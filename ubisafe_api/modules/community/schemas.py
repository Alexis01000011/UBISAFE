from __future__ import annotations

from enum import StrEnum

from pydantic import BaseModel

from modules.safety.schemas import GeoPoint


class ThreatType(StrEnum):
    animal_muerto = "animal_muerto"
    zona_sucia = "zona_sucia"


class ReportStatus(StrEnum):
    pending_validation = "pending_validation"
    confirmed = "confirmed"
    dismissed = "dismissed"
    expired = "expired"


class ValidationVerdict(StrEnum):
    confirm = "confirm"
    dismiss = "dismiss"


class Validation(BaseModel):
    user_uid: str
    verdict: ValidationVerdict
    timestamp: str | None = None


class CommunityReport(BaseModel):
    id: str
    reporter_uid: str
    threat_type: ThreatType
    location: GeoPoint
    radius_meters: int = 15
    status: ReportStatus
    validations: list[Validation] = []
    confirm_count: int = 0
    dismiss_count: int = 0
    is_duplicate: bool = False
    canonical_report_id: str | None = None
    created_at: str | None = None
    updated_at: str | None = None
    expires_at: str | None = None


class CreateCommunityReportBody(BaseModel):
    threat_type: ThreatType
    location: GeoPoint
    # radius_meters is always 15 — not accepted from client


class VoteBody(BaseModel):
    vote: ValidationVerdict
