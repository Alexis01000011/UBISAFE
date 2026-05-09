"""F4.1 — StopRequestRouter tests: role validation, state machine, race condition."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from modules.dispatching.schemas import GeoPoint, StopRequest

BUYER_UID = "buyer-uid-123"
VENDOR_UID = "vendor-uid-456"
OTHER_UID = "other-uid-789"
STOP_ID = "stop-doc-abc"

_BUYER_TOKEN = {"uid": BUYER_UID, "email": "buyer@test.com"}
_VENDOR_TOKEN = {"uid": VENDOR_UID, "email": "vendor@test.com"}
_OTHER_TOKEN = {"uid": OTHER_UID, "email": "other@test.com"}

_PENDING_STOP = StopRequest(
    id=STOP_ID,
    buyer_uid=BUYER_UID,
    vendor_uid=VENDOR_UID,
    buyer_location=GeoPoint(lat=20.6736, lng=-103.344),
    status="pending",
)
_ACCEPTED_STOP = StopRequest(
    id=STOP_ID,
    buyer_uid=BUYER_UID,
    vendor_uid=VENDOR_UID,
    buyer_location=GeoPoint(lat=20.6736, lng=-103.344),
    status="accepted",
)

# ── Short patch path aliases ──────────────────────────────────────────────────
_R = "modules.dispatching.router"
_GET_USER = f"{_R}.FirestoreService.get_user"
_GET_STOP = f"{_R}.FirestoreService.get_stop_request"
_CREATE_STOP = f"{_R}.FirestoreService.create_stop_request"
_UPD_STATUS = f"{_R}.FirestoreService.update_stop_status"
_UPD_PENDING = f"{_R}.FirestoreService.update_stop_status_if_pending"
_NOTIF_INCOMING = f"{_R}.NotificationService.send_stop_incoming"
_NOTIF_ACCEPTED = f"{_R}.NotificationService.send_stop_accepted"


@pytest.fixture
def mock_firebase():
    with patch("main.FirebaseAdminInit.initialize"):
        yield


@pytest.fixture
def as_buyer():
    with patch("dependencies.auth.verify_id_token", return_value=_BUYER_TOKEN):
        yield


@pytest.fixture
def as_vendor():
    with patch("dependencies.auth.verify_id_token", return_value=_VENDOR_TOKEN):
        yield


@pytest.fixture
def as_other():
    with patch("dependencies.auth.verify_id_token", return_value=_OTHER_TOKEN):
        yield


def _buyer_profile():
    from modules.identity.schemas import UserProfile

    return UserProfile(uid=BUYER_UID, name="Buyer", role="BUYER", fcm_token="tok-buyer")


def _vendor_profile():
    from modules.identity.schemas import UserProfile

    return UserProfile(uid=VENDOR_UID, name="Vendor", role="VENDOR", fcm_token="tok-vendor")


def _other_profile():
    from modules.identity.schemas import UserProfile

    return UserProfile(uid=OTHER_UID, name="Other", role="BUYER", fcm_token="tok-other")


# ── POST /stops ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_stop_no_token(mock_firebase):
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        r = await c.post(
            "/stops",
            json={"vendor_uid": VENDOR_UID, "buyer_location": {"lat": 20.0, "lng": -103.0}},
        )
    assert r.status_code == 401  # HTTPBearer rejects missing Authorization header


@pytest.mark.asyncio
async def test_create_stop_as_buyer(mock_firebase, as_buyer):
    from main import app

    with (
        patch(_GET_USER, new_callable=AsyncMock, return_value=_buyer_profile()),
        patch(_CREATE_STOP, new_callable=AsyncMock, return_value=_PENDING_STOP),
        patch(_NOTIF_INCOMING, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.post(
                "/stops",
                headers={"Authorization": "Bearer tok"},
                json={
                    "vendor_uid": VENDOR_UID,
                    "buyer_location": {"lat": 20.6736, "lng": -103.344},
                },
            )
    assert r.status_code == 201
    assert r.json()["status"] == "pending"
    assert r.json()["buyer_uid"] == BUYER_UID


@pytest.mark.asyncio
async def test_create_stop_as_vendor_returns_403(mock_firebase, as_vendor):
    from main import app

    with patch(_GET_USER, new_callable=AsyncMock, return_value=_vendor_profile()):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.post(
                "/stops",
                headers={"Authorization": "Bearer tok"},
                json={
                    "vendor_uid": VENDOR_UID,
                    "buyer_location": {"lat": 20.0, "lng": -103.0},
                },
            )
    assert r.status_code == 403


# ── GET /stops/{id} ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_stop_as_buyer(mock_firebase, as_buyer):
    from main import app

    with patch(_GET_STOP, new_callable=AsyncMock, return_value=_PENDING_STOP):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.get(f"/stops/{STOP_ID}", headers={"Authorization": "Bearer tok"})
    assert r.status_code == 200


@pytest.mark.asyncio
async def test_get_stop_forbidden_for_unrelated_user(mock_firebase, as_other):
    from main import app

    with patch(_GET_STOP, new_callable=AsyncMock, return_value=_PENDING_STOP):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.get(f"/stops/{STOP_ID}", headers={"Authorization": "Bearer tok"})
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_get_stop_not_found(mock_firebase, as_buyer):
    from main import app

    with patch(_GET_STOP, new_callable=AsyncMock, return_value=None):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.get("/stops/nonexistent", headers={"Authorization": "Bearer tok"})
    assert r.status_code == 404


# ── PATCH /stops/{id}/status ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_vendor_accepts_pending_stop(mock_firebase, as_vendor):
    from main import app

    with (
        patch(_GET_STOP, new_callable=AsyncMock, return_value=_PENDING_STOP),
        patch(_GET_USER, new_callable=AsyncMock, return_value=_vendor_profile()),
        patch(_UPD_STATUS, new_callable=AsyncMock, return_value=_ACCEPTED_STOP),
        patch(_NOTIF_ACCEPTED, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.patch(
                f"/stops/{STOP_ID}/status",
                headers={"Authorization": "Bearer tok"},
                json={"status": "accepted"},
            )
    assert r.status_code == 200
    assert r.json()["status"] == "accepted"


@pytest.mark.asyncio
async def test_invalid_transition_returns_400(mock_firebase, as_vendor):
    """accepted → pending is not a valid transition."""
    from main import app

    with patch(_GET_STOP, new_callable=AsyncMock, return_value=_ACCEPTED_STOP):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.patch(
                f"/stops/{STOP_ID}/status",
                headers={"Authorization": "Bearer tok"},
                json={"status": "pending"},
            )
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_buyer_cannot_accept_stop_returns_403(mock_firebase, as_buyer):
    """BUYER cannot set status=accepted (VENDOR-only transition)."""
    from main import app

    with (
        patch(_GET_STOP, new_callable=AsyncMock, return_value=_PENDING_STOP),
        patch(_GET_USER, new_callable=AsyncMock, return_value=_buyer_profile()),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.patch(
                f"/stops/{STOP_ID}/status",
                headers={"Authorization": "Bearer tok"},
                json={"status": "accepted"},
            )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_race_condition_buyer_expire_returns_409(mock_firebase, as_buyer):
    """Buyer sends 'expired' but vendor already changed status → 409."""
    from main import app

    with (
        patch(_GET_STOP, new_callable=AsyncMock, return_value=_PENDING_STOP),
        patch(_GET_USER, new_callable=AsyncMock, return_value=_buyer_profile()),
        patch(
            _UPD_PENDING,
            new_callable=AsyncMock,
            return_value=(_ACCEPTED_STOP, False),
        ),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.patch(
                f"/stops/{STOP_ID}/status",
                headers={"Authorization": "Bearer tok"},
                json={"status": "expired"},
            )
    assert r.status_code == 409
