"""CU-09-A/B — group_stay_router tests: POST, GET, cancel, attendances."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from modules.dispatching.group_stay_schemas import GroupStay
from modules.safety.schemas import GeoPoint, RiskZone

VENDOR_UID = "vendor-uid-stay"
BUYER_UID = "buyer-uid-stay"
STAY_ID = "stay-doc-001"

_VENDOR_TOKEN = {"uid": VENDOR_UID}
_BUYER_TOKEN = {"uid": BUYER_UID}
_AUTH = {"Authorization": "Bearer tok"}

_LOCATION = GeoPoint(lat=20.6736, lng=-103.344)

_FUTURE_START = (datetime.now(tz=UTC) + timedelta(hours=2)).isoformat()
_FUTURE_START_DT = datetime.now(tz=UTC) + timedelta(hours=2)
_FUTURE_END_DT = _FUTURE_START_DT + timedelta(hours=1)

_CREATED_STAY = GroupStay(
    id=STAY_ID,
    vendor_uid=VENDOR_UID,
    location=_LOCATION,
    start_at=_FUTURE_START_DT.isoformat(),
    end_at=_FUTURE_END_DT.isoformat(),
    duration_minutes=60,
    status="scheduled",
    attendees_count=0,
)

_VENDOR_PROFILE = type("P", (), {"role": "VENDOR"})()
_BUYER_PROFILE = type("P", (), {"role": "BUYER"})()

_FS_GET_USER = "modules.shared.firestore_service.FirestoreService.get_user"
_FS_GET_LOCATION = "modules.shared.firestore_service.FirestoreService.get_user_last_location"
_FS_CREATE = "modules.shared.firestore_service.FirestoreService.create_group_stay"
_FS_ZONES = "modules.shared.firestore_service.FirestoreService.get_active_risk_zones_near"
_FS_OVERLAP = "modules.shared.firestore_service.FirestoreService.vendor_has_overlapping_stay"
_FS_LIST_ACTIVE = "modules.shared.firestore_service.FirestoreService.list_active_group_stays"
_FS_GET_STAY = "modules.shared.firestore_service.FirestoreService.get_group_stay"
_FS_CANCEL = "modules.shared.firestore_service.FirestoreService.cancel_group_stay"
_FS_ATTENDANCES = "modules.shared.firestore_service.FirestoreService.get_confirmed_attendance_uids"
_FS_NEARBY = "modules.shared.firestore_service.FirestoreService.get_nearby_user_fcm_tokens"
_FS_CONFIRM_ATT = "modules.shared.firestore_service.FirestoreService.confirm_attendance"
_NS_CANCEL_NEARBY = "modules.shared.notification_service.NotificationService.send_group_stay_cancelled_nearby"
_NS_CREATED = "modules.shared.notification_service.NotificationService.send_group_stay_created"


@pytest.fixture
def mock_firebase():
    with patch("main.FirebaseAdminInit.initialize"):
        yield


@pytest.fixture
def as_vendor():
    with patch("dependencies.auth.verify_id_token", return_value=_VENDOR_TOKEN):
        yield


@pytest.fixture
def as_buyer():
    with patch("dependencies.auth.verify_id_token", return_value=_BUYER_TOKEN):
        yield


def _stay_body(start_iso: str | None = None, duration: int = 60) -> dict:
    return {
        "location": {"lat": _LOCATION.lat, "lng": _LOCATION.lng},
        "start_at": start_iso or _FUTURE_START,
        "duration_minutes": duration,
        # Include real-time vendor GPS so the router takes the body path and
        # skips the Firestore last_location lookup (0 km distance → always valid).
        "vendor_lat": _LOCATION.lat,
        "vendor_lng": _LOCATION.lng,
    }


# ── POST /group-stays ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_vendor_can_create_stay(mock_firebase, as_vendor):
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE),
        patch(_FS_GET_LOCATION, new_callable=AsyncMock, return_value=None),
        patch(_FS_ZONES, new_callable=AsyncMock, return_value=[]),
        patch(_FS_OVERLAP, new_callable=AsyncMock, return_value=False),
        patch(_FS_CREATE, new_callable=AsyncMock, return_value=_CREATED_STAY),
        patch(_FS_NEARBY, new_callable=AsyncMock, return_value=[]),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/group-stays", json=_stay_body(), headers=_AUTH)

    assert res.status_code == 201
    body = res.json()
    assert body["stay"]["status"] == "scheduled"
    assert body["warning"] is None


@pytest.mark.asyncio
async def test_create_rejected_if_zone_high_422(mock_firebase, as_vendor):
    from main import app

    high_zone = RiskZone(
        id="rz-high-01",
        reporter_uid="someone",
        threat_type="asalto",
        risk_level="HIGH",
        location=_LOCATION,
        radius_meters=100,
        active=True,
        created_at=datetime.now(tz=UTC).isoformat(),
        expires_at=(datetime.now(tz=UTC) + timedelta(hours=24)).isoformat(),
    )

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE),
        patch(_FS_GET_LOCATION, new_callable=AsyncMock, return_value=None),
        patch(_FS_ZONES, new_callable=AsyncMock, return_value=[high_zone]),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/group-stays", json=_stay_body(), headers=_AUTH)

    assert res.status_code == 422
    assert res.json()["detail"]["error"] == "zone_high"
    assert "rz-high-01" in res.json()["detail"]["risk_zone_ids"]


@pytest.mark.asyncio
async def test_create_returns_warning_for_medium_zone(mock_firebase, as_vendor):
    """POST sin acknowledged_risk_warning en zona MEDIUM devuelve 200 + stay=null.

    La estancia NO se crea: no se llama a FirestoreService.create_group_stay ni
    a NotificationService, evitando el spam de notificaciones antes de confirmar.
    """
    from main import app

    medium_zone = RiskZone(
        id="rz-med-01",
        reporter_uid="someone",
        threat_type="robo",
        risk_level="MEDIUM",
        location=_LOCATION,
        radius_meters=100,
        active=True,
        created_at=datetime.now(tz=UTC).isoformat(),
        expires_at=(datetime.now(tz=UTC) + timedelta(hours=24)).isoformat(),
    )

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE),
        patch(_FS_GET_LOCATION, new_callable=AsyncMock, return_value=None),
        patch(_FS_ZONES, new_callable=AsyncMock, return_value=[medium_zone]),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/group-stays", json=_stay_body(), headers=_AUTH)

    assert res.status_code == 200  # advertencia, no creación
    body = res.json()
    assert body["stay"] is None  # la estancia aún no existe
    assert body["warning"] is not None
    assert body["warning"]["risk_level"] == "MEDIUM"
    assert body["warning"]["risk_zone_id"] == "rz-med-01"


@pytest.mark.asyncio
async def test_create_with_acknowledged_risk_creates_stay(mock_firebase, as_vendor):
    """POST con acknowledged_risk_warning=True crea la estancia aunque haya zona MEDIUM."""
    from main import app

    medium_zone = RiskZone(
        id="rz-med-01",
        reporter_uid="someone",
        threat_type="robo",
        risk_level="MEDIUM",
        location=_LOCATION,
        radius_meters=100,
        active=True,
        created_at=datetime.now(tz=UTC).isoformat(),
        expires_at=(datetime.now(tz=UTC) + timedelta(hours=24)).isoformat(),
    )

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE),
        patch(_FS_GET_LOCATION, new_callable=AsyncMock, return_value=None),
        patch(_FS_ZONES, new_callable=AsyncMock, return_value=[medium_zone]),
        patch(_FS_OVERLAP, new_callable=AsyncMock, return_value=False),
        patch(_FS_CREATE, new_callable=AsyncMock, return_value=_CREATED_STAY),
        patch(_FS_NEARBY, new_callable=AsyncMock, return_value=[]),
    ):
        body = {**_stay_body(), "acknowledged_risk_warning": True}
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/group-stays", json=body, headers=_AUTH)

    assert res.status_code == 201
    data = res.json()
    assert data["stay"]["status"] == "scheduled"
    assert data["warning"] is None


@pytest.mark.asyncio
async def test_create_rejected_overlap_409(mock_firebase, as_vendor):
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE),
        patch(_FS_GET_LOCATION, new_callable=AsyncMock, return_value=None),
        patch(_FS_ZONES, new_callable=AsyncMock, return_value=[]),
        patch(_FS_OVERLAP, new_callable=AsyncMock, return_value=True),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/group-stays", json=_stay_body(), headers=_AUTH)

    assert res.status_code == 409
    assert res.json()["detail"] == "vendor_has_active_stay"


@pytest.mark.asyncio
async def test_buyer_cannot_create_stay_403(mock_firebase, as_buyer):
    from main import app

    with patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_BUYER_PROFILE):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/group-stays", json=_stay_body(), headers=_AUTH)

    assert res.status_code == 403


# ── GET /group-stays ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_active_stays_returns_200(mock_firebase, as_vendor):
    from main import app

    with patch(_FS_LIST_ACTIVE, new_callable=AsyncMock, return_value=[_CREATED_STAY]):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.get(
                "/group-stays",
                params={"lat": 20.6736, "lng": -103.344},
                headers=_AUTH,
            )

    assert res.status_code == 200
    assert len(res.json()) == 1
    assert res.json()[0]["id"] == STAY_ID


# ── PATCH /group-stays/{id}/cancel ───────────────────────────────────────────


@pytest.mark.asyncio
async def test_vendor_can_cancel_own_stay(mock_firebase, as_vendor):
    from main import app

    cancelled_stay = GroupStay(
        id=STAY_ID,
        vendor_uid=VENDOR_UID,
        location=_LOCATION,
        start_at=_FUTURE_START_DT.isoformat(),
        end_at=_FUTURE_END_DT.isoformat(),
        duration_minutes=60,
        status="cancelled",
        cancellation_reason="vendor_cancelled",
        attendees_count=0,
    )

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE),
        patch(_FS_GET_STAY, new_callable=AsyncMock, return_value=_CREATED_STAY),
        patch(_FS_CANCEL, new_callable=AsyncMock, return_value=cancelled_stay),
        patch(_FS_NEARBY, new_callable=AsyncMock, return_value=[]),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.patch(f"/group-stays/{STAY_ID}/cancel", headers=_AUTH)

    assert res.status_code == 200
    assert res.json()["status"] == "cancelled"
    assert res.json()["cancellation_reason"] == "vendor_cancelled"


# ── POST /group-stays/{id}/attendances ───────────────────────────────────────


@pytest.mark.asyncio
async def test_buyer_can_confirm_attendance(mock_firebase, as_buyer):
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_BUYER_PROFILE),
        patch(_FS_GET_STAY, new_callable=AsyncMock, return_value=_CREATED_STAY),
        patch(_FS_CONFIRM_ATT, new_callable=AsyncMock, return_value=None),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(
                f"/group-stays/{STAY_ID}/attendances", headers=_AUTH
            )

    assert res.status_code == 204


@pytest.mark.asyncio
async def test_vendor_cannot_confirm_attendance(mock_firebase, as_vendor):
    from main import app

    with patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(
                f"/group-stays/{STAY_ID}/attendances", headers=_AUTH
            )

    assert res.status_code == 403


@pytest.mark.asyncio
async def test_confirm_attendance_calls_firestore_with_correct_args(mock_firebase, as_buyer):
    """POST /attendances delegates to FirestoreService.confirm_attendance(stay_id, buyer_uid)."""
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_BUYER_PROFILE),
        patch(_FS_GET_STAY, new_callable=AsyncMock, return_value=_CREATED_STAY),
        patch(_FS_CONFIRM_ATT, new_callable=AsyncMock, return_value=None) as mock_confirm,
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(
                f"/group-stays/{STAY_ID}/attendances", headers=_AUTH
            )

    assert res.status_code == 204
    mock_confirm.assert_awaited_once_with(STAY_ID, BUYER_UID)


@pytest.mark.asyncio
async def test_double_confirm_is_idempotent(mock_firebase, as_buyer):
    """Two consecutive POST /attendances calls both return 204 (idempotency in FS layer)."""
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_BUYER_PROFILE),
        patch(_FS_GET_STAY, new_callable=AsyncMock, return_value=_CREATED_STAY),
        patch(_FS_CONFIRM_ATT, new_callable=AsyncMock, return_value=None),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res1 = await client.post(
                f"/group-stays/{STAY_ID}/attendances", headers=_AUTH
            )
            res2 = await client.post(
                f"/group-stays/{STAY_ID}/attendances", headers=_AUTH
            )

    assert res1.status_code == 204
    assert res2.status_code == 204


@pytest.mark.asyncio
async def test_vendor_cancel_notifies_nearby_users(mock_firebase, as_vendor):
    """PATCH /cancel multicast group_stay_cancelled_nearby to all nearby FCM tokens."""
    import asyncio

    from main import app

    cancelled_stay = GroupStay(
        id=STAY_ID,
        vendor_uid=VENDOR_UID,
        location=_LOCATION,
        start_at=_FUTURE_START_DT.isoformat(),
        end_at=_FUTURE_END_DT.isoformat(),
        duration_minutes=60,
        status="cancelled",
        cancellation_reason="vendor_cancelled",
        attendees_count=1,
    )
    _nearby_tokens = ["buyer-fcm-token"]

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE),
        patch(_FS_GET_STAY, new_callable=AsyncMock, return_value=_CREATED_STAY),
        patch(_FS_CANCEL, new_callable=AsyncMock, return_value=cancelled_stay),
        patch(_FS_NEARBY, new_callable=AsyncMock, return_value=_nearby_tokens),
        patch(_NS_CANCEL_NEARBY, new_callable=AsyncMock) as mock_notify,
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.patch(f"/group-stays/{STAY_ID}/cancel", headers=_AUTH)
        # Flush asyncio.ensure_future so the fire-and-forget coroutine executes
        await asyncio.sleep(0)

    assert res.status_code == 200
    mock_notify.assert_awaited_once_with(_nearby_tokens, STAY_ID, "vendor_cancelled", vendor_uid=VENDOR_UID)
