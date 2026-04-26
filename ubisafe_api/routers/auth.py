from fastapi import APIRouter, Depends

from dependencies import get_current_user
from schemas.user import DeviceTokenRequest, SyncProfileRequest, UserProfile
from services.firestore_service import FirestoreService

router = APIRouter()


@router.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@router.post("/sync-profile", response_model=UserProfile)
async def sync_profile(
    body: SyncProfileRequest,
    current_user: dict = Depends(get_current_user),
):
    profile = await FirestoreService.upsert_user(current_user["uid"], body)
    return profile


@router.post("/device-token", status_code=204)
async def register_device_token(
    body: DeviceTokenRequest,
    current_user: dict = Depends(get_current_user),
):
    await FirestoreService.update_device_token(current_user["uid"], body.token)
