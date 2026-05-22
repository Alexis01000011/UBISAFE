import asyncio

from fastapi import APIRouter, Depends, HTTPException, Query, status

from dependencies import get_current_user
from modules.community.schemas import (
    CommunityReport,
    CreateCommunityReportBody,
)
from modules.shared.firestore_service import FirestoreService
from modules.shared.notification_service import NotificationService

router = APIRouter()

_PROXIMITY_RADIUS_KM_INFECTION = 0.1   # focos de infección: usuario está en el punto
_PROXIMITY_RADIUS_KM_LOT = 1.0         # lote baldío: radio máximo de selección en mapa
_NOTIFY_RADIUS_KM = 1.0                # radio de fan-out FCM (todos los tipos)
_DUPLICATE_RADIUS_M = 50.0


@router.post("", response_model=CommunityReport, status_code=status.HTTP_201_CREATED)
async def create_community_report(
    body: CreateCommunityReportBody,
    current_user: dict = Depends(get_current_user),
):
    # Flujo 9.6.B — Condición 5A: proximity check (user IS the location in CU-05)
    # The reported location is the user's GPS position. FastAPI validates that
    # the user's stored position is within 4 km of what they claim to be reporting.
    # For CU-05 the location sent in the body IS the user's current GPS — we trust it
    # and validate format only (the distance check is meaningful for CU-06 /validations).
    # Haversine here is kept as a guard for future scenarios where location diverges.

    from modules.shared.firestore_service import _haversine_km  # noqa: PLC0415
    from modules.community.schemas import ThreatType  # noqa: PLC0415

    max_dist_km = (
        _PROXIMITY_RADIUS_KM_LOT
        if body.threat_type == ThreatType.lote_baldio
        else _PROXIMITY_RADIUS_KM_INFECTION
    )

    user_profile = await FirestoreService.get_user(current_user["uid"])
    if user_profile and user_profile.last_location:
        dist = _haversine_km(
            user_profile.last_location["lat"],
            user_profile.last_location["lng"],
            body.location.lat,
            body.location.lng,
        )
        if dist > max_dist_km:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": "location_out_of_range",
                    "message": "Debes estar a ≤ 4 km del área para reportar",
                },
            )

    if await FirestoreService.has_pending_report_within(
        body.location.lat, body.location.lng, _DUPLICATE_RADIUS_M, body.threat_type.value
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": "nearby_report_exists",
                "message": "Ya existe un reporte pendiente a menos de 50 m de esta ubicación.",
            },
        )

    report = await FirestoreService.create_community_report(uid=current_user["uid"], body=body)

    asyncio.ensure_future(_notify_nearby(report))

    return report


@router.get("", response_model=list[CommunityReport])
async def list_community_reports(
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    radius_km: float | None = Query(None),
    current_user: dict = Depends(get_current_user),
):
    return await FirestoreService.get_community_reports_in_bbox(lat, lng, radius_km)


async def _notify_nearby(report: CommunityReport) -> None:
    import logging  # noqa: PLC0415
    logger = logging.getLogger(__name__)
    try:
        tokens = await FirestoreService.get_nearby_user_fcm_tokens(
            report.location.lat, report.location.lng, _NOTIFY_RADIUS_KM
        )
        await NotificationService.send_community_report_nearby(
            tokens=tokens,
            report_id=report.id,
            threat_type=report.threat_type.value,
            lat=report.location.lat,
            lng=report.location.lng,
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("_notify_nearby failed for report %s: %s", report.id, exc)
