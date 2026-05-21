from __future__ import annotations

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, Field

from modules.safety.schemas import GeoPoint


class GroupStayStatus(StrEnum):
    scheduled = "scheduled"
    active = "active"
    ended = "ended"
    cancelled = "cancelled"


class GroupStay(BaseModel):
    id: str
    vendor_uid: str
    location: GeoPoint
    start_at: str
    duration_minutes: int
    end_at: str
    status: str
    cancellation_reason: str | None = None
    attendees_count: int = 0
    risk_level_at_creation: str | None = None
    start_at_iso: str | None = None  # plain ISO string for FCM data payload
    created_at: str | None = None
    updated_at: str | None = None


class CreateGroupStayBody(BaseModel):
    location: GeoPoint
    start_at: datetime
    duration_minutes: int = Field(ge=15, le=480)


# (from_status, to_status) → required_role ("SYSTEM" = automated CF only)
GROUP_STAY_VALID_TRANSITIONS: dict[tuple[str, str], str] = {
    ("scheduled", "active"): "SYSTEM",
    ("scheduled", "cancelled"): "VENDOR",
    ("active", "ended"): "SYSTEM",
    ("active", "cancelled"): "VENDOR",
}


class CreateGroupStayResponse(BaseModel):
    """Response for POST /group-stays. Includes the created stay and an optional
    risk-zone warning when the location overlaps a MEDIUM or LOW risk zone."""

    stay: GroupStay
    warning: dict | None = None
