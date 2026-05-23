from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.safety.schemas import RiskZone
from modules.shared.firestore_service import FirestoreService, VoteConflictError
from modules.shared.notification_service import NotificationService

router = APIRouter()


@router.post("/{zone_id}/dismiss", response_model=RiskZone)
async def dismiss_risk_zone(
    zone_id: str,
    current_user: dict = Depends(get_current_user),
):
    zone = await FirestoreService.get_risk_zone(zone_id)
    if zone is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Zone not found",
        )
    if not zone.active:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": "zone_already_inactive",
                "message": "La zona ya no está activa.",
            },
        )
    if zone.reporter_uid == current_user["uid"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "reporter_cannot_dismiss",
                "message": "No puedes desmentir tu propia zona de riesgo.",
            },
        )

    try:
        updated = await FirestoreService.dismiss_risk_zone(zone_id, current_user["uid"])
    except VoteConflictError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": exc.detail,
                "message": "Ya votaste en esta zona o la zona ya no está activa.",
            },
        ) from exc

    if not updated.active:
        await NotificationService.send_risk_zone_dismissed(
            reporter_uid=updated.reporter_uid,
            zone_id=zone_id,
        )

    return updated
