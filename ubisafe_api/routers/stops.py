from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from schemas.stop_request import CreateStopRequestBody, StopRequest, UpdateStatusBody
from services.firestore_service import FirestoreService

router = APIRouter()


@router.get("/", response_model=list[StopRequest])
async def list_stops(current_user: dict = Depends(get_current_user)):
    return await FirestoreService.list_stop_requests(current_user["uid"])


@router.post("/", response_model=StopRequest, status_code=status.HTTP_201_CREATED)
async def create_stop(
    body: CreateStopRequestBody,
    current_user: dict = Depends(get_current_user),
):
    return await FirestoreService.create_stop_request(current_user["uid"], body)


@router.get("/{stop_id}", response_model=StopRequest)
async def get_stop(stop_id: str, current_user: dict = Depends(get_current_user)):
    doc = await FirestoreService.get_stop_request(stop_id)
    if doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Stop request not found")
    return doc


@router.patch("/{stop_id}/status", response_model=StopRequest)
async def update_stop_status(
    stop_id: str,
    body: UpdateStatusBody,
    current_user: dict = Depends(get_current_user),
):
    doc = await FirestoreService.update_stop_status(stop_id, body.status)
    if doc is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Stop request not found")
    return doc
