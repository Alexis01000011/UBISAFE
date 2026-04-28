from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

from google.cloud.firestore import SERVER_TIMESTAMP

from modules.dispatching.schemas import CreateStopRequestBody, StopRequest
from modules.identity.schemas import SyncProfileRequest, UserProfile
from modules.safety.schemas import CreateRiskZoneBody, RiskZone
from modules.shared.firebase_admin_init import FirebaseAdminInit

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
    async def create_risk_zone(cls, reporter_uid: str, body: CreateRiskZoneBody) -> RiskZone:
        expires_at = (
            datetime.now(tz=UTC) + timedelta(hours=24)
        ).isoformat()
        data = body.model_dump()
        data["reporter_uid"] = reporter_uid
        data["active"] = True
        data["created_at"] = datetime.now(tz=UTC).isoformat()
        data["expires_at"] = expires_at
        data["expired_at"] = None
        _, ref = cls._db().collection("risk_zones").add(data)
        doc = ref.get()
        raw = doc.to_dict() or {}
        return RiskZone(id=doc.id, **raw)

    @classmethod
    async def query_active_risk_zones_bbox(
        cls, lat: float, lng: float, delta: float
    ) -> list[dict]:
        docs = (
            cls._db()
            .collection("risk_zones")
            .where("active", "==", True)
            .stream()
        )
        candidates = []
        for doc in docs:
            data = doc.to_dict() or {}
            loc = data.get("location") or {}
            zone_lat = loc.get("lat", 0)
            zone_lng = loc.get("lng", 0)
            if abs(zone_lat - lat) <= delta and abs(zone_lng - lng) <= delta:
                candidates.append({"id": doc.id, **data})
        return candidates

    @classmethod
    async def get_risk_zone(cls, zone_id: str) -> dict | None:
        doc = cls._db().collection("risk_zones").document(zone_id).get()
        if not doc.exists:
            return None
        return {"id": doc.id, **(doc.to_dict() or {})}

    @classmethod
    async def expire_risk_zone(cls, zone_id: str) -> None:
        cls._db().collection("risk_zones").document(zone_id).update({
            "active": False,
            "expired_at": datetime.now(tz=UTC).isoformat(),
        })

    @classmethod
    async def get_all_fcm_tokens(cls) -> list[str]:
        docs = cls._db().collection("users").stream()
        tokens = []
        for doc in docs:
            data = doc.to_dict() or {}
            token = data.get("fcm_token")
            if token:
                tokens.append(token)
        return tokens
