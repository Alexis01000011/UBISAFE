"""F5 — RiskZoneRouter tests: creación, validación, filtrado geo, expiración, 401/403/404."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from modules.safety.schemas import GeoPoint, RiskZone

REPORTER_UID = "reporter-uid-111"
OTHER_UID = "other-uid-222"
ZONE_ID = "rz-high-001"

_REPORTER_TOKEN = {"uid": REPORTER_UID, "email": "reporter@test.com"}
_OTHER_TOKEN = {"uid": OTHER_UID, "email": "other@test.com"}

_HIGH_ZONE = RiskZone(
    id=ZONE_ID,
    reporter_uid=REPORTER_UID,
    threat_type="Robo/Asalto",
    risk_level="HIGH",
    location=GeoPoint(lat=20.6741, lng=-103.4451),
    radius_meters=100,
    active=True,
    created_at="2026-04-28T10:00:00+00:00",
    expires_at="2026-04-29T10:00:00+00:00",
    expired_at=None,
)

_ZONE_DICT = {
    "id": ZONE_ID,
    "reporter_uid": REPORTER_UID,
    "threat_type": "Robo/Asalto",
    "risk_level": "HIGH",
    "location": {"lat": 20.6741, "lng": -103.4451},
    "radius_meters": 100,
    "active": True,
    "created_at": "2026-04-28T10:00:00+00:00",
    "expires_at": "2026-04-29T10:00:00+00:00",
    "expired_at": None,
}

_AUTH = {"Authorization": "Bearer tok"}

_R = "modules.safety.router"
_QUERY_BBOX = f"{_R}.FirestoreService.query_active_risk_zones_bbox"
_CREATE_ZONE = f"{_R}.FirestoreService.create_risk_zone"
_GET_ZONES = f"{_R}.FirestoreService.get_active_risk_zones"
_GET_ZONE = f"{_R}.FirestoreService.get_risk_zone"
_EXPIRE_ZONE = f"{_R}.FirestoreService.expire_risk_zone"
_GET_TOKENS = f"{_R}.FirestoreService.get_nearby_user_fcm_tokens"
_NOTIFY = f"{_R}.NotificationService.notify_risk_zone_alert"


@pytest.fixture
def mock_firebase():
    with patch("main.FirebaseAdminInit.initialize"):
        yield


@pytest.fixture
def as_reporter():
    with patch("dependencies.auth.verify_id_token", return_value=_REPORTER_TOKEN):
        yield


@pytest.fixture
def as_other():
    with patch("dependencies.auth.verify_id_token", return_value=_OTHER_TOKEN):
        yield


# ── POST /risk-zones/ ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_zone_no_token(mock_firebase):
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post(
            "/risk-zones",
            json={
                "threat_type": "Robo",
                "risk_level": "HIGH",
                "location": {"lat": 20.67, "lng": -103.34},
            },
        )

    assert res.status_code == 401


@pytest.mark.asyncio
async def test_create_zone_success(mock_firebase, as_reporter):
    from main import app

    with (
        patch(_QUERY_BBOX, new_callable=AsyncMock, return_value=[]),
        patch(_CREATE_ZONE, new_callable=AsyncMock, return_value=_HIGH_ZONE),
        patch(_GET_TOKENS, new_callable=AsyncMock, return_value=[]),
        patch(_NOTIFY, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(
                "/risk-zones",
                headers=_AUTH,
                json={
                    "threat_type": "Robo/Asalto",
                    "risk_level": "HIGH",
                    "location": {"lat": 20.6741, "lng": -103.4451},
                    "radius_meters": 100,
                },
            )

    assert res.status_code == 201
    data = res.json()
    assert data["id"] == ZONE_ID
    assert data["risk_level"] == "HIGH"
    assert data["active"] is True
    assert data["reporter_uid"] == REPORTER_UID


@pytest.mark.asyncio
async def test_create_zone_invalid_level(mock_firebase, as_reporter):
    from main import app

    with patch(_QUERY_BBOX, new_callable=AsyncMock, return_value=[]):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(
                "/risk-zones",
                headers=_AUTH,
                json={
                    "threat_type": "Robo",
                    "risk_level": "EXTREME",
                    "location": {"lat": 20.6741, "lng": -103.4451},
                },
            )

    assert res.status_code == 422


@pytest.mark.asyncio
async def test_create_zone_duplicate_returns_409(mock_firebase, as_reporter):
    from main import app

    with patch(_QUERY_BBOX, new_callable=AsyncMock, return_value=[_ZONE_DICT]):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(
                "/risk-zones",
                headers=_AUTH,
                json={
                    "threat_type": "Robo/Asalto",
                    "risk_level": "HIGH",
                    "location": {"lat": 20.6741, "lng": -103.4451},
                    "radius_meters": 100,
                },
            )

    assert res.status_code == 409
    detail = res.json()["detail"]
    assert detail["error"] == "duplicate_risk_zone"
    assert detail["existing_zone_id"] == ZONE_ID


# ── GET /risk-zones/ ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_zones_no_token(mock_firebase):
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/risk-zones")

    assert res.status_code == 401


@pytest.mark.asyncio
async def test_list_zones_with_filters(mock_firebase, as_reporter):
    from main import app

    with patch(_GET_ZONES, new_callable=AsyncMock, return_value=[_HIGH_ZONE]):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.get(
                "/risk-zones",
                headers=_AUTH,
                params={"lat": 20.6741, "lng": -103.4451, "radius_km": 5.0},
            )

    assert res.status_code == 200
    zones = res.json()
    assert len(zones) == 1
    assert zones[0]["id"] == ZONE_ID


@pytest.mark.asyncio
async def test_list_zones_empty(mock_firebase, as_reporter):
    from main import app

    with patch(_GET_ZONES, new_callable=AsyncMock, return_value=[]):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.get("/risk-zones", headers=_AUTH)

    assert res.status_code == 200
    assert res.json() == []


# ── DELETE /risk-zones/{id} — endpoint eliminado (CU-03) ─────────────────────


@pytest.mark.asyncio
async def test_delete_endpoint_removed(mock_firebase, as_reporter):
    """DELETE /risk-zones/{id} fue eliminado; solo Firebase Console puede borrar zonas."""
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.delete(f"/risk-zones/{ZONE_ID}", headers=_AUTH)

    assert res.status_code in (404, 405)


# ── POST /risk-zones/{id}/dismiss ─────────────────────────────────────────────

_DR = "modules.safety.dismiss_router"
_DISMISS_GET_ZONE = f"{_DR}.FirestoreService.get_risk_zone"
_DISMISS_ZONE = f"{_DR}.FirestoreService.dismiss_risk_zone"
_NOTIFY_DISMISSED = f"{_DR}.NotificationService.send_risk_zone_dismissed"


@pytest.mark.asyncio
async def test_dismiss_reporter_cannot_vote_403(mock_firebase, as_reporter):
    from main import app

    with patch(_DISMISS_GET_ZONE, new_callable=AsyncMock, return_value=_HIGH_ZONE):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/risk-zones/{ZONE_ID}/dismiss", headers=_AUTH)

    assert res.status_code == 403
    assert res.json()["detail"]["error"] == "reporter_cannot_dismiss"


@pytest.mark.asyncio
async def test_dismiss_zone_not_found_404(mock_firebase, as_other):
    from main import app

    with patch(_DISMISS_GET_ZONE, new_callable=AsyncMock, return_value=None):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/risk-zones/{ZONE_ID}/dismiss", headers=_AUTH)

    assert res.status_code == 404


@pytest.mark.asyncio
async def test_dismiss_inactive_zone_409(mock_firebase, as_other):
    from main import app

    inactive_zone = _HIGH_ZONE.model_copy(update={"active": False})
    with patch(_DISMISS_GET_ZONE, new_callable=AsyncMock, return_value=inactive_zone):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/risk-zones/{ZONE_ID}/dismiss", headers=_AUTH)

    assert res.status_code == 409
    assert res.json()["detail"]["error"] == "zone_already_inactive"


@pytest.mark.asyncio
async def test_dismiss_already_voted_409(mock_firebase, as_other):
    from main import app
    from modules.shared.firestore_service import VoteConflictError

    with (
        patch(_DISMISS_GET_ZONE, new_callable=AsyncMock, return_value=_HIGH_ZONE),
        patch(
            _DISMISS_ZONE, 
            new_callable=AsyncMock, 
            side_effect=VoteConflictError("already_voted")
        ),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/risk-zones/{ZONE_ID}/dismiss", headers=_AUTH)

    assert res.status_code == 409
    assert res.json()["detail"]["error"] == "already_voted"


@pytest.mark.asyncio
async def test_dismiss_success_returns_zone(mock_firebase, as_other):
    from main import app

    voted_zone = _HIGH_ZONE.model_copy(update={"dismiss_count": 1, "dismissers": [OTHER_UID]})
    with (
        patch(_DISMISS_GET_ZONE, new_callable=AsyncMock, return_value=_HIGH_ZONE),
        patch(_DISMISS_ZONE, new_callable=AsyncMock, return_value=voted_zone),
        patch(_NOTIFY_DISMISSED, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/risk-zones/{ZONE_ID}/dismiss", headers=_AUTH)

    assert res.status_code == 200
    data = res.json()
    assert data["dismiss_count"] == 1
    assert OTHER_UID in data["dismissers"]
    assert data["active"] is True  # aún activa (solo 1 voto)


@pytest.mark.asyncio
async def test_dismiss_third_vote_deactivates_zone(mock_firebase, as_other):
    from main import app

    dismissed_zone = _HIGH_ZONE.model_copy(
        update={"active": False, "dismiss_count": 3, "dismissers": ["u1", "u2", OTHER_UID]}
    )
    with (
        patch(_DISMISS_GET_ZONE, new_callable=AsyncMock, return_value=_HIGH_ZONE),
        patch(_DISMISS_ZONE, new_callable=AsyncMock, return_value=dismissed_zone),
        patch(_NOTIFY_DISMISSED, new_callable=AsyncMock) as mock_notify,
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/risk-zones/{ZONE_ID}/dismiss", headers=_AUTH)

    assert res.status_code == 200
    data = res.json()
    assert data["active"] is False
    assert data["dismiss_count"] == 3
    mock_notify.assert_awaited_once_with(reporter_uid=REPORTER_UID, zone_id=ZONE_ID)
