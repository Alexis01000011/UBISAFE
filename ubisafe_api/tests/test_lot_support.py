"""CU-07 — lot_router tests: POST /support + PATCH /resolve endpoints."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from modules.community.schemas import CommunityReport, ReportStatus, ThreatType
from modules.safety.schemas import GeoPoint

REPORTER_UID = "reporter-lot-uid"
SUPPORTER_1 = "supporter-uid-1"
SUPPORTER_2 = "supporter-uid-2"
SUPPORTER_3 = "supporter-uid-3"
REPORT_ID = "lot-doc-abc"

_SUPPORTER_1_TOKEN = {"uid": SUPPORTER_1}
_SUPPORTER_3_TOKEN = {"uid": SUPPORTER_3}

_BASE_LOT = CommunityReport(
    id=REPORT_ID,
    reporter_uid=REPORTER_UID,
    threat_type=ThreatType.lote,
    location=GeoPoint(lat=20.6736, lng=-103.344),
    status=ReportStatus.pending_validation,
    support_count=0,
    supporters=[],
    pending_resolver_uid=None,
)

_NON_LOT = CommunityReport(
    id=REPORT_ID,
    reporter_uid=REPORTER_UID,
    threat_type=ThreatType.animal_muerto,
    location=GeoPoint(lat=20.6736, lng=-103.344),
    status=ReportStatus.pending_validation,
)

_AUTH = {"Authorization": "Bearer tok"}

_FS_GET = "modules.shared.firestore_service.FirestoreService.get_community_report"
_FS_SUPPORT = "modules.shared.firestore_service.FirestoreService.support_community_report"
_FS_RESOLVE = "modules.shared.firestore_service.FirestoreService.resolve_community_report"
_NOTIFY_LOT = "modules.shared.notification_service.NotificationService.send_lot_resolved"


@pytest.fixture
def mock_firebase():
    with patch("main.FirebaseAdminInit.initialize"):
        yield


@pytest.fixture
def as_supporter_1():
    with patch("dependencies.auth.verify_id_token", return_value=_SUPPORTER_1_TOKEN):
        yield


@pytest.fixture
def as_supporter_3():
    with patch("dependencies.auth.verify_id_token", return_value=_SUPPORTER_3_TOKEN):
        yield


# ── POST /community-reports/{id}/support ──────────────────────────────────────


@pytest.mark.asyncio
async def test_support_increments_count(mock_firebase, as_supporter_1):
    from main import app

    updated = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.pending_validation,
        support_count=1,
        supporters=[SUPPORTER_1],
        pending_resolver_uid=None,
    )
    with (
        patch(_FS_GET, new_callable=AsyncMock, return_value=_BASE_LOT),
        patch(_FS_SUPPORT, new_callable=AsyncMock, return_value=updated),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/community-reports/{REPORT_ID}/support", headers=_AUTH)
    assert res.status_code == 200
    assert res.json()["support_count"] == 1
    assert SUPPORTER_1 in res.json()["supporters"]


@pytest.mark.asyncio
async def test_third_support_sets_pending_resolver(mock_firebase, as_supporter_3):
    from main import app

    two_supporters = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.pending_validation,
        support_count=2,
        supporters=[SUPPORTER_1, SUPPORTER_2],
        pending_resolver_uid=None,
    )
    after_third = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.pending_validation,
        support_count=3,
        supporters=[SUPPORTER_1, SUPPORTER_2, SUPPORTER_3],
        pending_resolver_uid=SUPPORTER_3,
    )
    with (
        patch(_FS_GET, new_callable=AsyncMock, return_value=two_supporters),
        patch(_FS_SUPPORT, new_callable=AsyncMock, return_value=after_third),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/community-reports/{REPORT_ID}/support", headers=_AUTH)
    assert res.status_code == 200
    assert res.json()["pending_resolver_uid"] == SUPPORTER_3


@pytest.mark.asyncio
async def test_double_support_rejected_409(mock_firebase, as_supporter_1):
    from main import app

    already_supported = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.pending_validation,
        supporters=[SUPPORTER_1],
        support_count=1,
    )
    with patch(_FS_GET, new_callable=AsyncMock, return_value=already_supported):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/community-reports/{REPORT_ID}/support", headers=_AUTH)
    assert res.status_code == 409
    assert res.json()["detail"] == "already_supported"


@pytest.mark.asyncio
async def test_support_beyond_3_rejected_409(mock_firebase, as_supporter_1):
    from main import app

    full_lot = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.pending_validation,
        supporters=[SUPPORTER_1, SUPPORTER_2, SUPPORTER_3],
        support_count=3,
        pending_resolver_uid=SUPPORTER_3,
    )
    with patch(_FS_GET, new_callable=AsyncMock, return_value=full_lot):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/community-reports/{REPORT_ID}/support", headers=_AUTH)
    assert res.status_code == 409
    assert res.json()["detail"] == "max_supporters_reached"


@pytest.mark.asyncio
async def test_support_on_resolved_status_rejected_409(mock_firebase, as_supporter_1):
    from main import app

    resolved_lot = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.resolved,
    )
    with patch(_FS_GET, new_callable=AsyncMock, return_value=resolved_lot):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/community-reports/{REPORT_ID}/support", headers=_AUTH)
    assert res.status_code == 409
    assert res.json()["detail"] == "report_status_is_resolved"


@pytest.mark.asyncio
async def test_support_on_non_lot_rejected_422(mock_firebase, as_supporter_1):
    from main import app

    with patch(_FS_GET, new_callable=AsyncMock, return_value=_NON_LOT):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.post(f"/community-reports/{REPORT_ID}/support", headers=_AUTH)
    assert res.status_code == 422
    assert res.json()["detail"] == "use_validation_endpoint"


# ── PATCH /community-reports/{id}/resolve ─────────────────────────────────────


@pytest.mark.asyncio
async def test_resolve_requires_3_supports(mock_firebase, as_supporter_1):
    from main import app

    two_supporter_lot = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.pending_validation,
        supporters=[SUPPORTER_1, SUPPORTER_2],
        support_count=2,
        pending_resolver_uid=None,
    )
    with patch(_FS_GET, new_callable=AsyncMock, return_value=two_supporter_lot):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.patch(f"/community-reports/{REPORT_ID}/resolve", headers=_AUTH)
    assert res.status_code == 409
    assert res.json()["detail"] == "insufficient_supports"


@pytest.mark.asyncio
async def test_any_user_can_resolve_with_3_supports(mock_firebase, as_supporter_1):
    """SUPPORTER_1 (not the pending_resolver_uid) can resolve once support_count >= 3."""
    from main import app

    lot_ready = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.pending_validation,
        supporters=[SUPPORTER_1, SUPPORTER_2, SUPPORTER_3],
        support_count=3,
        pending_resolver_uid=SUPPORTER_3,
    )
    resolved = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.resolved,
        supporters=[SUPPORTER_1, SUPPORTER_2, SUPPORTER_3],
        support_count=3,
        pending_resolver_uid=SUPPORTER_3,
        resolved_by_uid=SUPPORTER_1,
    )
    with (
        patch(_FS_GET, new_callable=AsyncMock, return_value=lot_ready),
        patch(_FS_RESOLVE, new_callable=AsyncMock, return_value=resolved),
        patch(_NOTIFY_LOT, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.patch(f"/community-reports/{REPORT_ID}/resolve", headers=_AUTH)
    assert res.status_code == 200
    assert res.json()["status"] == "resolved"


@pytest.mark.asyncio
async def test_resolve_marks_status_resolved(mock_firebase, as_supporter_3):
    from main import app

    lot_ready = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.pending_validation,
        supporters=[SUPPORTER_1, SUPPORTER_2, SUPPORTER_3],
        support_count=3,
        pending_resolver_uid=SUPPORTER_3,
    )
    resolved = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.resolved,
        supporters=[SUPPORTER_1, SUPPORTER_2, SUPPORTER_3],
        support_count=3,
        pending_resolver_uid=SUPPORTER_3,
        resolved_by_uid=SUPPORTER_3,
    )
    with (
        patch(_FS_GET, new_callable=AsyncMock, return_value=lot_ready),
        patch(_FS_RESOLVE, new_callable=AsyncMock, return_value=resolved),
        patch(_NOTIFY_LOT, new_callable=AsyncMock),
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.patch(f"/community-reports/{REPORT_ID}/resolve", headers=_AUTH)
    assert res.status_code == 200
    assert res.json()["status"] == "resolved"
    assert res.json()["resolved_by_uid"] == SUPPORTER_3


@pytest.mark.asyncio
async def test_validation_endpoint_rejects_lote_422(mock_firebase, as_supporter_1):
    """PATCH /validations must reject lote with 422 (guard D-2)."""
    from main import app

    with patch(_FS_GET, new_callable=AsyncMock, return_value=_BASE_LOT):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.patch(
                f"/community-reports/{REPORT_ID}/validations",
                headers=_AUTH,
                json={"vote": "confirm"},
            )
    assert res.status_code == 422
    assert res.json()["detail"] == "use_support_endpoint"


@pytest.mark.asyncio
async def test_resolve_sends_fcm(mock_firebase, as_supporter_3):
    """PATCH /resolve fires send_lot_resolved with correct arguments (fire-and-forget)."""
    import asyncio

    from main import app

    lot_ready = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.pending_validation,
        supporters=[SUPPORTER_1, SUPPORTER_2, SUPPORTER_3],
        support_count=3,
        pending_resolver_uid=SUPPORTER_3,
    )
    resolved = CommunityReport(
        id=REPORT_ID,
        reporter_uid=REPORTER_UID,
        threat_type=ThreatType.lote,
        location=GeoPoint(lat=20.6736, lng=-103.344),
        status=ReportStatus.resolved,
        supporters=[SUPPORTER_1, SUPPORTER_2, SUPPORTER_3],
        support_count=3,
        pending_resolver_uid=SUPPORTER_3,
        resolved_by_uid=SUPPORTER_3,
    )
    with (
        patch(_FS_GET, new_callable=AsyncMock, return_value=lot_ready),
        patch(_FS_RESOLVE, new_callable=AsyncMock, return_value=resolved),
        patch(_NOTIFY_LOT, new_callable=AsyncMock) as mock_notify,
    ):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            res = await client.patch(f"/community-reports/{REPORT_ID}/resolve", headers=_AUTH)
        await asyncio.sleep(0)  # flush asyncio.ensure_future

    assert res.status_code == 200
    mock_notify.assert_awaited_once_with(
        reporter_uid=REPORTER_UID,
        supporter_uids=[SUPPORTER_1, SUPPORTER_2, SUPPORTER_3],
        report_id=REPORT_ID,
        resolved_by_uid=SUPPORTER_3,
    )
