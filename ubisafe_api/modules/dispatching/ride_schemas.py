from __future__ import annotations

from enum import StrEnum

from pydantic import BaseModel

from modules.safety.schemas import GeoPoint

_RIDE_TTL_SECONDS = 60


class RideStatus(StrEnum):
    pending = "pending"
    accepted = "accepted"
    in_progress = "in_progress"
    completed = "completed"
    rejected = "rejected"
    expired = "expired"
    cancelled = "cancelled"
    abandoned = "abandoned"


class Ride(BaseModel):
    id: str
    buyer_uid: str
    vendor_uid: str
    pickup_location: GeoPoint
    destination: GeoPoint
    route_polyline: str | None = None
    status: RideStatus
    created_at: str | None = None
    updated_at: str | None = None
    accepted_at: str | None = None
    started_at: str | None = None
    completed_at: str | None = None
    expires_at: str | None = None
    rejected_reason: str | None = None


class CreateRideBody(BaseModel):
    vendor_uid: str
    pickup_location: GeoPoint
    destination: GeoPoint
    route_polyline: str | None = None


class UpdateRideStatusBody(BaseModel):
    status: str
    rejected_reason: str | None = None
    route_warnings: list[str] = []


# Valid state-machine transitions: (from_status, to_status) → required_role
RIDE_VALID_TRANSITIONS: dict[tuple[str, str], str] = {
    ("pending", "accepted"): "VENDOR",
    ("pending", "rejected"): "VENDOR",  # manual reject or destination_too_far
    ("pending", "expired"): "BUYER",    # client timer fired
    ("pending", "cancelled"): "BUYER",  # buyer cancels before vendor responds
    ("accepted", "in_progress"): "VENDOR",    # buyer boarded
    ("accepted", "rejected"): "BUYER_OR_VENDOR",  # buyer cancel OR vendor route_zone_rejected
    ("accepted", "abandoned"): "VENDOR",   # vendor exited app mid-ride
    ("in_progress", "completed"): "VENDOR",
    ("in_progress", "abandoned"): "VENDOR", # vendor exited app with passenger aboard
}
