from __future__ import annotations

from pydantic import BaseModel


class GeoPoint(BaseModel):
    lat: float
    lng: float


class RiskZone(BaseModel):
    id: str
    reported_by: str
    location: GeoPoint
    description: str
    level: str = "medium"
    created_at: str | None = None


class CreateRiskZoneBody(BaseModel):
    location: GeoPoint
    description: str
    level: str = "medium"
