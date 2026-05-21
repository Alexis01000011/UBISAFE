"""CU-09 — Group-stay endpoints (Sesión 6: POST ""; Sesión 7: GET, cancel, attendances)."""
from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.dispatching.group_stay_schemas import (
    CreateGroupStayBody,
    CreateGroupStayResponse,
    GroupStay,
)
from modules.shared.firestore_service import FirestoreService

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
