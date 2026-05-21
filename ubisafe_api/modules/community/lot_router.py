"""CU-07 — Support and resolve endpoints for lote_baldio community reports."""
from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.community.schemas import CommunityReport, ReportStatus, ThreatType
from modules.shared.firestore_service import FirestoreService, VoteConflictError
from modules.shared.notification_service import NotificationService

router = APIRouter()


@router.post("/{report_id}/support", response_model=CommunityReport)
async def support_community_report(
    report_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Append the caller's UID to the supporters list of a lote_baldio report.

    Rules:
    - 404 if report does not exist.
    - 422 if threat_type != lote_baldio.
    - 409 if status != pending_validation.
    - 409 if caller already supported.
    At the 3rd unique supporter: sets pending_resolver_uid (persists across sessions).
    """
    uid = current_user["uid"]
    report = await FirestoreService.get_community_report(report_id)
    if report is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="report_not_found")
    if report.threat_type != ThreatType.lote_baldio:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="use_validation_endpoint",
        )
    if report.status != ReportStatus.pending_validation:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"report_status_is_{report.status.value}",
        )
    if uid in (report.supporters or []):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="already_supported",
        )

    try:
        updated = await FirestoreService.support_community_report(report_id, uid)
    except VoteConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.detail)

    return updated


@router.patch("/{report_id}/resolve", response_model=CommunityReport)
async def resolve_community_report(
    report_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Mark a lote_baldio report as resolved.

    Only callable by the user set as pending_resolver_uid (the 3rd supporter).
    Sends FCM to the reporter and all supporters (fire-and-forget).
    """
    uid = current_user["uid"]
    report = await FirestoreService.get_community_report(report_id)
    if report is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="report_not_found")
    if report.threat_type != ThreatType.lote_baldio:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="use_validation_endpoint",
        )
    if report.pending_resolver_uid != uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="not_pending_resolver",
        )
    if report.status != ReportStatus.pending_validation:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"report_status_is_{report.status.value}",
        )

    updated = await FirestoreService.resolve_community_report(report_id, uid)

    asyncio.ensure_future(
        NotificationService.send_lot_resolved(
            reporter_uid=updated.reporter_uid,
            supporter_uids=updated.supporters or [],
            report_id=report_id,
            resolved_by_uid=uid,
        )
    )

    return updated
