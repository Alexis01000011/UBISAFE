from __future__ import annotations

import math

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.safety.schemas import CreateRiskZoneBody, RiskZone
from modules.shared.firestore_service import FirestoreService
from modules.shared.notification_service import NotificationService

router = APIRouter()

_VALID_RISK_LEVELS = {"HIGH", "MEDIUM", "LOW"}


_EARTH_RADIUS_M = 6_371_000


def _haversine_meters(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    )
    return 2 * _EARTH_RADIUS_M * math.asin(math.sqrt(a))


def _bbox_delta(radius_meters: float) -> float:
    return radius_meters / 111_000


@router.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@router.post("/", response_model=RiskZone, status_code=status.HTTP_201_CREATED)
async def create_risk_zone(
    body: CreateRiskZoneBody,
    current_user: dict = Depends(get_current_user),
):
    if body.risk_level not in _VALID_RISK_LEVELS:
        raise HTTPException(
            status_code=422,
            detail=f"risk_level must be one of {sorted(_VALID_RISK_LEVELS)}",
        )

    delta = _bbox_delta(body.radius_meters)
    candidates = await FirestoreService.query_active_risk_zones_bbox(
        body.location.lat, body.location.lng, delta
    )
    for cand in candidates:
        loc = cand.get("location") or {}
        dist = _haversine_meters(
            body.location.lat,
            body.location.lng,
            loc.get("lat", 0),
            loc.get("lng", 0),
        )
        if dist < cand.get("radius_meters", 100):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "error": "duplicate_risk_zone",
                    "existing_zone_id": cand["id"],
                    "message": "Ya existe una zona activa en esta área",
                },
            )

    zone = await FirestoreService.create_risk_zone(current_user["uid"], body)

    fcm_tokens = await FirestoreService.get_all_fcm_tokens()
    loc = zone.location
    await NotificationService.notify_risk_zone_alert(
        fcm_tokens,
        {
            "type": "risk_zone_alert",
            "risk_zone_id": zone.id,
            "risk_level": zone.risk_level,
            "threat_type": zone.threat_type,
            "lat": str(loc.lat),
            "lng": str(loc.lng),
        },
    )

    return zone


@router.get("/", response_model=list[RiskZone])
async def list_risk_zones(
    lat: float,
    lng: float,
    radius_km: float = 5.0,
    current_user: dict = Depends(get_current_user),
):
    delta = _bbox_delta(radius_km * 1000)
    candidates = await FirestoreService.query_active_risk_zones_bbox(lat, lng, delta)
    radius_m = radius_km * 1000
    results = []
    for cand in candidates:
        loc = cand.get("location") or {}
        dist = _haversine_meters(lat, lng, loc.get("lat", 0), loc.get("lng", 0))
        if dist <= radius_m:
            results.append(
                RiskZone(
                    id=cand["id"],
                    reporter_uid=cand.get("reporter_uid", ""),
                    threat_type=cand.get("threat_type", ""),
                    risk_level=cand.get("risk_level", ""),
                    location={"lat": loc.get("lat", 0), "lng": loc.get("lng", 0)},
                    radius_meters=cand.get("radius_meters", 100),
                    active=cand.get("active", True),
                    created_at=cand.get("created_at"),
                    expires_at=cand.get("expires_at"),
                    expired_at=cand.get("expired_at"),
                )
            )
    return results


@router.delete("/{zone_id}", status_code=status.HTTP_204_NO_CONTENT)
async def expire_risk_zone(
    zone_id: str,
    current_user: dict = Depends(get_current_user),
):
    zone = await FirestoreService.get_risk_zone(zone_id)
    if zone is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Zone not found",
        )
    if zone.get("reporter_uid") != current_user["uid"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the reporter can expire this zone",
        )
    await FirestoreService.expire_risk_zone(zone_id)
