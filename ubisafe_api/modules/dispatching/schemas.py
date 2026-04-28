from __future__ import annotations

from pydantic import BaseModel


class GeoPoint(BaseModel):
    lat: float
    lng: float


class StopRequest(BaseModel):
    id: str
    buyer_uid: str
    vendor_uid: str | None = None
    buyer_location: GeoPoint
    status: str = "pending"
    expires_at: str | None = None
    created_at: str | None = None
    updated_at: str | None = None


class CreateStopRequestBody(BaseModel):
    vendor_uid: str
    buyer_location: GeoPoint


class UpdateStatusBody(BaseModel):
    status: str


# Valid state-machine transitions: (from_status, to_status) → required_role
VALID_TRANSITIONS: dict[tuple[str, str], str] = {
    ("pending", "accepted"): "VENDOR",
    ("pending", "rejected"): "VENDOR",
    ("pending", "expired"): "BUYER",
    ("accepted", "completed"): "VENDOR",
}
