"""F5 — RiskZoneRouter tests: POST, GET, DELETE, 409 duplicate, 401/403/404."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from modules.safety.schemas import GeoPoint, RiskZone

REPORTER_UID = "reporter-uid-111"
OTHER_UID = "other-uid-222"
ZONE_ID = "zone-doc-abc"

_REPORTER_TOKEN = {"uid": REPORTER_UID, "email": "reporter@test.com"}
_OTHER_TOKEN = {"uid": OTHER_UID, "email": "other@test.com"}

_ACTIVE_ZONE = RiskZone(
    id=ZONE_ID,
    reporter_uid=REPORTER_UID,
    threat_type="Robo/Asalto",
    risk_level="HIGH",
    location=GeoPoint(lat=20.6736, lng=-103.344),
    radius_meters=100,
    active=True,
)

_BODY = {
    "threat_type": "Robo/Asalto",
    "risk_level": "HIGH",
    "location": {"lat": 20.6736, "lng": -103.344},
}

_R = "modules.safety.router"
_FIND_DUP = f"{_R}.FirestoreService.find_duplicate_risk_zone"
_CREATE = f"{_R}.FirestoreService.create_risk_zone"
_GET_ZONES = f"{_R}.FirestoreService.get_active_risk_zones"
_GET_ZONE = f"{_R}.FirestoreService.get_risk_zone"
_EXPIRE = f"{_R}.FirestoreService.expire_risk_zone"
_NOTIFY = f"{_R}._notify_all"


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


_AUTH = {"Authorization": "Bearer tok"}

# ── POST /risk-zones ──────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_zone_no_token(mock_firebase):
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/risk-zones", json=_BODY)

    assert res.status_code == 401


@pytest.mark.asyncio
async def test_create_zone_success(mock_firebase, as_reporter):
    from main import app

    with (
        patch(_FIND_DUP, new_callable=AsyncMock, return_value=None),
        patch(_CREATE, new_callable=AsyncMock, return_value=_ACTIVE_ZONE),
        patch(_NOTIFY, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/risk-zones", headers=_AUTH, json=_BODY)

    assert res.status_code == 201
    data = res.json()
    assert data["id"] == ZONE_ID
    assert data["risk_level"] == "HIGH"
    assert data["active"] is True


@pytest.mark.asyncio
async def test_create_zone_duplicate_returns_409(mock_firebase, as_reporter):
    from main import app

    with patch(_FIND_DUP, new_callable=AsyncMock, return_value=_ACTIVE_ZONE):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/risk-zones", headers=_AUTH, json=_BODY)

    assert res.status_code == 409
    detail = res.json()["detail"]
    assert detail["error"] == "duplicate_risk_zone"
    assert detail["existing_zone_id"] == ZONE_ID


# ── GET /risk-zones ───────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_zones_no_token(mock_firebase):
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/risk-zones")

    assert res.status_code == 401


@pytest.mark.asyncio
async def test_list_zones_with_filters(mock_firebase, as_reporter):
    from main import app

    with patch(_GET_ZONES, new_callable=AsyncMock, return_value=[_ACTIVE_ZONE]):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.get(
                "/risk-zones",
                headers=_AUTH,
                params={"lat": 20.67, "lng": -103.34, "radius_km": 5.0},
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


# ── DELETE /risk-zones/{id} ───────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_expire_zone_by_reporter_returns_204(mock_firebase, as_reporter):
    from main import app

    with (
        patch(_GET_ZONE, new_callable=AsyncMock, return_value=_ACTIVE_ZONE),
        patch(_EXPIRE, new_callable=AsyncMock, return_value=_ACTIVE_ZONE),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.delete(f"/risk-zones/{ZONE_ID}", headers=_AUTH)

    assert res.status_code == 204


@pytest.mark.asyncio
async def test_expire_zone_by_non_reporter_returns_403(mock_firebase, as_other):
    from main import app

    with patch(_GET_ZONE, new_callable=AsyncMock, return_value=_ACTIVE_ZONE):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.delete(f"/risk-zones/{ZONE_ID}", headers=_AUTH)

    assert res.status_code == 403


@pytest.mark.asyncio
async def test_expire_zone_not_found_returns_404(mock_firebase, as_reporter):
    from main import app

    with patch(_GET_ZONE, new_callable=AsyncMock, return_value=None):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.delete(f"/risk-zones/{ZONE_ID}", headers=_AUTH)

    assert res.status_code == 404
