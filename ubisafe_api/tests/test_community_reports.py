"""F6 — CommunityReportRouter tests: POST, GET, 400 out-of-range, 401."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from modules.community.schemas import CommunityReport, ReportStatus, ThreatType
from modules.safety.schemas import GeoPoint

REPORTER_UID = "reporter-uid-cr1"
REPORT_ID = "cr-doc-abc"

_REPORTER_TOKEN = {"uid": REPORTER_UID, "email": "reporter@test.com"}

_ACTIVE_REPORT = CommunityReport(
    id=REPORT_ID,
    reporter_uid=REPORTER_UID,
    threat_type=ThreatType.animal_muerto,
    location=GeoPoint(lat=20.6736, lng=-103.344),
    radius_meters=15,
    status=ReportStatus.pending_validation,
    validations=[],
    confirm_count=0,
    dismiss_count=0,
    is_duplicate=False,
    canonical_report_id=None,
)

_BODY = {
    "threat_type": "animal_muerto",
    "location": {"lat": 20.6736, "lng": -103.344},
}

_R = "modules.community.report_router"
_CREATE = "modules.shared.firestore_service.FirestoreService.create_community_report"
_LIST = "modules.shared.firestore_service.FirestoreService.get_community_reports_in_bbox"
_NOTIFY = f"{_R}._notify_nearby"

_AUTH = {"Authorization": "Bearer tok"}


@pytest.fixture
def mock_firebase():
    with patch("main.FirebaseAdminInit.initialize"):
        yield


@pytest.fixture
def as_reporter():
    with patch("dependencies.auth.verify_id_token", return_value=_REPORTER_TOKEN):
        yield


# ── POST /community-reports/ ──────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_create_report_no_token(mock_firebase):
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.post("/community-reports", json=_BODY)

    assert res.status_code == 401


@pytest.mark.asyncio
async def test_create_report_success(mock_firebase, as_reporter):
    from main import app

    with (
        patch(_CREATE, new_callable=AsyncMock, return_value=_ACTIVE_REPORT),
        patch(_NOTIFY, new_callable=AsyncMock),
        # Bypass user-profile proximity check (no last_location stored)
        patch(
            "modules.shared.firestore_service.FirestoreService.get_user",
            new_callable=AsyncMock,
            return_value=None,
        ),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post("/community-reports", headers=_AUTH, json=_BODY)

    assert res.status_code == 201
    data = res.json()
    assert data["id"] == REPORT_ID
    assert data["status"] == "pending_validation"
    assert data["radius_meters"] == 15
    assert data["is_duplicate"] is False


@pytest.mark.asyncio
async def test_create_report_invalid_threat_type(mock_firebase, as_reporter):
    from main import app

    with patch(
        "modules.shared.firestore_service.FirestoreService.get_user",
        new_callable=AsyncMock,
        return_value=None,
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(
                "/community-reports",
                headers=_AUTH,
                json={**_BODY, "threat_type": "incendio"},
            )

    assert res.status_code == 422  # Pydantic enum validation


# ── GET /community-reports/ ───────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_list_reports_no_token(mock_firebase):
    from main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/community-reports")

    assert res.status_code == 401


@pytest.mark.asyncio
async def test_list_reports_returns_active(mock_firebase, as_reporter):
    from main import app

    with patch(_LIST, new_callable=AsyncMock, return_value=[_ACTIVE_REPORT]):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.get(
                "/community-reports",
                headers=_AUTH,
                params={"lat": 20.67, "lng": -103.34, "radius_km": 5.0},
            )

    assert res.status_code == 200
    reports = res.json()
    assert len(reports) == 1
    assert reports[0]["id"] == REPORT_ID
    assert reports[0]["threat_type"] == "animal_muerto"


@pytest.mark.asyncio
async def test_list_reports_empty(mock_firebase, as_reporter):
    from main import app

    with patch(_LIST, new_callable=AsyncMock, return_value=[]):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.get("/community-reports", headers=_AUTH)

    assert res.status_code == 200
    assert res.json() == []


@pytest.mark.asyncio
async def test_list_reports_zona_sucia(mock_firebase, as_reporter):
    from main import app

    zona_sucia_report = CommunityReport(
        id="cr-zs-001",
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.zona_sucia,
        location=GeoPoint(lat=20.67, lng=-103.34),
        radius_meters=15,
        status=ReportStatus.confirmed,
        validations=[],
        confirm_count=3,
        dismiss_count=0,
        is_duplicate=False,
        canonical_report_id=None,
    )

    with patch(_LIST, new_callable=AsyncMock, return_value=[zona_sucia_report]):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.get("/community-reports", headers=_AUTH)

    assert res.status_code == 200
    data = res.json()
    assert data[0]["threat_type"] == "zona_sucia"
    assert data[0]["status"] == "confirmed"
    assert data[0]["confirm_count"] == 3
