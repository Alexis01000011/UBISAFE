"""F5.1 — RiskZoneRouter tests: creation, duplicate detection, geo filter, soft delete."""
from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from modules.safety.schemas import GeoPoint, RiskZone

REPORTER_UID = "reporter-uid-001"
OTHER_UID = "other-uid-002"
ZONE_ID = "rz-high-001"

_REPORTER_TOKEN = {"uid": REPORTER_UID, "email": "reporter@test.com"}
_OTHER_TOKEN = {"uid": OTHER_UID, "email": "other@test.com"}

_HIGH_ZONE = RiskZone(
    id=ZONE_ID,
    reporter_uid=REPORTER_UID,
    threat_type="robo con violencia",
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
    "threat_type": "robo con violencia",
    "risk_level": "HIGH",
    "location": {"lat": 20.6741, "lng": -103.4451},
    "radius_meters": 100,
    "active": True,
    "created_at": "2026-04-28T10:00:00+00:00",
    "expires_at": "2026-04-29T10:00:00+00:00",
    "expired_at": None,
}

_R = "modules.safety.router"
_CREATE_ZONE = f"{_R}.FirestoreService.create_risk_zone"
_QUERY_BBOX = f"{_R}.FirestoreService.query_active_risk_zones_bbox"
_GET_ZONE = f"{_R}.FirestoreService.get_risk_zone"
_EXPIRE_ZONE = f"{_R}.FirestoreService.expire_risk_zone"
_GET_TOKENS = f"{_R}.FirestoreService.get_all_fcm_tokens"
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
async def test_create_risk_zone_success(mock_firebase, as_reporter):
    from main import app

    with (
        patch(_QUERY_BBOX, new_callable=AsyncMock, return_value=[]),
        patch(_CREATE_ZONE, new_callable=AsyncMock, return_value=_HIGH_ZONE),
        patch(_GET_TOKENS, new_callable=AsyncMock, return_value=[]),
        patch(_NOTIFY, new_callable=AsyncMock),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as c:
            r = await c.post(
                "/risk-zones/",
                headers={"Authorization": "Bearer tok"},
                json={
                    "threat_type": "robo",
                    "risk_level": "HIGH",
                    "location": {"lat": 20.6741, "lng": -103.4451},
                    "radius_meters": 100,
                },
            )
    assert r.status_code == 201
    assert r.json()["risk_level"] == "HIGH"
    assert r.json()["reporter_uid"] == REPORTER_UID


@pytest.mark.asyncio
async def test_create_risk_zone_no_auth(mock_firebase):
    from main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as c:
        r = await c.post(
            "/risk-zones/",
            json={
                "threat_type": "robo",
                "risk_level": "HIGH",
                "location": {"lat": 20.6741, "lng": -103.4451},
            },
        )
    assert r.status_code == 401


@pytest.mark.asyncio
async def test_create_risk_zone_invalid_level(mock_firebase, as_reporter):
    from main import app

    with patch(_QUERY_BBOX, new_callable=AsyncMock, return_value=[]):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as c:
            r = await c.post(
                "/risk-zones/",
                headers={"Authorization": "Bearer tok"},
                json={
                    "threat_type": "robo",
                    "risk_level": "EXTREME",
                    "location": {"lat": 20.6741, "lng": -103.4451},
                },
            )
    assert r.status_code == 422


@pytest.mark.asyncio
async def test_create_risk_zone_duplicate_returns_409(mock_firebase, as_reporter):
    """Zone at the same coordinates as an active zone → 409 Conflict."""
    from main import app

    # The candidate is at the same lat/lng — distance = 0 < radius_meters=100
    with patch(_QUERY_BBOX, new_callable=AsyncMock, return_value=[_ZONE_DICT]):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as c:
            r = await c.post(
                "/risk-zones/",
                headers={"Authorization": "Bearer tok"},
                json={
                    "threat_type": "robo",
                    "risk_level": "HIGH",
                    "location": {"lat": 20.6741, "lng": -103.4451},
                    "radius_meters": 100,
                },
            )
    assert r.status_code == 409
    assert r.json()["detail"]["error"] == "duplicate_risk_zone"
    assert r.json()["detail"]["existing_zone_id"] == ZONE_ID


# ── GET /risk-zones/ ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_risk_zones_returns_zones_in_radius(mock_firebase, as_reporter):
    from main import app

    # Zone at same coords as query center — should be included
    with patch(_QUERY_BBOX, new_callable=AsyncMock, return_value=[_ZONE_DICT]):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as c:
            r = await c.get(
                "/risk-zones/",
                headers={"Authorization": "Bearer tok"},
                params={"lat": 20.6741, "lng": -103.4451, "radius_km": 5},
            )
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.json()[0]["risk_level"] == "HIGH"


@pytest.mark.asyncio
async def test_list_risk_zones_filters_by_haversine(mock_firebase, as_reporter):
    """Zone 10 km away should NOT appear in a 5 km radius query."""
    from main import app

    far_zone = dict(_ZONE_DICT)
    far_zone["location"] = {"lat": 20.7800, "lng": -103.4451}  # ~11 km north

    with patch(_QUERY_BBOX, new_callable=AsyncMock, return_value=[far_zone]):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as c:
            r = await c.get(
                "/risk-zones/",
                headers={"Authorization": "Bearer tok"},
                params={"lat": 20.6741, "lng": -103.4451, "radius_km": 5},
            )
    assert r.status_code == 200
    assert len(r.json()) == 0


# ── DELETE /risk-zones/{id} ───────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_expire_risk_zone_by_reporter(mock_firebase, as_reporter):
    from main import app

    with (
        patch(_GET_ZONE, new_callable=AsyncMock, return_value=_ZONE_DICT),
        patch(_EXPIRE_ZONE, new_callable=AsyncMock),
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as c:
            r = await c.delete(
                f"/risk-zones/{ZONE_ID}",
                headers={"Authorization": "Bearer tok"},
            )
    assert r.status_code == 204


@pytest.mark.asyncio
async def test_expire_risk_zone_by_other_returns_403(mock_firebase, as_other):
    from main import app

    with patch(_GET_ZONE, new_callable=AsyncMock, return_value=_ZONE_DICT):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as c:
            r = await c.delete(
                f"/risk-zones/{ZONE_ID}",
                headers={"Authorization": "Bearer tok"},
            )
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_expire_risk_zone_not_found(mock_firebase, as_reporter):
    from main import app

    with patch(_GET_ZONE, new_callable=AsyncMock, return_value=None):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as c:
            r = await c.delete(
                "/risk-zones/nonexistent",
                headers={"Authorization": "Bearer tok"},
            )
    assert r.status_code == 404
