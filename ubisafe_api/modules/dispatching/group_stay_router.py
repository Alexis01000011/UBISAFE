"""CU-09 — Group-stay endpoints (Sesión 6: POST ""; Sesión 7: GET, cancel, attendances)."""
from __future__ import annotations

import asyncio
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.dispatching.group_stay_schemas import (
    CreateGroupStayBody,
    CreateGroupStayResponse,
    GroupStay,
)
from modules.shared.firestore_service import FirestoreService
from modules.shared.notification_service import NotificationService

router = APIRouter()

_MIN_ADVANCE_MINUTES = 5
_ZONE_VALIDATION_RADIUS_M = 200


async def _require_vendor(uid: str) -> None:
    profile = await FirestoreService.get_user(uid)
    if not profile or profile.role != "VENDOR":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only VENDOR users can perform this action.",
        )


@router.post("", response_model=CreateGroupStayResponse, status_code=status.HTTP_201_CREATED)
async def create_group_stay(
    body: CreateGroupStayBody,
    current_user: dict = Depends(get_current_user),
):
    """Schedule a new group stay at the given location.

    - 403 if caller is not VENDOR.
    - 422 if start_at is less than 5 minutes from now.
    - 422 with error='zone_high' if an active HIGH risk zone is within 200 m.
    - 200 with warning if an active MEDIUM/LOW risk zone is within 200 m.
    - 409 if the vendor already has an overlapping stay (scheduled or active).
    Returns 201 with the created GroupStay and an optional warning.
    """
    vendor_uid = current_user["uid"]
    await _require_vendor(vendor_uid)

    # Validate temporal advance (R-B1: keep logic in server)
    now = datetime.now(tz=UTC)
    start_at = body.start_at
    if start_at.tzinfo is None:
        start_at = start_at.replace(tzinfo=UTC)
    if start_at < now + timedelta(minutes=_MIN_ADVANCE_MINUTES):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="start_at must be at least 5 minutes in the future",
        )

    end_at = start_at + timedelta(minutes=body.duration_minutes)

    # Validate zone
    nearby_zones = await FirestoreService.get_active_risk_zones_near(
        body.location.lat,
        body.location.lng,
        radius_m=_ZONE_VALIDATION_RADIUS_M,
    )

    warning: dict | None = None
    high_zone_ids = [z.id for z in nearby_zones if z.risk_level == "HIGH"]
    if high_zone_ids:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": "zone_high", "risk_zone_ids": high_zone_ids},
        )

    medium_low_zones = [z for z in nearby_zones if z.risk_level in ("MEDIUM", "LOW")]
    if medium_low_zones:
        top = medium_low_zones[0]
        warning = {"risk_level": top.risk_level, "risk_zone_id": top.id}

    # Validate overlap with existing stays (R-B7)
    has_overlap = await FirestoreService.vendor_has_overlapping_stay(
        vendor_uid, start_at, end_at
    )
    if has_overlap:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="vendor_has_active_stay",
        )

    risk_level_at_creation = (
        medium_low_zones[0].risk_level if medium_low_zones else None
    )
    stay: GroupStay = await FirestoreService.create_group_stay(
        vendor_uid, body, risk_level_at_creation
    )

    return CreateGroupStayResponse(stay=stay, warning=warning)


@router.get("", response_model=list[GroupStay])
async def list_active_stays(
    lat: float,
    lng: float,
    radius_km: float = 1.0,
    current_user: dict = Depends(get_current_user),
):
    """Return active group stays within radius_km of (lat, lng)."""
    return await FirestoreService.list_active_group_stays(lat, lng, radius_km)


@router.get("/{stay_id}", response_model=GroupStay)
async def get_stay(
    stay_id: str,
    current_user: dict = Depends(get_current_user),
):
    stay = await FirestoreService.get_group_stay(stay_id)
    if stay is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="stay_not_found")
    return stay


@router.patch("/{stay_id}/cancel", response_model=GroupStay)
async def cancel_stay(
    stay_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Cancel a scheduled/active stay. Vendor must own the stay.

    Notifies all confirmed attendees via FCM (fire-and-forget, R-B6).
    """
    vendor_uid = current_user["uid"]
    await _require_vendor(vendor_uid)

    stay = await FirestoreService.get_group_stay(stay_id)
    if stay is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="stay_not_found")
    if stay.vendor_uid != vendor_uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="not_your_stay")
    if stay.status not in ("scheduled", "active"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="stay_not_cancellable",
        )

    cancelled = await FirestoreService.cancel_group_stay(stay_id, "vendor_cancelled")
    attendee_uids = await FirestoreService.get_confirmed_attendance_uids(stay_id)
    if attendee_uids:
        asyncio.ensure_future(
            NotificationService.send_group_stay_cancelled(
                attendee_uids, stay_id, "vendor_cancelled"
            )
        )
    return cancelled


@router.post("/{stay_id}/attendances", status_code=status.HTTP_204_NO_CONTENT)
async def confirm_attendance(
    stay_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Buyer confirms attendance for a scheduled/active stay."""
    buyer_uid = current_user["uid"]
    profile = await FirestoreService.get_user(buyer_uid)
    if not profile or profile.role != "BUYER":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only BUYER users can confirm attendance.",
        )
    stay = await FirestoreService.get_group_stay(stay_id)
    if stay is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="stay_not_found")
    if stay.status not in ("scheduled", "active"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="stay_not_active",
        )
    await FirestoreService.confirm_attendance(stay_id, buyer_uid)
