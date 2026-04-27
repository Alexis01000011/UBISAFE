from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr


class UserProfile(BaseModel):
    uid: str
    name: str | None = None
    phone: str | None = None
    role: str | None = None
    email: EmailStr | None = None
    fcm_token: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class SyncProfileRequest(BaseModel):
    name: str | None = None
    phone: str | None = None
    role: str | None = None
    email: EmailStr | None = None


class DeviceTokenRequest(BaseModel):
    token: str
