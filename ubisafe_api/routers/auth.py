from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from schemas.user import DeviceTokenRequest, SyncProfileRequest, UserProfile
from services.firestore_service import FirestoreService

router = APIRouter()


@router.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@router.get("/me", response_model=UserProfile)
async def get_me(current_user: dict = Depends(get_current_user)):
    profile = await FirestoreService.get_user(current_user["uid"])
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
    return profile


@router.post("/sync-profile", response_model=UserProfile)
async def sync_profile(
    body: SyncProfileRequest,
    current_user: dict = Depends(get_current_user),
):
    profile = await FirestoreService.upsert_user(current_user["uid"], body)
    return profile


@router.patch("/device-token", status_code=204)
async def register_device_token(
    body: DeviceTokenRequest,
    current_user: dict = Depends(get_current_user),
):
    await FirestoreService.update_device_token(current_user["uid"], body.token)
