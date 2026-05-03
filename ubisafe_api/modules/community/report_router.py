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

_PROXIMITY_RADIUS_KM = 4.0


@router.post("/", response_model=CommunityReport, status_code=status.HTTP_201_CREATED)
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

    user_profile = await FirestoreService.get_user(current_user["uid"])
    if user_profile and user_profile.last_location:
        dist = _haversine_km(
            user_profile.last_location["lat"],
            user_profile.last_location["lng"],
            body.location.lat,
            body.location.lng,
        )
        if dist > _PROXIMITY_RADIUS_KM:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error": "location_out_of_range",
                    "message": "Debes estar a ≤ 4 km del área para reportar",
                },
            )

    report = await FirestoreService.create_community_report(uid=current_user["uid"], body=body)

    asyncio.ensure_future(_notify_nearby(report))

    return report


@router.get("/", response_model=list[CommunityReport])
async def list_community_reports(
    lat: float | None = Query(None),
    lng: float | None = Query(None),
    radius_km: float | None = Query(None),
    current_user: dict = Depends(get_current_user),
):
    return await FirestoreService.get_community_reports_in_bbox(lat, lng, radius_km)


async def _notify_nearby(report: CommunityReport) -> None:
    tokens = await FirestoreService.get_nearby_user_fcm_tokens(
        report.location.lat, report.location.lng, _PROXIMITY_RADIUS_KM
    )
    await NotificationService.send_community_report_nearby(
        tokens=tokens,
        report_id=report.id,
        threat_type=report.threat_type.value,
        lat=report.location.lat,
        lng=report.location.lng,
    )
