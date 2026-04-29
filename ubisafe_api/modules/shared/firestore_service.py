from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta
from typing import Any

from google.cloud.firestore import SERVER_TIMESTAMP

from modules.community.schemas import (
    CommunityReport,
    CreateCommunityReportBody,
    ReportStatus,
    Validation,
    ValidationVerdict,
)
from modules.dispatching.ride_schemas import CreateRideBody, Ride
from modules.dispatching.schemas import CreateStopRequestBody, StopRequest
from modules.identity.schemas import SyncProfileRequest, UserProfile
from modules.safety.schemas import CreateRiskZoneBody, RiskZone
from modules.shared.firebase_admin_init import FirebaseAdminInit

_RISK_ZONE_TTL_HOURS = 24
_COMMUNITY_REPORT_TTL_HOURS = 24
_EARTH_RADIUS_KM = 6371.0


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Return great-circle distance in km between two points."""
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(
        math.radians(lat2)
    ) * math.sin(dlng / 2) ** 2
    return _EARTH_RADIUS_KM * 2 * math.asin(math.sqrt(a))

_STOP_REQUEST_TTL_SECONDS = 60


class FirestoreService:
    @staticmethod
    def _db():
        return FirebaseAdminInit.get_firestore()

    # ------------------------------------------------------------------ users
    @classmethod
    async def upsert_user(cls, uid: str, body: SyncProfileRequest) -> UserProfile:
        ref = cls._db().collection("users").document(uid)
        doc = ref.get()

        data: dict[str, Any] = body.model_dump(exclude_none=True)
        data["updated_at"] = SERVER_TIMESTAMP

        if not doc.exists:
            data["uid"] = uid
            data["created_at"] = SERVER_TIMESTAMP
            ref.set(data)
        else:
            ref.set(data, merge=True)

        doc = ref.get()
        raw = doc.to_dict() or {}
        raw.pop("uid", None)
        return UserProfile(uid=uid, **raw)

    @classmethod
    async def get_user(cls, uid: str) -> UserProfile | None:
        doc = cls._db().collection("users").document(uid).get()
        if not doc.exists:
            return None
        raw = doc.to_dict() or {}
        raw.pop("uid", None)
        return UserProfile(uid=uid, **raw)

    @classmethod
    async def update_device_token(cls, uid: str, token: str) -> None:
        cls._db().collection("users").document(uid).set(
            {"fcm_token": token, "updated_at": SERVER_TIMESTAMP}, merge=True
        )

    # --------------------------------------------------------------- stops
    @classmethod
    async def list_stop_requests(cls, uid: str) -> list[StopRequest]:
        docs = (
            cls._db()
            .collection("stop_requests")
            .where("buyer_uid", "==", uid)
            .stream()
        )
        return [StopRequest(id=d.id, **d.to_dict()) for d in docs]

    @classmethod
    async def create_stop_request(
        cls, uid: str, body: CreateStopRequestBody
    ) -> StopRequest:
        expires_at = (
            datetime.now(tz=UTC) + timedelta(seconds=_STOP_REQUEST_TTL_SECONDS)
        ).isoformat()
        data = body.model_dump()
        data["buyer_uid"] = uid
        data["status"] = "pending"
        data["expires_at"] = expires_at
        _, ref = cls._db().collection("stop_requests").add(data)
        doc = ref.get()
        return StopRequest(id=doc.id, **doc.to_dict())

    @classmethod
    async def get_stop_request(cls, stop_id: str) -> StopRequest | None:
        doc = cls._db().collection("stop_requests").document(stop_id).get()
        if not doc.exists:
            return None
        return StopRequest(id=doc.id, **doc.to_dict())

    @classmethod
    async def update_stop_status(cls, stop_id: str, new_status: str) -> StopRequest | None:
        ref = cls._db().collection("stop_requests").document(stop_id)
        doc = ref.get()
        if not doc.exists:
            return None
        ref.update({"status": new_status, "updated_at": SERVER_TIMESTAMP})
        doc = ref.get()
        return StopRequest(id=doc.id, **doc.to_dict())

    @classmethod
    async def update_stop_status_if_pending(
        cls, stop_id: str, new_status: str
    ) -> tuple[StopRequest | None, bool]:
        """Update status only if current status is 'pending'.

        Returns (doc, was_updated). If not pending, returns (current_doc, False).
        Used for race-condition detection when buyer sends 'expired'.
        """
        ref = cls._db().collection("stop_requests").document(stop_id)
        doc = ref.get()
        if not doc.exists:
            return None, False
        current = doc.to_dict() or {}
        if current.get("status") != "pending":
            return StopRequest(id=doc.id, **current), False
        ref.update({"status": new_status, "updated_at": SERVER_TIMESTAMP})
        doc = ref.get()
        return StopRequest(id=doc.id, **doc.to_dict()), True

    # ------------------------------------------------------------ risk zones
    @classmethod
    async def get_risk_zone(cls, zone_id: str) -> RiskZone | None:
        doc = cls._db().collection("risk_zones").document(zone_id).get()
        if not doc.exists:
            return None
        return RiskZone(id=doc.id, **doc.to_dict())

    @classmethod
    async def get_active_risk_zones(
        cls, lat: float | None, lng: float | None, radius_km: float | None
    ) -> list[RiskZone]:
        """Return active risk zones, optionally filtered by proximity."""
        query = cls._db().collection("risk_zones").where("active", "==", True)

        if lat is not None and lng is not None and radius_km is not None:
            # Bounding-box pre-filter (1° lat ≈ 111 km)
            delta_lat = radius_km / 111.0
            delta_lng = radius_km / (111.0 * math.cos(math.radians(lat)))
            query = (
                query.where("location.lat", ">=", lat - delta_lat)
                .where("location.lat", "<=", lat + delta_lat)
            )
            docs = query.stream()
            results = []
            for d in docs:
                raw = d.to_dict()
                loc = raw.get("location", {})
                doc_lat = loc.get("lat", 0.0)
                doc_lng = loc.get("lng", 0.0)
                if abs(doc_lng - lng) <= delta_lng and _haversine_km(
                    lat, lng, doc_lat, doc_lng
                ) <= radius_km:
                    results.append(RiskZone(id=d.id, **raw))
            return results

        return [RiskZone(id=d.id, **d.to_dict()) for d in query.stream()]

    @classmethod
    async def find_duplicate_risk_zone(
        cls, lat: float, lng: float, radius_meters: int
    ) -> RiskZone | None:
        """Return an existing active zone whose area overlaps the given point."""
        radius_km = radius_meters / 1000.0
        zones = await cls.get_active_risk_zones(lat, lng, radius_km * 2)
        for z in zones:
            dist_km = _haversine_km(lat, lng, z.location.lat, z.location.lng)
            combined_radius_km = (z.radius_meters + radius_meters) / 1000.0
            if dist_km <= combined_radius_km:
                return z
        return None

    @classmethod
    async def create_risk_zone(cls, uid: str, body: CreateRiskZoneBody) -> RiskZone:
        expires_at = (
            datetime.now(tz=UTC) + timedelta(hours=_RISK_ZONE_TTL_HOURS)
        ).isoformat()
        data = body.model_dump()
        data["reporter_uid"] = uid
        data["active"] = True
        data["created_at"] = SERVER_TIMESTAMP
        data["expires_at"] = expires_at
        data["expired_at"] = None
        _, ref = cls._db().collection("risk_zones").add(data)
        doc = ref.get()
        return RiskZone(id=doc.id, **doc.to_dict())

    @classmethod
    async def expire_risk_zone(cls, zone_id: str) -> RiskZone | None:
        ref = cls._db().collection("risk_zones").document(zone_id)
        doc = ref.get()
        if not doc.exists:
            return None
        ref.update({
            "active": False,
            "expired_at": SERVER_TIMESTAMP,
        })
        doc = ref.get()
        return RiskZone(id=doc.id, **doc.to_dict())

    @classmethod
    async def get_all_user_fcm_tokens(cls) -> list[str]:
        """Return all non-null FCM tokens from the users collection."""
        docs = cls._db().collection("users").stream()
        return [
            d.to_dict()["fcm_token"]
            for d in docs
            if d.to_dict().get("fcm_token")
        ]

    # -------------------------------------------------- community_reports
    @classmethod
    def _doc_to_community_report(cls, doc: Any) -> CommunityReport:
        raw = doc.to_dict() or {}
        loc = raw.get("location", {})
        if hasattr(loc, "latitude"):
            # Native Firestore GeoPoint
            raw["location"] = {"lat": loc.latitude, "lng": loc.longitude}
        # Normalize Validation timestamps
        validations = []
        for v in raw.get("validations", []):
            ts = v.get("timestamp")
            validations.append(
                Validation(
                    user_uid=v.get("user_uid", ""),
                    verdict=v.get("verdict", "confirm"),
                    timestamp=ts.isoformat() if hasattr(ts, "isoformat") else str(ts) if ts else None,
                )
            )
        raw["validations"] = [v.model_dump() for v in validations]
        for field in ("created_at", "updated_at", "expires_at"):
            val = raw.get(field)
            if hasattr(val, "isoformat"):
                raw[field] = val.isoformat()
            elif hasattr(val, "timestamp"):
                raw[field] = datetime.fromtimestamp(val.timestamp(), tz=UTC).isoformat()
        return CommunityReport(id=doc.id, **raw)

    @classmethod
    async def create_community_report(
        cls, uid: str, body: CreateCommunityReportBody
    ) -> CommunityReport:
        expires_at = (
            datetime.now(tz=UTC) + timedelta(hours=_COMMUNITY_REPORT_TTL_HOURS)
        ).isoformat()
        data = {
            "reporter_uid": uid,
            "threat_type": body.threat_type.value,
            "location": body.location.model_dump(),
            "radius_meters": 15,
            "status": ReportStatus.pending_validation.value,
            "validations": [],
            "confirm_count": 0,
            "dismiss_count": 0,
            "is_duplicate": False,
            "canonical_report_id": None,
            "created_at": SERVER_TIMESTAMP,
            "updated_at": SERVER_TIMESTAMP,
            "expires_at": expires_at,
        }
        _, ref = cls._db().collection("community_reports").add(data)
        doc = ref.get()
        return cls._doc_to_community_report(doc)

    @classmethod
    async def get_community_reports_in_bbox(
        cls,
        lat: float | None,
        lng: float | None,
        radius_km: float | None,
    ) -> list[CommunityReport]:
        """Return pending_validation and confirmed reports, optionally filtered by proximity."""
        active_statuses = [
            ReportStatus.pending_validation.value,
            ReportStatus.confirmed.value,
        ]
        query = cls._db().collection("community_reports").where(
            "status", "in", active_statuses
        )

        if lat is not None and lng is not None and radius_km is not None:
            delta_lat = radius_km / 111.0
            delta_lng = radius_km / (111.0 * math.cos(math.radians(lat)))
            query = (
                query.where("location.lat", ">=", lat - delta_lat)
                .where("location.lat", "<=", lat + delta_lat)
            )
            docs = query.stream()
            results = []
            for d in docs:
                raw = d.to_dict() or {}
                loc = raw.get("location", {})
                if hasattr(loc, "latitude"):
                    doc_lat, doc_lng = loc.latitude, loc.longitude
                else:
                    doc_lat = loc.get("lat", 0.0)
                    doc_lng = loc.get("lng", 0.0)
                if abs(doc_lng - lng) <= delta_lng and _haversine_km(
                    lat, lng, doc_lat, doc_lng
                ) <= radius_km:
                    results.append(cls._doc_to_community_report(d))
            return results

        return [cls._doc_to_community_report(d) for d in query.stream()]

    @classmethod
    async def get_community_report(cls, report_id: str) -> CommunityReport | None:
        doc = cls._db().collection("community_reports").document(report_id).get()
        if not doc.exists:
            return None
        return cls._doc_to_community_report(doc)

    @classmethod
    async def vote_community_report(
        cls, report_id: str, voter_uid: str, verdict: str
    ) -> CommunityReport:
        """Append a vote, increment the counter, and promote status if threshold reached."""
        from google.cloud.firestore import ArrayUnion, Increment  # noqa: PLC0415

        ref = cls._db().collection("community_reports").document(report_id)
        doc = ref.get()
        data = doc.to_dict() or {}

        vote_entry = {
            "user_uid": voter_uid,
            "verdict": verdict,
            "timestamp": datetime.now(tz=UTC).isoformat(),
        }

        update: dict[str, Any] = {
            "validations": ArrayUnion([vote_entry]),
            "updated_at": SERVER_TIMESTAMP,
        }

        if verdict == ValidationVerdict.confirm.value:
            update["confirm_count"] = Increment(1)
            if (data.get("confirm_count") or 0) + 1 >= 3:
                update["status"] = ReportStatus.confirmed.value
        else:
            update["dismiss_count"] = Increment(1)
            if (data.get("dismiss_count") or 0) + 1 >= 3:
                update["status"] = ReportStatus.dismissed.value

        ref.update(update)
        return cls._doc_to_community_report(ref.get())

    # ------------------------------------------------------------------ rides
    @classmethod
    def _doc_to_ride(cls, doc: Any) -> Ride:
        raw = doc.to_dict() or {}
        timestamp_fields = (
            "created_at", "updated_at", "accepted_at",
            "started_at", "completed_at", "expires_at",
        )
        for field in timestamp_fields:
            val = raw.get(field)
            if val is None:
                continue
            if hasattr(val, "isoformat"):
                raw[field] = val.isoformat()
            elif hasattr(val, "timestamp"):
                raw[field] = datetime.fromtimestamp(val.timestamp(), tz=UTC).isoformat()
        for geo_field in ("pickup_location", "destination"):
            loc = raw.get(geo_field)
            if loc is not None and hasattr(loc, "latitude"):
                raw[geo_field] = {"lat": loc.latitude, "lng": loc.longitude}
        return Ride(id=doc.id, **raw)

    @classmethod
    async def vendor_has_active_requests(cls, vendor_uid: str) -> bool:
        """Return True if vendor has pending/accepted/in_progress rides or stop_requests."""
        active_ride_statuses = ["pending", "accepted", "in_progress"]
        ride_docs = (
            cls._db()
            .collection("rides")
            .where("vendor_uid", "==", vendor_uid)
            .where("status", "in", active_ride_statuses)
            .limit(1)
            .stream()
        )
        if any(True for _ in ride_docs):
            return True
        stop_docs = (
            cls._db()
            .collection("stop_requests")
            .where("vendor_uid", "==", vendor_uid)
            .where("status", "in", ["pending", "accepted"])
            .limit(1)
            .stream()
        )
        return any(True for _ in stop_docs)

    @classmethod
    async def create_ride(cls, buyer_uid: str, body: CreateRideBody) -> Ride:
        from modules.dispatching.ride_schemas import _RIDE_TTL_SECONDS
        expires_at = (
            datetime.now(tz=UTC) + timedelta(seconds=_RIDE_TTL_SECONDS)
        ).isoformat()
        data = body.model_dump()
        data["buyer_uid"] = buyer_uid
        data["status"] = "pending"
        data["created_at"] = SERVER_TIMESTAMP
        data["updated_at"] = SERVER_TIMESTAMP
        data["expires_at"] = expires_at
        _, ref = cls._db().collection("rides").add(data)
        doc = ref.get()
        return cls._doc_to_ride(doc)

    @classmethod
    async def get_ride(cls, ride_id: str) -> Ride | None:
        doc = cls._db().collection("rides").document(ride_id).get()
        if not doc.exists:
            return None
        return cls._doc_to_ride(doc)

    @classmethod
    async def update_ride_status(cls, ride_id: str, new_status: str, extra: dict) -> Ride | None:
        ref = cls._db().collection("rides").document(ride_id)
        doc = ref.get()
        if not doc.exists:
            return None
        update_data: dict[str, Any] = {"status": new_status, "updated_at": SERVER_TIMESTAMP}
        for key, val in extra.items():
            update_data[key] = SERVER_TIMESTAMP if val is True else val
        ref.update(update_data)
        doc = ref.get()
        return cls._doc_to_ride(doc)

    @classmethod
    async def update_ride_status_if_pending(
        cls, ride_id: str, new_status: str, rejected_reason: str | None = None
    ) -> tuple[Ride | None, bool]:
        """Update status only if current status is 'pending'. Returns (doc, was_updated)."""
        ref = cls._db().collection("rides").document(ride_id)
        doc = ref.get()
        if not doc.exists:
            return None, False
        current = doc.to_dict() or {}
        if current.get("status") != "pending":
            return cls._doc_to_ride(doc), False
        update_data: dict[str, Any] = {"status": new_status, "updated_at": SERVER_TIMESTAMP}
        if rejected_reason:
            update_data["rejected_reason"] = rejected_reason
        ref.update(update_data)
        doc = ref.get()
        return cls._doc_to_ride(doc), True

    @classmethod
    async def update_ride_enabled(cls, uid: str, value: bool) -> None:
        cls._db().collection("users").document(uid).set(
            {"ride_enabled": value, "updated_at": SERVER_TIMESTAMP}, merge=True
        )
