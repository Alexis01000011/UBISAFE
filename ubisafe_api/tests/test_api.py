"""
FastAPI endpoint tests — pytest + starlette TestClient.

Strategy:
- autouse fixture patches FirebaseAdminInit.initialize to prevent real Firebase connections.
- Per-test fixtures override get_current_user dependency (buyer / vendor / anon).
- FirestoreService async methods are patched with AsyncMock per test.
"""
from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

# ─── Fixtures ────────────────────────────────────────────────────────────────

_BUYER_CLAIMS = {"uid": "buyer-uid"}
_VENDOR_CLAIMS = {"uid": "vendor-uid"}


@pytest.fixture(autouse=True)
def _no_firebase():
    """Prevent real Firebase SDK initialization in all tests."""
    with patch("modules.shared.firebase_admin_init.FirebaseAdminInit.initialize"):
        yield


def _make_client(user_claims: dict | None):
    from main import app
    from dependencies import get_current_user

    if user_claims is not None:
        app.dependency_overrides[get_current_user] = lambda: user_claims
    else:
        app.dependency_overrides.pop(get_current_user, None)

    client = TestClient(app, raise_server_exceptions=True)
    return client


@pytest.fixture
def buyer():
    client = _make_client(_BUYER_CLAIMS)
    yield client
    from main import app
    app.dependency_overrides.clear()


@pytest.fixture
def vendor():
    client = _make_client(_VENDOR_CLAIMS)
    yield client
    from main import app
    app.dependency_overrides.clear()


@pytest.fixture
def anon():
    from main import app
    from dependencies import get_current_user
    app.dependency_overrides.pop(get_current_user, None)
    client = TestClient(app)
    yield client
    app.dependency_overrides.clear()


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _buyer_profile(**kwargs):
    from modules.identity.schemas import UserProfile
    return UserProfile(uid="buyer-uid", role="BUYER", **kwargs)


def _vendor_profile(**kwargs):
    from modules.identity.schemas import UserProfile
    return UserProfile(uid="vendor-uid", role="VENDOR", **kwargs)


def _make_stop(status: str = "pending"):
    from modules.dispatching.schemas import StopRequest, GeoPoint
    return StopRequest(
        id="stop-1",
        buyer_uid="buyer-uid",
        vendor_uid="vendor-uid",
        buyer_location=GeoPoint(lat=20.0, lng=-103.0),
        status=status,
    )


def _make_report(
    reporter_uid: str = "other-uid",
    status: str = "pending_validation",
    validations: list | None = None,
):
    from modules.community.schemas import CommunityReport, ReportStatus, ThreatType
    from modules.safety.schemas import GeoPoint
    return CommunityReport(
        id="report-1",
        reporter_uid=reporter_uid,
        threat_type=ThreatType.animal_muerto,
        location=GeoPoint(lat=20.0, lng=-103.0),
        status=ReportStatus(status),
        validations=validations or [],
    )


# ─── Health endpoints ─────────────────────────────────────────────────────────

class TestHealth:
    def test_auth_health(self, anon):
        assert anon.get("/auth/health").status_code == 200

    def test_stops_health(self, anon):
        assert anon.get("/stops/health").status_code == 200

    def test_risk_zones_health(self, anon):
        assert anon.get("/risk-zones/health").status_code == 200


# ─── Auth middleware ──────────────────────────────────────────────────────────

class TestAuthMiddleware:
    def test_protected_endpoint_without_token_returns_401(self, anon):
        # /auth/me requires a bearer token; without override it goes through
        # the real HTTPBearer which returns 403 when no Authorization header.
        res = anon.get("/auth/me")
        assert res.status_code in (401, 403)

    def test_authenticated_me_returns_profile(self, buyer):
        profile = _buyer_profile(name="Test Buyer")
        with patch(
            "modules.shared.firestore_service.FirestoreService.get_user",
            new_callable=AsyncMock,
            return_value=profile,
        ):
            res = buyer.get("/auth/me")
        assert res.status_code == 200
        assert res.json()["uid"] == "buyer-uid"
        assert res.json()["role"] == "BUYER"

    def test_me_returns_404_when_no_profile(self, buyer):
        with patch(
            "modules.shared.firestore_service.FirestoreService.get_user",
            new_callable=AsyncMock,
            return_value=None,
        ):
            res = buyer.get("/auth/me")
        assert res.status_code == 404


# ─── Stop requests ────────────────────────────────────────────────────────────

class TestStopRequests:
    def test_buyer_can_create_stop(self, buyer):
        stop = _make_stop()
        with (
            patch(
                "modules.shared.firestore_service.FirestoreService.get_user",
                new_callable=AsyncMock,
                return_value=_buyer_profile(),
            ),
            patch(
                "modules.shared.firestore_service.FirestoreService.create_stop_request",
                new_callable=AsyncMock,
                return_value=stop,
            ),
            patch(
                "modules.shared.notification_service.NotificationService.send_stop_incoming",
                new_callable=AsyncMock,
            ),
        ):
            res = buyer.post(
                "/stops/",
                json={"vendor_uid": "vendor-uid", "buyer_location": {"lat": 20.0, "lng": -103.0}},
            )
        assert res.status_code == 201
        assert res.json()["id"] == "stop-1"

    def test_vendor_cannot_create_stop(self, vendor):
        with patch(
            "modules.shared.firestore_service.FirestoreService.get_user",
            new_callable=AsyncMock,
            return_value=_vendor_profile(),
        ):
            res = vendor.post(
                "/stops/",
                json={"vendor_uid": "vendor-uid", "buyer_location": {"lat": 20.0, "lng": -103.0}},
            )
        assert res.status_code == 403

    def test_invalid_state_transition_returns_400(self, vendor):
        stop = _make_stop(status="completed")
        with (
            patch(
                "modules.shared.firestore_service.FirestoreService.get_stop_request",
                new_callable=AsyncMock,
                return_value=stop,
            ),
            patch(
                "modules.shared.firestore_service.FirestoreService.get_user",
                new_callable=AsyncMock,
                return_value=_vendor_profile(),
            ),
        ):
            res = vendor.patch("/stops/stop-1/status", json={"status": "accepted"})
        assert res.status_code == 400

    def test_vendor_can_accept_pending_stop(self, vendor):
        stop_pending = _make_stop(status="pending")
        stop_accepted = _make_stop(status="accepted")
        with (
            patch(
                "modules.shared.firestore_service.FirestoreService.get_stop_request",
                new_callable=AsyncMock,
                return_value=stop_pending,
            ),
            patch(
                "modules.shared.firestore_service.FirestoreService.get_user",
                new_callable=AsyncMock,
                return_value=_vendor_profile(),
            ),
            patch(
                "modules.shared.firestore_service.FirestoreService.update_stop_status",
                new_callable=AsyncMock,
                return_value=stop_accepted,
            ),
            patch(
                "modules.shared.notification_service.NotificationService.send_stop_accepted",
                new_callable=AsyncMock,
            ),
        ):
            res = vendor.patch("/stops/stop-1/status", json={"status": "accepted"})
        assert res.status_code == 200
        assert res.json()["status"] == "accepted"

    def test_buyer_cannot_accept_stop(self, buyer):
        stop_pending = _make_stop(status="pending")
        with (
            patch(
                "modules.shared.firestore_service.FirestoreService.get_stop_request",
                new_callable=AsyncMock,
                return_value=stop_pending,
            ),
            patch(
                "modules.shared.firestore_service.FirestoreService.get_user",
                new_callable=AsyncMock,
                return_value=_buyer_profile(),
            ),
        ):
            res = buyer.patch("/stops/stop-1/status", json={"status": "accepted"})
        assert res.status_code == 403

    def test_expired_race_condition_returns_409(self, buyer):
        """Buyer sends expired but vendor already changed status — 409 conflict."""
        stop_accepted = _make_stop(status="accepted")
        with (
            patch(
                "modules.shared.firestore_service.FirestoreService.get_stop_request",
                new_callable=AsyncMock,
                return_value=_make_stop(status="pending"),
            ),
            patch(
                "modules.shared.firestore_service.FirestoreService.get_user",
                new_callable=AsyncMock,
                return_value=_buyer_profile(),
            ),
            patch(
                "modules.shared.firestore_service.FirestoreService.update_stop_status_if_pending",
                new_callable=AsyncMock,
                return_value=(stop_accepted, False),  # was_updated=False → already changed
            ),
        ):
            res = buyer.patch("/stops/stop-1/status", json={"status": "expired"})
        assert res.status_code == 409


# ─── Community report validation ──────────────────────────────────────────────

class TestReportValidation:
    def test_reporter_cannot_vote_on_own_report(self, buyer):
        report = _make_report(reporter_uid="buyer-uid")  # same uid as voter
        with patch(
            "modules.shared.firestore_service.FirestoreService.get_community_report",
            new_callable=AsyncMock,
            return_value=report,
        ):
            res = buyer.patch("/community-reports/report-1/validations", json={"vote": "confirm"})
        assert res.status_code == 403
        assert res.json()["detail"] == "reporter_cannot_vote"

    def test_cannot_vote_on_non_pending_report(self, buyer):
        report = _make_report(status="confirmed")
        with patch(
            "modules.shared.firestore_service.FirestoreService.get_community_report",
            new_callable=AsyncMock,
            return_value=report,
        ):
            res = buyer.patch("/community-reports/report-1/validations", json={"vote": "confirm"})
        assert res.status_code == 409
        assert "confirmed" in res.json()["detail"]

    def test_cannot_vote_twice(self, buyer):
        from modules.community.schemas import Validation, ValidationVerdict
        existing_vote = Validation(
            user_uid="buyer-uid",
            verdict=ValidationVerdict.confirm,
            timestamp="2026-01-01T00:00:00",
        )
        report = _make_report(validations=[existing_vote])
        with patch(
            "modules.shared.firestore_service.FirestoreService.get_community_report",
            new_callable=AsyncMock,
            return_value=report,
        ):
            res = buyer.patch("/community-reports/report-1/validations", json={"vote": "confirm"})
        assert res.status_code == 409
        assert res.json()["detail"] == "already_voted"

    def test_valid_vote_returns_updated_report(self, buyer):
        report = _make_report()
        updated = _make_report(reporter_uid="other-uid")
        with (
            patch(
                "modules.shared.firestore_service.FirestoreService.get_community_report",
                new_callable=AsyncMock,
                return_value=report,
            ),
            patch(
                "modules.shared.firestore_service.FirestoreService.vote_community_report",
                new_callable=AsyncMock,
                return_value=updated,
            ),
        ):
            res = buyer.patch("/community-reports/report-1/validations", json={"vote": "confirm"})
        assert res.status_code == 200
        assert res.json()["id"] == "report-1"
