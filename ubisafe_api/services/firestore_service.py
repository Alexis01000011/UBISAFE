from __future__ import annotations

from typing import Any

from google.cloud.firestore import SERVER_TIMESTAMP

from schemas.risk_zone import CreateRiskZoneBody, RiskZone
from schemas.stop_request import CreateStopRequestBody, StopRequest
from schemas.user import SyncProfileRequest, UserProfile
from services.firebase_admin_init import FirebaseAdminInit


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

        # Re-fetch to get server-resolved timestamps
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
        data = body.model_dump()
        data["buyer_uid"] = uid
        data["status"] = "pending"
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
        ref.update({"status": new_status})
        doc = ref.get()
        return StopRequest(id=doc.id, **doc.to_dict())

    # ------------------------------------------------------------ risk zones
    @classmethod
    async def list_risk_zones(cls) -> list[RiskZone]:
        docs = cls._db().collection("risk_zones").stream()
        return [RiskZone(id=d.id, **d.to_dict()) for d in docs]

    @classmethod
    async def create_risk_zone(cls, uid: str, body: CreateRiskZoneBody) -> RiskZone:
        data = body.model_dump()
        data["reported_by"] = uid
        _, ref = cls._db().collection("risk_zones").add(data)
        doc = ref.get()
        return RiskZone(id=doc.id, **doc.to_dict())
