from __future__ import annotations

import asyncio
import math

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.dispatching.ride_schemas import (
    RIDE_VALID_TRANSITIONS,
    CreateRideBody,
    Ride,
    UpdateRideStatusBody,
)
from modules.shared.firestore_service import FirestoreService
from modules.shared.notification_service import NotificationService

router = APIRouter()

_EARTH_RADIUS_KM = 6371.0
_MAX_DISTANCE_KM = 4.0


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng / 2) ** 2
    )
    return _EARTH_RADIUS_KM * 2 * math.asin(math.sqrt(a))


async def _require_role(uid: str, required_role: str) -> None:
    profile = await FirestoreService.get_user(uid)
    if not profile or profile.role != required_role:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Only {required_role} users can perform this action.",
        )


@router.post("", response_model=Ride, status_code=status.HTTP_201_CREATED)
async def create_ride(
    body: CreateRideBody,
    current_user: dict = Depends(get_current_user),
):
    buyer_uid = current_user["uid"]
    await _require_role(buyer_uid, "BUYER")

    # Verify vendor exists and has ride_enabled
    vendor = await FirestoreService.get_user(body.vendor_uid)
    if not vendor:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Vendor not found")
    if vendor.ride_enabled is False:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="vendor_ride_disabled",
        )

    # Verify vendor has no active rides or stop_requests
    busy = await FirestoreService.vendor_has_active_requests(body.vendor_uid)
    if busy:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="vendor_not_available",
        )

    # Compute distance pickup → destination
    dist_km = _haversine_km(
        body.pickup_location.lat,
        body.pickup_location.lng,
        body.destination.lat,
        body.destination.lng,
    )
    destination_too_far = dist_km > _MAX_DISTANCE_KM

    ride = await FirestoreService.create_ride(buyer_uid, body)

    if destination_too_far:
        # Condition 4A: notify vendor to reject; vendor sees distance and must reject
        asyncio.ensure_future(
            NotificationService.send_ride_destination_too_far(
                vendor_uid=body.vendor_uid,
                ride_id=ride.id,
                distance_km=round(dist_km, 2),
            )
        )
    else:
        asyncio.ensure_future(
            NotificationService.send_ride_incoming(
                vendor_uid=body.vendor_uid,
                ride_id=ride.id,
                pickup_lat=body.pickup_location.lat,
                pickup_lng=body.pickup_location.lng,
                destination_lat=body.destination.lat,
                destination_lng=body.destination.lng,
            )
        )

    return ride


@router.get("/{ride_id}", response_model=Ride)
async def get_ride(ride_id: str, current_user: dict = Depends(get_current_user)):
    ride = await FirestoreService.get_ride(ride_id)
    if ride is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ride not found")
    uid = current_user["uid"]
    if uid != ride.buyer_uid and uid != ride.vendor_uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
    return ride


@router.patch("/{ride_id}/status", response_model=Ride)
async def update_ride_status(
    ride_id: str,
    body: UpdateRideStatusBody,
    current_user: dict = Depends(get_current_user),
):
    ride = await FirestoreService.get_ride(ride_id)
    if ride is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ride not found")

    transition = (ride.status.value, body.status)
    if transition not in RIDE_VALID_TRANSITIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid transition: {ride.status} → {body.status}",
        )

    required_role = RIDE_VALID_TRANSITIONS[transition]
    if required_role == "BUYER_OR_VENDOR":
        profile = await FirestoreService.get_user(current_user["uid"])
        if not profile or profile.role not in ("BUYER", "VENDOR"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only BUYER or VENDOR users can perform this action.",
            )
        caller_role = profile.role
    else:
        await _require_role(current_user["uid"], required_role)
        caller_role = required_role

    if body.status == "expired":
        updated, was_updated = await FirestoreService.update_ride_status_if_pending(
            ride_id, "expired", rejected_reason="timeout"
        )
        if updated is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ride not found")
        if not was_updated:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Ride already in status '{updated.status}'",
            )
        asyncio.ensure_future(NotificationService.send_ride_expired(updated.vendor_uid, ride_id))
        return updated

    extra: dict = {}
    if body.status == "accepted":
        # Verify the vendor is not already handling another stop or ride.
        # exclude_ride_id skips this ride so it doesn't count as a blocker against itself.
        busy = await FirestoreService.vendor_has_active_requests(
            ride.vendor_uid, exclude_ride_id=ride_id
        )
        if busy:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="vendor_already_busy",
            )
        extra["accepted_at"] = True  # firestore_service will set server timestamp
    elif body.status == "in_progress":
        extra["started_at"] = True
    elif body.status == "completed":
        extra["completed_at"] = True
    if body.rejected_reason:
        extra["rejected_reason"] = body.rejected_reason

    updated = await FirestoreService.update_ride_status(ride_id, body.status, extra)
    if updated is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ride not found")

    buyer_uid = updated.buyer_uid
    vendor_uid = updated.vendor_uid

    if body.status == "accepted":
        asyncio.ensure_future(NotificationService.send_ride_accepted(buyer_uid, ride_id))
        if body.route_warnings:
            asyncio.ensure_future(
                NotificationService.send_route_zone_warning(
                    buyer_uid, ride_id, len(body.route_warnings), is_ride=True
                )
            )
    elif body.status == "rejected":
        from_status = ride.status.value  # ride is the pre-update snapshot
        if from_status == "accepted" and caller_role == "BUYER":
            # Buyer cancelled after acceptance
            asyncio.ensure_future(
                NotificationService.send_ride_cancelled_by_buyer(vendor_uid, ride_id)
            )
        else:
            # Vendor rejected: pending→rejected, destination_too_far, or route_zone_rejected
            reason = body.rejected_reason or "vendor_rejected"
            asyncio.ensure_future(
                NotificationService.send_ride_rejected(buyer_uid, ride_id, reason)
            )
    elif body.status == "in_progress":
        if body.route_warnings:
            asyncio.ensure_future(
                NotificationService.send_route_zone_warning(
                    buyer_uid, ride_id, len(body.route_warnings), is_ride=True
                )
            )
    elif body.status == "completed":
        asyncio.ensure_future(
            NotificationService.send_ride_completed(buyer_uid, vendor_uid, ride_id)
        )
    elif body.status == "cancelled":
        # Buyer cancelled while ride was still pending (vendor hadn't responded yet)
        asyncio.ensure_future(
            NotificationService.send_ride_cancelled_by_buyer(vendor_uid, ride_id)
        )
    elif body.status == "abandoned":
        asyncio.ensure_future(
            NotificationService.send_ride_abandoned(buyer_uid, ride_id)
        )

    return updated


@router.post("/{ride_id}/vendor_arrived", status_code=status.HTTP_204_NO_CONTENT)
async def vendor_arrived(
    ride_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Vendor signals arrival at pickup point — sends FCM to buyer, no status change."""
    await _require_role(current_user["uid"], "VENDOR")
    ride = await FirestoreService.get_ride(ride_id)
    if ride is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ride not found")
    if ride.vendor_uid != current_user["uid"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    asyncio.ensure_future(NotificationService.send_ride_vendor_arrived(ride.buyer_uid, ride_id))
