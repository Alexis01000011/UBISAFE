"""Tests for POST/GET/DELETE /subscriptions (CU-08-A)."""
from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

_BUYER_UID = "buyer-uid"
_VENDOR_UID = "vendor-uid"
_BUYER_TOKEN = {"uid": _BUYER_UID, "email": "buyer@example.com"}
_VENDOR_TOKEN = {"uid": _VENDOR_UID, "email": "vendor@example.com"}
_SUB_ID = f"{_BUYER_UID}_{_VENDOR_UID}"

_FS_LIST = "modules.shared.firestore_service.FirestoreService.list_active_subscriptions"
_FS_GET_USER = "modules.shared.firestore_service.FirestoreService.get_user"
_FS_GET_SUB = "modules.shared.firestore_service.FirestoreService.get_subscription"
_FS_CREATE = "modules.shared.firestore_service.FirestoreService.create_subscription"
_NOTIFY_SUB = "modules.shared.notification_service.NotificationService.send_subscription_created"


@pytest.fixture
def mock_firebase():
    with patch("main.FirebaseAdminInit.initialize"):
        yield


@pytest.fixture
def mock_buyer_token():
    with patch("dependencies.auth.verify_id_token", return_value=_BUYER_TOKEN):
        yield


@pytest.fixture
def mock_vendor_token():
    with patch("dependencies.auth.verify_id_token", return_value=_VENDOR_TOKEN):
        yield


def _make_sub(active: bool = True, buyer_uid: str = _BUYER_UID) -> object:
    from modules.shared.subscription_schemas import Subscription

    return Subscription(
        id=f"{buyer_uid}_{_VENDOR_UID}",
        buyer_uid=buyer_uid,
        vendor_uid=_VENDOR_UID,
        active=active,
        created_at="2026-01-01T00:00:00",
        cancelled_at=None,
        cancellation_reason=None,
    )


def _make_profile(uid: str, role: str) -> object:
    from modules.identity.schemas import UserProfile

    return UserProfile(uid=uid, role=role)


# ── POST /subscriptions ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_buyer_can_subscribe_to_vendor(mock_firebase, mock_buyer_token):
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_make_profile(_BUYER_UID, "BUYER")),
        patch(_FS_LIST, new_callable=AsyncMock, return_value=[]),
        patch(_FS_GET_SUB, new_callable=AsyncMock, return_value=None),
        patch(_FS_CREATE, new_callable=AsyncMock, return_value=_make_sub(active=True)),
        patch(_NOTIFY_SUB, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/subscriptions",
                headers={"Authorization": "Bearer valid-token"},
                json={"vendor_uid": _VENDOR_UID},
            )

    assert response.status_code == 201
    data = response.json()
    assert data["active"] is True
    assert data["buyer_uid"] == _BUYER_UID
    assert data["vendor_uid"] == _VENDOR_UID


@pytest.mark.asyncio
async def test_buyer_cannot_subscribe_twice_returns_409(mock_firebase, mock_buyer_token):
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_make_profile(_BUYER_UID, "BUYER")),
        patch(_FS_LIST, new_callable=AsyncMock, return_value=[_make_sub()]),
        patch(_FS_GET_SUB, new_callable=AsyncMock, return_value=_make_sub(active=True)),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/subscriptions",
                headers={"Authorization": "Bearer valid-token"},
                json={"vendor_uid": _VENDOR_UID},
            )

    assert response.status_code == 409
    assert response.json()["detail"] == "already_subscribed"


@pytest.mark.asyncio
async def test_buyer_exceeds_5_subscriptions_returns_409(mock_firebase, mock_buyer_token):
    from main import app

    five_subs = [_make_sub(buyer_uid=f"uid-{i}") for i in range(5)]
    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_make_profile(_BUYER_UID, "BUYER")),
        patch(_FS_LIST, new_callable=AsyncMock, return_value=five_subs),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/subscriptions",
                headers={"Authorization": "Bearer valid-token"},
                json={"vendor_uid": _VENDOR_UID},
            )

    assert response.status_code == 409
    assert response.json()["detail"] == "max_subscriptions_reached"


@pytest.mark.asyncio
async def test_inactive_subscription_gets_reactivated(mock_firebase, mock_buyer_token):
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_make_profile(_BUYER_UID, "BUYER")),
        patch(_FS_LIST, new_callable=AsyncMock, return_value=[]),
        patch(_FS_GET_SUB, new_callable=AsyncMock, return_value=_make_sub(active=False)),
        patch(_FS_CREATE, new_callable=AsyncMock, return_value=_make_sub(active=True)),
        patch(_NOTIFY_SUB, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/subscriptions",
                headers={"Authorization": "Bearer valid-token"},
                json={"vendor_uid": _VENDOR_UID},
            )

    assert response.status_code == 201
    assert response.json()["active"] is True


@pytest.mark.asyncio
async def test_vendor_cannot_subscribe_returns_403(mock_firebase, mock_vendor_token):
    from main import app

    with patch(
        "modules.shared.firestore_service.FirestoreService.get_user",
        new_callable=AsyncMock,
        return_value=_make_profile(_VENDOR_UID, "VENDOR"),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/subscriptions",
                headers={"Authorization": "Bearer valid-token"},
                json={"vendor_uid": _BUYER_UID},
            )

    assert response.status_code == 403


# ── GET /subscriptions ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_returns_only_active(mock_firebase, mock_buyer_token):
    from main import app

    with patch(
        "modules.shared.firestore_service.FirestoreService.list_active_subscriptions",
        new_callable=AsyncMock,
        return_value=[_make_sub(active=True)],
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.get(
                "/subscriptions",
                headers={"Authorization": "Bearer valid-token"},
            )

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["active"] is True


# ── DELETE /subscriptions/{id} ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_delete_marks_inactive(mock_firebase, mock_buyer_token):
    from main import app

    with (
        patch(
            "modules.shared.firestore_service.FirestoreService.get_subscription",
            new_callable=AsyncMock,
            return_value=_make_sub(active=True),
        ),
        patch(
            "modules.shared.firestore_service.FirestoreService.cancel_subscription",
            new_callable=AsyncMock,
            return_value=None,
        ) as mock_cancel,
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.delete(
                f"/subscriptions/{_SUB_ID}",
                headers={"Authorization": "Bearer valid-token"},
            )

    assert response.status_code == 204
    mock_cancel.assert_called_once_with(_SUB_ID, "user_cancelled")


@pytest.mark.asyncio
async def test_delete_other_users_subscription_returns_403(mock_firebase, mock_buyer_token):
    from main import app

    with patch(
        "modules.shared.firestore_service.FirestoreService.get_subscription",
        new_callable=AsyncMock,
        return_value=_make_sub(active=True, buyer_uid="other-buyer-uid"),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.delete(
                "/subscriptions/other-buyer-uid_vendor-uid",
                headers={"Authorization": "Bearer valid-token"},
            )

    assert response.status_code == 403
