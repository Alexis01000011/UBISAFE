"""CU-08-A — Subscriptions endpoint tests."""

from datetime import datetime
from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

BUYER_UID = "buyer-uid-001"
VENDOR_UID = "vendor-uid-002"
OTHER_UID = "other-uid-003"

BUYER_TOKEN = {"uid": BUYER_UID, "email": "buyer@test.com"}
VENDOR_TOKEN = {"uid": VENDOR_UID, "email": "vendor@test.com"}

MOCK_BUYER_PROFILE = {
    "name": "Buyer User",
    "phone": "+52 33 0000 0001",
    "role": "BUYER",
    "fcm_token": None,
    "last_location": None,
    "last_location_at": None,
    "created_at": datetime(2026, 1, 1),
    "updated_at": datetime(2026, 1, 2),
}

MOCK_VENDOR_PROFILE = {
    "name": "Vendor User",
    "phone": "+52 33 0000 0002",
    "role": "VENDOR",
    "fcm_token": None,
    "last_location": None,
    "last_location_at": None,
    "created_at": datetime(2026, 1, 1),
    "updated_at": datetime(2026, 1, 2),
}


def _make_subscription(active: bool = True, buyer_uid: str = BUYER_UID):
    from modules.shared.subscription_schemas import Subscription

    return Subscription(
        id=f"{buyer_uid}_{VENDOR_UID}",
        buyer_uid=buyer_uid,
        vendor_uid=VENDOR_UID,
        active=active,
        created_at="2026-01-01T00:00:00+00:00",
        cancelled_at=None if active else "2026-01-02T00:00:00+00:00",
        cancellation_reason=None if active else "user_cancelled",
    )


@pytest.fixture
def mock_firebase():
    with patch("main.FirebaseAdminInit.initialize"):
        yield


@pytest.fixture
def mock_buyer_token():
    with patch("dependencies.auth.verify_id_token", return_value=BUYER_TOKEN):
        yield


@pytest.fixture
def mock_vendor_token():
    with patch("dependencies.auth.verify_id_token", return_value=VENDOR_TOKEN):
        yield


@pytest.fixture
def mock_get_user_buyer():
    from modules.identity.schemas import UserProfile

    profile = UserProfile(uid=BUYER_UID, **MOCK_BUYER_PROFILE)
    with patch(
        "modules.shared.subscription_router.FirestoreService.get_user",
        new_callable=AsyncMock,
        return_value=profile,
    ):
        yield profile


@pytest.fixture
def mock_get_user_vendor():
    from modules.identity.schemas import UserProfile

    profile = UserProfile(uid=VENDOR_UID, **MOCK_VENDOR_PROFILE)
    with patch(
        "modules.shared.subscription_router.FirestoreService.get_user",
        new_callable=AsyncMock,
        return_value=profile,
    ):
        yield profile


# ── POST /subscriptions ───────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_buyer_can_subscribe_to_vendor(mock_firebase, mock_buyer_token, mock_get_user_buyer):
    """Buyer subscribes → 201 + subscription returned."""
    from main import app

    sub = _make_subscription(active=True)
    with (
        patch(
            "modules.shared.subscription_router.FirestoreService.get_subscription",
            new_callable=AsyncMock,
            return_value=None,
        ),
        patch(
            "modules.shared.subscription_router.FirestoreService.create_subscription",
            new_callable=AsyncMock,
            return_value=sub,
        ),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/subscriptions",
                headers={"Authorization": "Bearer valid"},
                json={"vendor_uid": VENDOR_UID},
            )
    assert response.status_code == 201
    body = response.json()
    assert body["buyer_uid"] == BUYER_UID
    assert body["vendor_uid"] == VENDOR_UID
    assert body["active"] is True


@pytest.mark.asyncio
async def test_buyer_cannot_subscribe_twice_returns_409(
    mock_firebase, mock_buyer_token, mock_get_user_buyer
):
    """Active subscription already exists → 409."""
    from main import app

    sub = _make_subscription(active=True)
    with patch(
        "modules.shared.subscription_router.FirestoreService.get_subscription",
        new_callable=AsyncMock,
        return_value=sub,
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/subscriptions",
                headers={"Authorization": "Bearer valid"},
                json={"vendor_uid": VENDOR_UID},
            )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_inactive_subscription_gets_reactivated(
    mock_firebase, mock_buyer_token, mock_get_user_buyer
):
    """Cancelled subscription → reactivated → 201."""
    from main import app

    inactive_sub = _make_subscription(active=False)
    reactivated_sub = _make_subscription(active=True)
    with (
        patch(
            "modules.shared.subscription_router.FirestoreService.get_subscription",
            new_callable=AsyncMock,
            return_value=inactive_sub,
        ),
        patch(
            "modules.shared.subscription_router.FirestoreService.create_subscription",
            new_callable=AsyncMock,
            return_value=reactivated_sub,
        ),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.post(
                "/subscriptions",
                headers={"Authorization": "Bearer valid"},
                json={"vendor_uid": VENDOR_UID},
            )
    assert response.status_code == 201
    assert response.json()["active"] is True


@pytest.mark.asyncio
async def test_vendor_cannot_subscribe_returns_403(
    mock_firebase, mock_vendor_token, mock_get_user_vendor
):
    """VENDOR role → 403."""
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post(
            "/subscriptions",
            headers={"Authorization": "Bearer valid"},
            json={"vendor_uid": BUYER_UID},
        )
    assert response.status_code == 403


# ── GET /subscriptions ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_returns_only_active(mock_firebase, mock_buyer_token):
    """GET /subscriptions returns only the active subscriptions from Firestore."""
    from main import app

    active_sub = _make_subscription(active=True)
    with patch(
        "modules.shared.subscription_router.FirestoreService.list_active_subscriptions",
        new_callable=AsyncMock,
        return_value=[active_sub],
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.get(
                "/subscriptions",
                headers={"Authorization": "Bearer valid"},
            )
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["active"] is True


# ── DELETE /subscriptions/{id} ────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_delete_marks_inactive(mock_firebase, mock_buyer_token):
    """DELETE → calls cancel_subscription → 204."""
    from main import app

    sub = _make_subscription(active=True)
    with (
        patch(
            "modules.shared.subscription_router.FirestoreService.get_subscription",
            new_callable=AsyncMock,
            return_value=sub,
        ),
        patch(
            "modules.shared.subscription_router.FirestoreService.cancel_subscription",
            new_callable=AsyncMock,
        ) as mock_cancel,
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.delete(
                f"/subscriptions/{sub.id}",
                headers={"Authorization": "Bearer valid"},
            )
    assert response.status_code == 204
    mock_cancel.assert_awaited_once_with(sub.id, "user_cancelled")


@pytest.mark.asyncio
async def test_delete_other_users_subscription_returns_403(mock_firebase, mock_buyer_token):
    """Buyer cannot cancel a subscription belonging to another buyer → 403."""
    from main import app

    other_sub = _make_subscription(active=True, buyer_uid=OTHER_UID)
    with patch(
        "modules.shared.subscription_router.FirestoreService.get_subscription",
        new_callable=AsyncMock,
        return_value=other_sub,
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            response = await client.delete(
                f"/subscriptions/{other_sub.id}",
                headers={"Authorization": "Bearer valid"},
            )
    assert response.status_code == 403
