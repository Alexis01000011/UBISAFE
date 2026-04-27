from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel


class UserProfile(BaseModel):
    uid: str
    name: str | None = None
    phone: str | None = None
    role: str | None = None
    fcm_token: str | None = None
    # Anticipatory iter.1 fields (SDD §7.2.1) — updated by GPSService in foreground
    last_location: dict[str, Any] | None = None
    last_location_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class SyncProfileRequest(BaseModel):
    name: str | None = None
    phone: str | None = None
    role: str | None = None


class DeviceTokenRequest(BaseModel):
    token: str
