from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends, HTTPException, status

from dependencies import get_current_user
from modules.shared.firestore_service import FirestoreService
from modules.shared.notification_service import NotificationService
from modules.shared.subscription_schemas import CreateSubscriptionBody, Subscription

router = APIRouter()


@router.post("", status_code=status.HTTP_201_CREATED, response_model=Subscription)
async def create_subscription(
    body: CreateSubscriptionBody,
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    profile = await FirestoreService.get_user(uid)
    if profile and profile.role == "VENDOR":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="vendor_cannot_subscribe",
        )
    active_subs = await FirestoreService.list_active_subscriptions(uid)
    if len(active_subs) >= 5:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="max_subscriptions_reached",
        )
    subscription_id = f"{uid}_{body.vendor_uid}"
    existing = await FirestoreService.get_subscription(subscription_id)
    if existing and existing.active:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="already_subscribed",
        )
    subscription = await FirestoreService.create_subscription(uid, body.vendor_uid)
    buyer_name = profile.name if profile and profile.name else "Un comprador"
    asyncio.ensure_future(
        NotificationService.send_subscription_created(body.vendor_uid, buyer_name)
    )
    return subscription


@router.get("", response_model=list[Subscription])
async def list_subscriptions(
    current_user: dict = Depends(get_current_user),
):
    return await FirestoreService.list_active_subscriptions(current_user["uid"])


@router.delete("/{subscription_id}", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_subscription(
    subscription_id: str,
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    sub = await FirestoreService.get_subscription(subscription_id)
    if sub is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="not_found")
    if sub.buyer_uid != uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="forbidden")
    await FirestoreService.cancel_subscription(subscription_id, "user_cancelled")
