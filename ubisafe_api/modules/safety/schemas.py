from __future__ import annotations

from pydantic import BaseModel


class GeoPoint(BaseModel):
    lat: float
    lng: float


class RiskZone(BaseModel):
    """Modelo de zona de riesgo. Ref: SDD_FASE3_UBISAFE.md §7.2.3
    El backend siempre genera created_at y expires_at (now+24h) al crear.
    """

    id: str
    reporter_uid: str
    threat_type: str
    risk_level: str  # HIGH | MEDIUM | LOW
    location: GeoPoint
    radius_meters: int
    active: bool
    created_at: str  # Siempre presente — generado por el backend
    expires_at: str  # Siempre presente — created_at + 24h
    expired_at: str | None = None  # Solo presente cuando la zona expiró por TTL
    dismissed_at: str | None = None  # Solo presente cuando la zona fue desmentida por la comunidad
    dismiss_count: int = 0  # Número de votos de desmentido
    dismissers: list[str] = []  # UIDs de usuarios que desmintieron


class CreateRiskZoneBody(BaseModel):
    threat_type: str
    risk_level: str  # HIGH | MEDIUM | LOW
    location: GeoPoint
    radius_meters: int = 100
