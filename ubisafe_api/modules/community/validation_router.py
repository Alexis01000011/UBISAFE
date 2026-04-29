from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.community.schemas import CommunityReport, VoteBody
from modules.shared.firestore_service import FirestoreService

router = APIRouter()


@router.patch("/{report_id}/validations", response_model=CommunityReport)
async def validate_report(
    report_id: str,
    body: VoteBody,
    current_user: dict = Depends(get_current_user),
):
    """CU-06 — Cast a confirm or dismiss vote on a community report.

    Rules:
    - 403 if the voter is the original reporter.
    - 409 if the voter already voted.
    - 409 if the report is not in pending_validation.
    Threshold: 3 confirms → confirmed; 3 dismisses → dismissed.
    """
    voter_uid = current_user["uid"]

    report = await FirestoreService.get_community_report(report_id)
    if report is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="report_not_found")

    if report.reporter_uid == voter_uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="reporter_cannot_vote",
        )

    if report.status.value != "pending_validation":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"report_status_is_{report.status.value}",
        )

    already_voted = any(v.user_uid == voter_uid for v in report.validations)
    if already_voted:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="already_voted",
        )

    updated = await FirestoreService.vote_community_report(
        report_id, voter_uid, body.vote.value
    )
    return updated
