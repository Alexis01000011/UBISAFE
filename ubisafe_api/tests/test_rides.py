"""F6 — RideRouter tests: role validation, state machine, vendor_arrived."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from modules.dispatching.ride_schemas import Ride, RideStatus
from modules.safety.schemas import GeoPoint

BUYER_UID = "buyer-ride-123"
VENDOR_UID = "vendor-ride-456"
OTHER_UID = "other-ride-789"
RIDE_ID = "ride-doc-abc"

_BUYER_TOKEN = {"uid": BUYER_UID}
_VENDOR_TOKEN = {"uid": VENDOR_UID}
_OTHER_TOKEN = {"uid": OTHER_UID}

_PICKUP = GeoPoint(lat=20.6736, lng=-103.344)
_DEST = GeoPoint(lat=20.690, lng=-103.360)

_PENDING_RIDE = Ride(
    id=RIDE_ID,
    buyer_uid=BUYER_UID,
    vendor_uid=VENDOR_UID,
    pickup_location=_PICKUP,
    destination=_DEST,
    status=RideStatus.pending,
)
_ACCEPTED_RIDE = Ride(
    id=RIDE_ID,
    buyer_uid=BUYER_UID,
    vendor_uid=VENDOR_UID,
    pickup_location=_PICKUP,
    destination=_DEST,
    status=RideStatus.accepted,
)
_IN_PROGRESS_RIDE = Ride(
    id=RIDE_ID,
    buyer_uid=BUYER_UID,
    vendor_uid=VENDOR_UID,
    pickup_location=_PICKUP,
    destination=_DEST,
    status=RideStatus.in_progress,
)

_R = "modules.dispatching.ride_router"
_GET_USER = f"{_R}.FirestoreService.get_user"
_VENDOR_BUSY = f"{_R}.FirestoreService.vendor_has_active_requests"
_CREATE_RIDE = f"{_R}.FirestoreService.create_ride"
_GET_RIDE = f"{_R}.FirestoreService.get_ride"
_UPD_STATUS = f"{_R}.FirestoreService.update_ride_status"
_UPD_PENDING = f"{_R}.FirestoreService.update_ride_status_if_pending"
_NOTIF_INCOMING = f"{_R}.NotificationService.send_ride_incoming"
_NOTIF_ACCEPTED = f"{_R}.NotificationService.send_ride_accepted"
_NOTIF_REJECTED = f"{_R}.NotificationService.send_ride_rejected"
_NOTIF_ARRIVED = f"{_R}.NotificationService.send_ride_vendor_arrived"


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

    return UserProfile(uid=BUYER_UID, name="Buyer", role="BUYER", fcm_token="tok-b")


def _vendor_profile(ride_enabled: bool = True):
    from modules.identity.schemas import UserProfile

    return UserProfile(
        uid=VENDOR_UID,
        name="Vendor",
        role="VENDOR",
        fcm_token="tok-v",
        ride_enabled=ride_enabled,
    )


def _other_profile():
    from modules.identity.schemas import UserProfile

    return UserProfile(uid=OTHER_UID, name="Other", role="BUYER")


# ── POST /rides ──────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_ride_no_token(mock_firebase):
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        r = await c.post(
            "/rides",
            json={
                "vendor_uid": VENDOR_UID,
                "pickup_location": {"lat": 20.0, "lng": -103.0},
                "destination": {"lat": 20.01, "lng": -103.01},
            },
        )
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_create_ride_as_buyer(mock_firebase, as_buyer):
    from main import app

    with (
        patch(_GET_USER, new_callable=AsyncMock, side_effect=[_buyer_profile(), _vendor_profile()]),
        patch(_VENDOR_BUSY, new_callable=AsyncMock, return_value=False),
        patch(_CREATE_RIDE, new_callable=AsyncMock, return_value=_PENDING_RIDE),
        patch(_NOTIF_INCOMING, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.post(
                "/rides",
                headers={"Authorization": "Bearer tok"},
                json={
                    "vendor_uid": VENDOR_UID,
                    "pickup_location": {"lat": 20.6736, "lng": -103.344},
                    "destination": {"lat": 20.690, "lng": -103.360},
                },
            )
    assert r.status_code == 201
    assert r.json()["status"] == "pending"
    assert r.json()["buyer_uid"] == BUYER_UID


@pytest.mark.asyncio
async def test_create_ride_as_vendor_returns_403(mock_firebase, as_vendor):
    from main import app

    with patch(_GET_USER, new_callable=AsyncMock, return_value=_vendor_profile()):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.post(
                "/rides",
                headers={"Authorization": "Bearer tok"},
                json={
                    "vendor_uid": VENDOR_UID,
                    "pickup_location": {"lat": 20.0, "lng": -103.0},
                    "destination": {"lat": 20.01, "lng": -103.01},
                },
            )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_create_ride_vendor_not_available_returns_409(mock_firebase, as_buyer):
    from main import app

    with (
        patch(_GET_USER, new_callable=AsyncMock, side_effect=[_buyer_profile(), _vendor_profile()]),
        patch(_VENDOR_BUSY, new_callable=AsyncMock, return_value=True),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.post(
                "/rides",
                headers={"Authorization": "Bearer tok"},
                json={
                    "vendor_uid": VENDOR_UID,
                    "pickup_location": {"lat": 20.0, "lng": -103.0},
                    "destination": {"lat": 20.01, "lng": -103.01},
                },
            )
    assert r.status_code == 409
    assert r.json()["detail"] == "vendor_not_available"


# ── GET /rides/{id} ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_ride_as_buyer(mock_firebase, as_buyer):
    from main import app

    with patch(_GET_RIDE, new_callable=AsyncMock, return_value=_PENDING_RIDE):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.get(f"/rides/{RIDE_ID}", headers={"Authorization": "Bearer tok"})
    assert r.status_code == 200


@pytest.mark.asyncio
async def test_get_ride_forbidden_for_unrelated_user(mock_firebase, as_other):
    from main import app

    with patch(_GET_RIDE, new_callable=AsyncMock, return_value=_PENDING_RIDE):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.get(f"/rides/{RIDE_ID}", headers={"Authorization": "Bearer tok"})
    assert r.status_code == 403


# ── PATCH /rides/{id}/status ─────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_vendor_accepts_pending_ride(mock_firebase, as_vendor):
    from main import app

    with (
        patch(_GET_RIDE, new_callable=AsyncMock, return_value=_PENDING_RIDE),
        patch(_GET_USER, new_callable=AsyncMock, return_value=_vendor_profile()),
        patch(_UPD_STATUS, new_callable=AsyncMock, return_value=_ACCEPTED_RIDE),
        patch(_NOTIF_ACCEPTED, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.patch(
                f"/rides/{RIDE_ID}/status",
                headers={"Authorization": "Bearer tok"},
                json={"status": "accepted"},
            )
    assert r.status_code == 200
    assert r.json()["status"] == "accepted"


@pytest.mark.asyncio
async def test_invalid_transition_returns_400(mock_firebase, as_vendor):
    from main import app

    with patch(_GET_RIDE, new_callable=AsyncMock, return_value=_ACCEPTED_RIDE):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.patch(
                f"/rides/{RIDE_ID}/status",
                headers={"Authorization": "Bearer tok"},
                json={"status": "pending"},
            )
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_buyer_cannot_accept_ride_returns_403(mock_firebase, as_buyer):
    from main import app

    with (
        patch(_GET_RIDE, new_callable=AsyncMock, return_value=_PENDING_RIDE),
        patch(_GET_USER, new_callable=AsyncMock, return_value=_buyer_profile()),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.patch(
                f"/rides/{RIDE_ID}/status",
                headers={"Authorization": "Bearer tok"},
                json={"status": "accepted"},
            )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_race_condition_buyer_expire_returns_409(mock_firebase, as_buyer):
    from main import app

    with (
        patch(_GET_RIDE, new_callable=AsyncMock, return_value=_PENDING_RIDE),
        patch(_GET_USER, new_callable=AsyncMock, return_value=_buyer_profile()),
        patch(_UPD_PENDING, new_callable=AsyncMock, return_value=(_ACCEPTED_RIDE, False)),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.patch(
                f"/rides/{RIDE_ID}/status",
                headers={"Authorization": "Bearer tok"},
                json={"status": "expired"},
            )
    assert r.status_code == 409


# ── POST /rides/{id}/vendor_arrived ─────────────────────────────────────────


@pytest.mark.asyncio
async def test_vendor_arrived_sends_fcm(mock_firebase, as_vendor):
    from main import app

    with (
        patch(_GET_USER, new_callable=AsyncMock, return_value=_vendor_profile()),
        patch(_GET_RIDE, new_callable=AsyncMock, return_value=_ACCEPTED_RIDE),
        patch(_NOTIF_ARRIVED, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.post(
                f"/rides/{RIDE_ID}/vendor_arrived",
                headers={"Authorization": "Bearer tok"},
            )
    assert r.status_code == 204


@pytest.mark.asyncio
async def test_vendor_arrived_buyer_cannot_call(mock_firebase, as_buyer):
    from main import app

    with patch(_GET_USER, new_callable=AsyncMock, return_value=_buyer_profile()):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
            r = await c.post(
                f"/rides/{RIDE_ID}/vendor_arrived",
                headers={"Authorization": "Bearer tok"},
            )
    assert r.status_code == 403
