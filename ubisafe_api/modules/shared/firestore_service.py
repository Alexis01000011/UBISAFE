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
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng / 2) ** 2
    )
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
        if "role" in data and isinstance(data["role"], str):
            data["role"] = data["role"].upper()
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
    def _doc_to_stop_request(cls, doc: Any) -> StopRequest:
        raw = doc.to_dict() or {}
        for field in ("created_at", "updated_at", "expires_at", "accepted_at", "completed_at"):
            val = raw.get(field)
            if val is None:
                continue
            if hasattr(val, "isoformat"):
                raw[field] = val.isoformat()
            elif hasattr(val, "timestamp"):
                raw[field] = datetime.fromtimestamp(val.timestamp(), tz=UTC).isoformat()
        return StopRequest(id=doc.id, **raw)

    @classmethod
    async def list_stop_requests(cls, uid: str) -> list[StopRequest]:
        docs = cls._db().collection("stop_requests").where("buyer_uid", "==", uid).stream()
        return [cls._doc_to_stop_request(d) for d in docs]

    @classmethod
    async def create_stop_request(cls, uid: str, body: CreateStopRequestBody) -> StopRequest:
        expires_at = (
            datetime.now(tz=UTC) + timedelta(seconds=_STOP_REQUEST_TTL_SECONDS)
        ).isoformat()
        data = body.model_dump()
        data["buyer_uid"] = uid
        data["status"] = "pending"
        data["expires_at"] = expires_at
        data["created_at"] = SERVER_TIMESTAMP
        data["updated_at"] = SERVER_TIMESTAMP
        _, ref = cls._db().collection("stop_requests").add(data)
        doc = ref.get()
        return cls._doc_to_stop_request(doc)

    @classmethod
    async def get_stop_request(cls, stop_id: str) -> StopRequest | None:
        doc = cls._db().collection("stop_requests").document(stop_id).get()
        if not doc.exists:
            return None
        return cls._doc_to_stop_request(doc)

    @classmethod
    async def update_stop_status(cls, stop_id: str, new_status: str, extra: dict | None = None) -> StopRequest | None:
        ref = cls._db().collection("stop_requests").document(stop_id)
        doc = ref.get()
        if not doc.exists:
            return None
        update_data: dict[str, Any] = {"status": new_status, "updated_at": SERVER_TIMESTAMP}
        if extra:
            update_data.update({k: SERVER_TIMESTAMP for k, v in extra.items() if v is True})
        ref.update(update_data)
        doc = ref.get()
        return cls._doc_to_stop_request(doc)

    @classmethod
    async def update_stop_status_if_in_state(
        cls,
        stop_id: str,
        from_status: str,
        new_status: str,
        extra: dict | None = None,
    ) -> tuple[StopRequest | None, bool]:
        """Atomically update stop status only when current status == from_status.

        Uses a Firestore transaction to close the TOCTOU window between the
        VALID_TRANSITIONS check in the router and the actual Firestore write.
        Returns (updated_doc, True) on success; (current_doc, False) if state
        doesn't match from_status; (None, False) if the document doesn't exist.
        """
        from google.cloud.firestore import transactional as fs_transactional  # noqa: PLC0415

        db = cls._db()
        ref = db.collection("stop_requests").document(stop_id)

        @fs_transactional
        def _txn(transaction):
            doc = ref.get(transaction=transaction)
            if not doc.exists:
                return None, False
            if (doc.to_dict() or {}).get("status") != from_status:
                return cls._doc_to_stop_request(doc), False
            update_data: dict[str, Any] = {"status": new_status, "updated_at": SERVER_TIMESTAMP}
            if extra:
                update_data.update({k: SERVER_TIMESTAMP for k, v in extra.items() if v is True})
            transaction.update(ref, update_data)
            return None, True

        result, was_updated = _txn(db.transaction())
        if was_updated:
            doc = ref.get()
            return cls._doc_to_stop_request(doc), True
        return result, was_updated

    @classmethod
    async def update_stop_status_if_pending(
        cls, stop_id: str, new_status: str
    ) -> tuple[StopRequest | None, bool]:
        """Update status only if current status is 'pending' — atomically (B07).

        Thin wrapper around update_stop_status_if_in_state kept for backwards
        compatibility with the expired-transition path in the router.
        """
        return await cls.update_stop_status_if_in_state(stop_id, "pending", new_status)

    # ------------------------------------------------------------ risk zones
    @classmethod
    def _doc_to_risk_zone(cls, doc: Any) -> RiskZone:
        raw = doc.to_dict() or {}
        for field in ("created_at", "expires_at", "expired_at"):
            val = raw.get(field)
            if val is None:
                continue
            if hasattr(val, "isoformat"):
                raw[field] = val.isoformat()
            elif hasattr(val, "timestamp"):
                raw[field] = datetime.fromtimestamp(val.timestamp(), tz=UTC).isoformat()
        return RiskZone(id=doc.id, **raw)

    @classmethod
    async def get_risk_zone(cls, zone_id: str) -> RiskZone | None:
        doc = cls._db().collection("risk_zones").document(zone_id).get()
        if not doc.exists:
            return None
        return cls._doc_to_risk_zone(doc)

    @classmethod
    async def get_active_risk_zones(
        cls, lat: float | None, lng: float | None, radius_km: float | None
    ) -> list[RiskZone]:
        """Return active risk zones, optionally filtered by proximity.

        Proximity filtering is done in Python to avoid requiring a Firestore
        composite index on (active, location.lat).
        """
        docs = cls._db().collection("risk_zones").where("active", "==", True).stream()
        results = []
        for d in docs:
            raw = d.to_dict()
            if lat is None or lng is None or radius_km is None:
                results.append(cls._doc_to_risk_zone(d))
                continue
            loc = raw.get("location", {})
            doc_lat = loc.get("lat", 0.0)
            doc_lng = loc.get("lng", 0.0)
            if _haversine_km(lat, lng, doc_lat, doc_lng) <= radius_km:
                results.append(cls._doc_to_risk_zone(d))
        return results

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
        expires_at = (datetime.now(tz=UTC) + timedelta(hours=_RISK_ZONE_TTL_HOURS)).isoformat()
        data = body.model_dump()
        data["reporter_uid"] = uid
        data["active"] = True
        data["created_at"] = SERVER_TIMESTAMP
        data["expires_at"] = expires_at
        data["expired_at"] = None
        _, ref = cls._db().collection("risk_zones").add(data)
        doc = ref.get()
        return cls._doc_to_risk_zone(doc)

    @classmethod
    async def expire_risk_zone(cls, zone_id: str) -> RiskZone | None:
        ref = cls._db().collection("risk_zones").document(zone_id)
        doc = ref.get()
        if not doc.exists:
            return None
        ref.update(
            {
                "active": False,
                "expired_at": SERVER_TIMESTAMP,
            }
        )
        doc = ref.get()
        return cls._doc_to_risk_zone(doc)

    @classmethod
    async def query_active_risk_zones_bbox(
        cls, lat: float, lng: float, lat_delta: float, lng_delta: float
    ) -> list[dict]:
        """Return active zones whose location falls within a lat/lng bounding box."""
        docs = cls._db().collection("risk_zones").where("active", "==", True).stream()
        candidates = []
        for doc in docs:
            data = doc.to_dict() or {}
            loc = data.get("location") or {}
            zone_lat = loc.get("lat", 0)
            zone_lng = loc.get("lng", 0)
            if abs(zone_lat - lat) <= lat_delta and abs(zone_lng - lng) <= lng_delta:
                candidates.append({"id": doc.id, **data})
        return candidates

    @classmethod
    async def get_all_fcm_tokens(cls) -> list[str]:
        """Return all non-null FCM tokens from the users collection."""
        docs = cls._db().collection("users").stream()
        tokens = []
        for doc in docs:
            data = doc.to_dict() or {}
            token = data.get("fcm_token")
            if token:
                tokens.append(token)
        return tokens

    @classmethod
    async def get_all_user_fcm_tokens(cls) -> list[str]:
        """Alias for get_all_fcm_tokens."""
        return await cls.get_all_fcm_tokens()

    @classmethod
    async def get_nearby_user_fcm_tokens(
        cls, lat: float, lng: float, radius_km: float
    ) -> list[str]:
        """Return FCM tokens for users whose last_location is within radius_km."""
        docs = cls._db().collection("users").stream()
        tokens: list[str] = []
        for d in docs:
            data = d.to_dict() or {}
            token = data.get("fcm_token")
            if not token:
                continue
            loc = data.get("last_location")
            if not loc:
                continue
            dist = _haversine_km(lat, lng, loc.get("lat", 0.0), loc.get("lng", 0.0))
            if dist <= radius_km:
                tokens.append(token)
        return tokens

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
            ts_str = ts.isoformat() if hasattr(ts, "isoformat") else str(ts) if ts else None
            validations.append(
                Validation(
                    user_uid=v.get("user_uid", ""),
                    verdict=v.get("verdict", "confirm"),
                    timestamp=ts_str,
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
        # Proximity filtering is done in Python to avoid requiring a Firestore
        # composite index on (status, location.lat).
        docs = (
            cls._db()
            .collection("community_reports")
            .where("status", "in", active_statuses)
            .stream()
        )
        results = []
        for d in docs:
            if lat is None or lng is None or radius_km is None:
                results.append(cls._doc_to_community_report(d))
                continue
            raw = d.to_dict() or {}
            loc = raw.get("location", {})
            if hasattr(loc, "latitude"):
                doc_lat, doc_lng = loc.latitude, loc.longitude
            else:
                doc_lat = loc.get("lat", 0.0)
                doc_lng = loc.get("lng", 0.0)
            if _haversine_km(lat, lng, doc_lat, doc_lng) <= radius_km:
                results.append(cls._doc_to_community_report(d))
        return results

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
        """Append a vote and promote status atomically via a Firestore transaction."""
        from google.cloud.firestore import transactional as fs_transactional  # noqa: PLC0415

        db = cls._db()
        ref = db.collection("community_reports").document(report_id)

        @fs_transactional
        def _txn(transaction):
            doc = ref.get(transaction=transaction)
            data = doc.to_dict() or {}

            vote_entry = {
                "user_uid": voter_uid,
                "verdict": verdict,
                "timestamp": datetime.now(tz=UTC).isoformat(),
            }
            validations = list(data.get("validations", []))
            validations.append(vote_entry)

            confirm_count = data.get("confirm_count", 0)
            dismiss_count = data.get("dismiss_count", 0)
            update: dict[str, Any] = {
                "validations": validations,
                "updated_at": SERVER_TIMESTAMP,
            }

            if verdict == ValidationVerdict.confirm.value:
                confirm_count += 1
                update["confirm_count"] = confirm_count
                if confirm_count >= 3:
                    update["status"] = ReportStatus.confirmed.value
            else:
                dismiss_count += 1
                update["dismiss_count"] = dismiss_count
                if dismiss_count >= 3:
                    update["status"] = ReportStatus.dismissed.value

            transaction.update(ref, update)

        _txn(db.transaction())
        return cls._doc_to_community_report(ref.get())

    # ------------------------------------------------------------------ rides
    @classmethod
    def _doc_to_ride(cls, doc: Any) -> Ride:
        raw = doc.to_dict() or {}
        timestamp_fields = (
            "created_at",
            "updated_at",
            "accepted_at",
            "started_at",
            "completed_at",
            "expires_at",
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
        """Return True if vendor has active (non-expired) rides or stop_requests.

        "pending" rides/stops are skipped if their expires_at is in the past —
        the client timer is the only enforcer of TTL, so stale pending docs must
        not block new requests indefinitely (e.g. after an app crash).
        "accepted" and "in_progress" rides always block (no automatic TTL).
        """
        now = datetime.now(tz=UTC)

        def _is_expired_pending(data: dict) -> bool:
            """True when a pending doc has passed its TTL."""
            if data.get("status") != "pending":
                return False
            raw_exp = data.get("expires_at")
            if raw_exp is None:
                return False
            if hasattr(raw_exp, "timestamp"):  # Firestore Timestamp object
                exp_dt = datetime.fromtimestamp(raw_exp.timestamp(), tz=UTC)
            else:
                exp_dt = datetime.fromisoformat(str(raw_exp))
            return exp_dt < now

        active_ride_statuses = ["pending", "accepted", "in_progress"]
        ride_docs = (
            cls._db()
            .collection("rides")
            .where("vendor_uid", "==", vendor_uid)
            .where("status", "in", active_ride_statuses)
            .limit(10)
            .stream()
        )
        for doc in ride_docs:
            if not _is_expired_pending(doc.to_dict() or {}):
                return True

        stop_docs = (
            cls._db()
            .collection("stop_requests")
            .where("vendor_uid", "==", vendor_uid)
            .where("status", "in", ["pending", "accepted"])
            .limit(10)
            .stream()
        )
        for doc in stop_docs:
            if not _is_expired_pending(doc.to_dict() or {}):
                return True

        return False

    @classmethod
    async def create_ride(cls, buyer_uid: str, body: CreateRideBody) -> Ride:
        from modules.dispatching.ride_schemas import _RIDE_TTL_SECONDS

        expires_at = (datetime.now(tz=UTC) + timedelta(seconds=_RIDE_TTL_SECONDS)).isoformat()
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

    @classmethod
    async def update_user_location(cls, uid: str, lat: float, lng: float) -> None:
        cls._db().collection("users").document(uid).set(
            {
                "last_location": {"lat": lat, "lng": lng},
                "last_location_at": SERVER_TIMESTAMP,
                "updated_at": SERVER_TIMESTAMP,
            },
            merge=True,
        )
