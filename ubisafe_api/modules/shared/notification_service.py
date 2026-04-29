from __future__ import annotations

import asyncio
import logging

from firebase_admin import messaging

from modules.shared.firebase_admin_init import FirebaseAdminInit

logger = logging.getLogger(__name__)


class NotificationService:
    @staticmethod
    def send(token: str, title: str, body: str, data: dict | None = None) -> str:
        fcm = FirebaseAdminInit.get_fcm()
        message = fcm.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
        )
        return fcm.send(message)

    @staticmethod
    async def send_async(
        token: str, title: str, body: str, data: dict | None = None
    ) -> str | None:
        try:
            return await asyncio.to_thread(
                NotificationService.send, token, title, body, data
            )
        except messaging.UnregisteredError:
            logger.warning("FCM token unregistered: %s", token[:20])
            return None
        except Exception as exc:
            logger.error("FCM send failed: %s", exc)
            return None

    @staticmethod
    async def send_to_user(
        uid: str, title: str, body: str, data: dict | None = None
    ) -> None:
        # Import here to avoid circular dependency
        from modules.shared.firestore_service import FirestoreService

        profile = await FirestoreService.get_user(uid)
        if not profile or not profile.fcm_token:
            logger.debug("No FCM token for uid=%s, skipping notification", uid)
            return
        await NotificationService.send_async(profile.fcm_token, title, body, data)

    @staticmethod
    async def send_stop_incoming(
        vendor_uid: str, stop_id: str, buyer_lat: float, buyer_lng: float
    ) -> None:
        await NotificationService.send_to_user(
            uid=vendor_uid,
            title="Nueva solicitud de parada",
            body="Un comprador cerca de ti solicita que te detengas.",
            data={
                "type": "stop_request_incoming",
                "stop_id": stop_id,
                "buyer_lat": str(buyer_lat),
                "buyer_lng": str(buyer_lng),
            },
        )

    @staticmethod
    async def send_stop_accepted(buyer_uid: str, stop_id: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="¡El vendedor aceptó!",
            body="El vendedor se dirige hacia tu ubicación.",
            data={"type": "stop_request_accepted", "stop_id": stop_id},
        )

    @staticmethod
    async def send_stop_rejected(buyer_uid: str, stop_id: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="El vendedor no pudo atenderte",
            body="Intenta con otro vendedor cercano.",
            data={"type": "stop_request_rejected", "stop_id": stop_id},
        )

    @staticmethod
    async def send_stop_completed(buyer_uid: str, stop_id: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="¡El vendedor llegó!",
            body="El vendedor confirmó la entrega.",
            data={"type": "stop_request_completed", "stop_id": stop_id},
        )

    @staticmethod
    async def notify_risk_zone_alert(
        fcm_tokens: list[str], risk_zone_data: dict
    ) -> None:
        if not fcm_tokens:
            return
        data_str = {k: str(v) for k, v in risk_zone_data.items()}
        batch_size = 500
        for i in range(0, len(fcm_tokens), batch_size):
            batch = fcm_tokens[i : i + batch_size]
            message = messaging.MulticastMessage(data=data_str, tokens=batch)
            try:
                response = await asyncio.to_thread(messaging.send_multicast, message)
                if response.failure_count > 0:
                    for idx, result in enumerate(response.responses):
                        if not result.success:
                            logger.warning(
                                "FCM multicast failure for token %s: %s",
                                batch[idx][:20],
                                result.exception,
                            )
            except Exception as exc:
                logger.error("FCM multicast failed: %s", exc)
