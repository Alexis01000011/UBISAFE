"""F2 — AuthMiddleware + auth endpoints tests."""
import pytest
from datetime import datetime
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock, MagicMock, patch


VALID_UID = "test-uid-123"
VALID_TOKEN_PAYLOAD = {"uid": VALID_UID, "email": "test@example.com"}

MOCK_PROFILE = {
    "name": "Test User",
    "phone": "+52 33 1234 5678",
    "role": "BUYER",
    "fcm_token": None,
    "last_location": None,
    "last_location_at": None,
    "created_at": datetime(2026, 1, 1),
    "updated_at": datetime(2026, 1, 2),
}


@pytest.fixture
def mock_firebase():
    with patch("main.FirebaseAdminInit.initialize"):
        yield


@pytest.fixture
def mock_valid_token():
    """Patch firebase_admin.auth.verify_id_token to return a valid decoded token."""
    with patch("dependencies.auth.verify_id_token", return_value=VALID_TOKEN_PAYLOAD):
        yield


@pytest.fixture
def mock_firestore_get_user():
    """Patch FirestoreService.get_user to return a mock profile."""
    from schemas.user import UserProfile
    profile = UserProfile(uid=VALID_UID, **MOCK_PROFILE)
    with patch(
        "routers.auth.FirestoreService.get_user",
        new_callable=AsyncMock,
        return_value=profile,
    ):
        yield profile


@pytest.fixture
def mock_firestore_upsert_user():
    """Patch FirestoreService.upsert_user to return a mock profile."""
    from schemas.user import UserProfile
    profile = UserProfile(uid=VALID_UID, **MOCK_PROFILE)
    with patch(
        "routers.auth.FirestoreService.upsert_user",
        new_callable=AsyncMock,
        return_value=profile,
    ):
        yield profile


# ── AuthMiddleware ────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_auth_me_no_token_returns_401(mock_firebase):
    """HTTPBearer rejects requests with no Authorization header → 401."""
    from main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/auth/me")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_auth_me_invalid_token_returns_401(mock_firebase):
    """An invalid JWT is rejected with 401."""
    from main import app

    with patch("dependencies.auth.verify_id_token", side_effect=Exception("invalid")):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/auth/me", headers={"Authorization": "Bearer bad-token"}
            )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_auth_me_valid_token_returns_profile(
    mock_firebase, mock_valid_token, mock_firestore_get_user
):
    """Valid token + existing Firestore profile → 200 with user data."""
    from main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get(
            "/auth/me", headers={"Authorization": "Bearer valid-token"}
        )
    assert response.status_code == 200
    data = response.json()
    assert data["uid"] == VALID_UID
    assert data["role"] == "BUYER"
    assert data["name"] == "Test User"


@pytest.mark.asyncio
async def test_auth_me_profile_not_found_returns_404(mock_firebase, mock_valid_token):
    """Valid token but no Firestore profile → 404."""
    from main import app

    with patch(
        "routers.auth.FirestoreService.get_user",
        new_callable=AsyncMock,
        return_value=None,
    ):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/auth/me", headers={"Authorization": "Bearer valid-token"}
            )
    assert response.status_code == 404


# ── sync-profile ──────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_sync_profile_creates_user(
    mock_firebase, mock_valid_token, mock_firestore_upsert_user
):
    """POST /auth/sync-profile with valid token → 200, returns profile."""
    from main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/auth/sync-profile",
            headers={"Authorization": "Bearer valid-token"},
            json={"name": "Test User", "phone": "+52 33 1234 5678", "role": "BUYER"},
        )
    assert response.status_code == 200
    data = response.json()
    assert data["uid"] == VALID_UID
    assert data["role"] == "BUYER"


@pytest.mark.asyncio
async def test_sync_profile_updates_existing_user(
    mock_firebase, mock_valid_token, mock_firestore_upsert_user
):
    """POST /auth/sync-profile second call (update) → 200, same uid."""
    from main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post(
            "/auth/sync-profile",
            headers={"Authorization": "Bearer valid-token"},
            json={"name": "Test User Updated", "phone": "+52 33 1234 5678", "role": "BUYER"},
        )
    assert response.status_code == 200
    assert response.json()["uid"] == VALID_UID
