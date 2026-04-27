from __future__ import annotations

from pydantic import BaseModel


class GeoPoint(BaseModel):
    lat: float
    lng: float


class StopRequest(BaseModel):
    id: str
    buyer_uid: str
    vendor_uid: str | None = None
    location: GeoPoint
    status: str = "pending"
    created_at: str | None = None


class CreateStopRequestBody(BaseModel):
    vendor_uid: str
    location: GeoPoint


class UpdateStatusBody(BaseModel):
    status: str
