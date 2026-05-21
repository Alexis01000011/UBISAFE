"""CU-09-A — group_stay_router tests: POST /group-stays."""

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
_FS_CREATE = "modules.shared.firestore_service.FirestoreService.create_group_stay"
_FS_ZONES = "modules.shared.firestore_service.FirestoreService.get_active_risk_zones_near"
_FS_OVERLAP = "modules.shared.firestore_service.FirestoreService.vendor_has_overlapping_stay"


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
    }


# ── POST /group-stays ─────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_vendor_can_create_stay(mock_firebase, as_vendor):
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE),
        patch(_FS_ZONES, new_callable=AsyncMock, return_value=[]),
        patch(_FS_OVERLAP, new_callable=AsyncMock, return_value=False),
        patch(_FS_CREATE, new_callable=AsyncMock, return_value=_CREATED_STAY),
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
        patch(_FS_ZONES, new_callable=AsyncMock, return_value=[high_zone]),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/group-stays", json=_stay_body(), headers=_AUTH)

    assert res.status_code == 422
    assert res.json()["detail"]["error"] == "zone_high"
    assert "rz-high-01" in res.json()["detail"]["risk_zone_ids"]


@pytest.mark.asyncio
async def test_create_returns_warning_for_medium_zone(mock_firebase, as_vendor):
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
        patch(_FS_ZONES, new_callable=AsyncMock, return_value=[medium_zone]),
        patch(_FS_OVERLAP, new_callable=AsyncMock, return_value=False),
        patch(_FS_CREATE, new_callable=AsyncMock, return_value=_CREATED_STAY),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/group-stays", json=_stay_body(), headers=_AUTH)

    assert res.status_code == 201
    body = res.json()
    assert body["warning"] is not None
    assert body["warning"]["risk_level"] == "MEDIUM"
    assert body["warning"]["risk_zone_id"] == "rz-med-01"


@pytest.mark.asyncio
async def test_create_rejected_overlap_409(mock_firebase, as_vendor):
    from main import app

    with (
        patch(_FS_GET_USER, new_callable=AsyncMock, return_value=_VENDOR_PROFILE),
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
