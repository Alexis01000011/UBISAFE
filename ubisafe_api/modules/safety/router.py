import asyncio

from fastapi import APIRouter, Depends, HTTPException, Query, status

from dependencies import get_current_user
from modules.safety.schemas import CreateRiskZoneBody, RiskZone
from modules.shared.firestore_service import FirestoreService
from modules.shared.notification_service import NotificationService

router = APIRouter()


@router.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@router.get("/", response_model=list[RiskZone])
async def list_risk_zones(
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    radius_km: float | None = Query(None),
    current_user: dict = Depends(get_current_user),
):
    return await FirestoreService.get_active_risk_zones(lat, lng, radius_km)


@router.post("/", response_model=RiskZone, status_code=status.HTTP_201_CREATED)
async def create_risk_zone(
    body: CreateRiskZoneBody,
    current_user: dict = Depends(get_current_user),
):
    duplicate = await FirestoreService.find_duplicate_risk_zone(
        body.location.lat, body.location.lng, body.radius_meters
    )
    if duplicate:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": "duplicate_risk_zone",
                "existing_zone_id": duplicate.id,
                "message": "Ya existe una zona activa en esta área",
            },
        )

    zone = await FirestoreService.create_risk_zone(current_user["uid"], body)

    asyncio.ensure_future(_notify_all(zone.id, body))

    return zone


@router.delete("/{zone_id}", status_code=status.HTTP_204_NO_CONTENT)
async def expire_risk_zone(
    zone_id: str,
    current_user: dict = Depends(get_current_user),
):
    zone = await FirestoreService.get_risk_zone(zone_id)
    if zone is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Zone not found")
    if zone.reporter_uid != current_user["uid"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the reporter can expire this zone")
    await FirestoreService.expire_risk_zone(zone_id)


async def _notify_all(zone_id: str, body: CreateRiskZoneBody) -> None:
    tokens = await FirestoreService.get_all_user_fcm_tokens()
    await NotificationService.send_risk_zone_alert(
        tokens=tokens,
        zone_id=zone_id,
        risk_level=body.risk_level,
        threat_type=body.threat_type,
        lat=body.location.lat,
        lng=body.location.lng,
    )
