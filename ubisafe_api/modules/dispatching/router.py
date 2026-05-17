import asyncio

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.dispatching.schemas import (
    VALID_TRANSITIONS,
    CreateStopRequestBody,
    StopRequest,
    UpdateStatusBody,
)
from modules.shared.firestore_service import FirestoreService
from modules.shared.notification_service import NotificationService

router = APIRouter()


async def _require_role(uid: str, required_role: str) -> None:
    profile = await FirestoreService.get_user(uid)
    if not profile or profile.role != required_role:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Only {required_role} users can perform this action.",
        )


@router.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@router.get("", response_model=list[StopRequest])
async def list_stops(current_user: dict = Depends(get_current_user)):
    return await FirestoreService.list_stop_requests(current_user["uid"])


@router.post("", response_model=StopRequest, status_code=status.HTTP_201_CREATED)
async def create_stop(
    body: CreateStopRequestBody,
    current_user: dict = Depends(get_current_user),
):
    await _require_role(current_user["uid"], "BUYER")
    doc = await FirestoreService.create_stop_request(current_user["uid"], body)
    asyncio.ensure_future(
        NotificationService.send_stop_incoming(
            vendor_uid=body.vendor_uid,
            stop_id=doc.id,
            buyer_lat=body.buyer_location.lat,
            buyer_lng=body.buyer_location.lng,
        )
    )
    return doc


@router.get("/{stop_id}", response_model=StopRequest)
async def get_stop(stop_id: str, current_user: dict = Depends(get_current_user)):
    doc = await FirestoreService.get_stop_request(stop_id)
    if doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Stop request not found")
    uid = current_user["uid"]
    if uid != doc.buyer_uid and uid != doc.vendor_uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
    return doc


@router.patch("/{stop_id}/status", response_model=StopRequest)
async def update_stop_status(
    stop_id: str,
    body: UpdateStatusBody,
    current_user: dict = Depends(get_current_user),
):
    doc = await FirestoreService.get_stop_request(stop_id)
    if doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Stop request not found")

    transition = (doc.status, body.status)
    if transition not in VALID_TRANSITIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid transition: {doc.status} → {body.status}",
        )

    required_role = VALID_TRANSITIONS[transition]
    await _require_role(current_user["uid"], required_role)

    # Race condition: buyer sends 'expired' but vendor already changed status
    if body.status == "expired":
        updated_doc, was_updated = await FirestoreService.update_stop_status_if_pending(
            stop_id, "expired"
        )
        if updated_doc is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Stop request not found"
            )
        if not was_updated:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Stop request already in status '{updated_doc.status}'",
            )
        asyncio.ensure_future(
            NotificationService.send_stop_expired(updated_doc.buyer_uid, stop_id)
        )
        if updated_doc.vendor_uid:
            asyncio.ensure_future(
                NotificationService.send_stop_expired_vendor(updated_doc.vendor_uid, stop_id)
            )
        return updated_doc

    extra: dict | None = None
    if body.status == "accepted":
        extra = {"accepted_at": True}
    elif body.status == "completed":
        extra = {"completed_at": True}
    updated = await FirestoreService.update_stop_status(stop_id, body.status, extra=extra)
    if updated is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Stop request not found")

    buyer_uid = updated.buyer_uid
    vendor_uid = updated.vendor_uid
    if body.status == "accepted":
        asyncio.ensure_future(NotificationService.send_stop_accepted(buyer_uid, stop_id))
    elif body.status == "rejected":
        asyncio.ensure_future(NotificationService.send_stop_rejected(buyer_uid, stop_id))
    elif body.status == "completed":
        asyncio.ensure_future(NotificationService.send_stop_completed(buyer_uid, stop_id))
    elif body.status == "cancelled" and vendor_uid:
        asyncio.ensure_future(NotificationService.send_stop_cancelled(vendor_uid, stop_id))

    return updated
