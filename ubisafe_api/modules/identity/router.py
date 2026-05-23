from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.identity.schemas import (
    DeviceTokenRequest,
    SyncProfileRequest,
    UpdateLocationBody,
    UpdateRadarStatusRequest,
    UpdateRideEnabledRequest,
    UserProfile,
)
from modules.shared.firestore_service import FirestoreService

router = APIRouter()


@router.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@router.get(
    "/me",
    response_model=UserProfile,
    # Decision (D-10 / ADR pending): GET /auth/me is not in the SDD §5.3.1.4 endpoint
    # table but was added to avoid reading Firestore directly from the Flutter client.
    # This is cleaner than exposing a Firestore SDK call from the app and keeps all
    # profile reads behind the authenticated API. Pending formal ADR before iter.2.
)
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


@router.patch("/ride-enabled", status_code=status.HTTP_204_NO_CONTENT)
async def update_ride_enabled(
    body: UpdateRideEnabledRequest,
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    profile = await FirestoreService.get_user(uid)
    if not profile or profile.role != "VENDOR":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only VENDOR users can update ride_enabled.",
        )
    await FirestoreService.update_ride_enabled(uid, body.ride_enabled)


@router.patch("/location", status_code=status.HTTP_204_NO_CONTENT)
async def update_location(
    body: UpdateLocationBody,
    current_user: dict = Depends(get_current_user),
):
    await FirestoreService.update_user_location(current_user["uid"], body.lat, body.lng)


@router.patch("/radar-status", status_code=status.HTTP_204_NO_CONTENT)
async def update_radar_status(
    body: UpdateRadarStatusRequest,
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    profile = await FirestoreService.get_user(uid)
    if not profile or profile.role != "VENDOR":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only VENDOR users can update radar status.",
        )
    await FirestoreService.update_radar_status(uid, body.is_active_radar)
