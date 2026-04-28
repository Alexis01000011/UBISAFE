from __future__ import annotations

from pydantic import BaseModel


class GeoPoint(BaseModel):
    lat: float
    lng: float


class RiskZone(BaseModel):
    id: str
    reporter_uid: str
    threat_type: str
    risk_level: str  # HIGH | MEDIUM | LOW
    location: GeoPoint
    radius_meters: int
    active: bool
    created_at: str | None = None
    expires_at: str | None = None
    expired_at: str | None = None


class CreateRiskZoneBody(BaseModel):
    threat_type: str
    risk_level: str
    location: GeoPoint
    radius_meters: int = 100
