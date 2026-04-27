"""F1 — smoke tests: each router exposes GET /health → 200 {"status": "ok"}."""
from unittest.mock import patch

import pytest
from httpx import ASGITransport, AsyncClient


@pytest.fixture
def mock_firebase():
    """Prevent real Firebase Admin SDK init during tests."""
    with patch("main.FirebaseAdminInit.initialize"):
        yield


@pytest.mark.asyncio
async def test_auth_health(mock_firebase):
    from main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/auth/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_stops_health(mock_firebase):
    from main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/stops/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_risk_zones_health(mock_firebase):
    from main import app

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/risk-zones/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
