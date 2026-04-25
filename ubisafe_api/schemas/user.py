from __future__ import annotations

from pydantic import BaseModel, EmailStr


class UserProfile(BaseModel):
    uid: str
    email: EmailStr | None = None
    display_name: str | None = None
    photo_url: str | None = None
    device_token: str | None = None


class SyncProfileRequest(BaseModel):
    email: EmailStr | None = None
    display_name: str | None = None
    photo_url: str | None = None


class DeviceTokenRequest(BaseModel):
    token: str
