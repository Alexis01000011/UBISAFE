from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.shared.firestore_service import FirestoreService
from modules.shared.subscription_schemas import CreateSubscriptionBody, Subscription

router = APIRouter()


@router.post("", response_model=Subscription, status_code=status.HTTP_201_CREATED)
async def create_subscription(
    body: CreateSubscriptionBody,
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    profile = await FirestoreService.get_user(uid)
    if not profile or profile.role != "BUYER":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only BUYER users can subscribe.",
        )
    sub_id = f"{uid}_{body.vendor_uid}"
    existing = await FirestoreService.get_subscription(sub_id)
    if existing and existing.active:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already subscribed to this vendor.",
        )
    return await FirestoreService.create_subscription(uid, body.vendor_uid)


@router.get("", response_model=list[Subscription])
async def list_subscriptions(current_user: dict = Depends(get_current_user)):
    return await FirestoreService.list_active_subscriptions(current_user["uid"])


@router.delete("/{subscription_id}", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_subscription(
    subscription_id: str,
    current_user: dict = Depends(get_current_user),
):
    sub = await FirestoreService.get_subscription(subscription_id)
    if sub is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subscription not found.")
    if sub.buyer_uid != current_user["uid"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your subscription.")
    await FirestoreService.cancel_subscription(subscription_id, "user_cancelled")
