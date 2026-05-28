from __future__ import annotations

import asyncio
import logging

from firebase_admin import messaging

from modules.shared.firebase_admin_init import FirebaseAdminInit

logger = logging.getLogger(__name__)


class NotificationService:
    @staticmethod
    def send(token: str, title: str, body: str, data: dict | None = None) -> str:
        # B12: mensaje data-only — sin notification body para que Flutter procese
        # el payload de forma idéntica en foreground y background, y para evitar
        # que Android/iOS muestren una notificación del SO que luego puede
        # disparar onMessageOpenedApp con datos ya expirados.
        # Los parámetros title y body se conservan en la firma para no romper
        # los call-sites, pero no se incluyen en el Message.
        fcm = FirebaseAdminInit.get_fcm()
        message = fcm.Message(
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
        )
        return fcm.send(message)

    @staticmethod
    async def send_async(token: str, title: str, body: str, data: dict | None = None) -> str | None:
        try:
            return await asyncio.to_thread(NotificationService.send, token, title, body, data)
        except messaging.UnregisteredError:
            logger.warning("FCM token unregistered: %s", token[:20])
            return None
        except Exception as exc:
            logger.error("FCM send failed: %s", exc)
            return None

    @staticmethod
    async def send_to_user(uid: str, title: str, body: str, data: dict | None = None) -> None:
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
    async def send_stop_expired(buyer_uid: str, stop_id: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="Tiempo de espera agotado",
            body="El vendedor no respondió a tiempo.",
            data={"type": "stop_request_expired", "stop_id": stop_id},
        )

    @staticmethod
    async def send_stop_expired_vendor(vendor_uid: str, stop_id: str) -> None:
        await NotificationService.send_to_user(
            uid=vendor_uid,
            title="Solicitud de parada expirada",
            body="El comprador no obtuvo respuesta a tiempo.",
            data={"type": "stop_request_expired", "stop_id": stop_id},
        )

    @staticmethod
    async def send_stop_cancelled(vendor_uid: str, stop_id: str) -> None:
        await NotificationService.send_to_user(
            uid=vendor_uid,
            title="Parada cancelada",
            body="El comprador canceló la solicitud de parada.",
            data={"type": "stop_request_cancelled", "stop_id": stop_id},
        )

    @staticmethod
    async def send_stop_abandoned(buyer_uid: str, stop_id: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="Entrega cancelada",
            body="El vendedor abandonó la aplicación.",
            data={"type": "stop_abandoned", "stop_id": stop_id},
        )

    @staticmethod
    async def send_ride_abandoned(buyer_uid: str, ride_id: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="Raite cancelado",
            body="El vendedor abandonó la aplicación.",
            data={"type": "ride_abandoned", "ride_id": ride_id},
        )

    @staticmethod
    async def send_community_report_nearby(
        tokens: list[str],
        report_id: str,
        threat_type: str,
        lat: float,
        lng: float,
    ) -> None:
        """FCM multicast to all users when a new community report is created."""
        if not tokens:
            return
        fcm = FirebaseAdminInit.get_fcm()
        data = {
            "type": "community_report_nearby",
            "report_id": report_id,
            "threat_type": threat_type,
            "lat": str(lat),
            "lng": str(lng),
        }
        chunk_size = 500
        for i in range(0, len(tokens), chunk_size):
            chunk = tokens[i : i + chunk_size]
            try:
                message = fcm.MulticastMessage(data=data, tokens=chunk)
                await asyncio.to_thread(fcm.send_each_for_multicast, message)
            except Exception as exc:
                logger.error("FCM community_report_nearby multicast failed: %s", exc)

    # ------------------------------------------------------------------ rides
    @staticmethod
    async def send_ride_incoming(
        vendor_uid: str,
        ride_id: str,
        pickup_lat: float,
        pickup_lng: float,
        destination_lat: float,
        destination_lng: float,
    ) -> None:
        await NotificationService.send_to_user(
            uid=vendor_uid,
            title="Nueva solicitud de raite",
            body="Un pasajero te solicita un raite.",
            data={
                "type": "ride_request_incoming",
                "ride_id": ride_id,
                "pickup_lat": str(pickup_lat),
                "pickup_lng": str(pickup_lng),
                "destination_lat": str(destination_lat),
                "destination_lng": str(destination_lng),
            },
        )

    @staticmethod
    async def send_ride_destination_too_far(
        vendor_uid: str, ride_id: str, distance_km: float
    ) -> None:
        await NotificationService.send_to_user(
            uid=vendor_uid,
            title="Destino fuera de rango",
            body=f"El destino está a {distance_km} km. Debes rechazar este raite.",
            data={
                "type": "ride_destination_too_far",
                "ride_id": ride_id,
                "distance_km": str(distance_km),
            },
        )

    @staticmethod
    async def send_ride_accepted(buyer_uid: str, ride_id: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="¡El vendedor aceptó tu raite!",
            body="El vendedor se dirige hacia tu punto de recogida.",
            data={"type": "ride_request_accepted", "ride_id": ride_id},
        )

    @staticmethod
    async def send_ride_rejected(buyer_uid: str, ride_id: str, reason: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="El vendedor no pudo llevarte",
            body="Intenta con otro vendedor cercano.",
            data={"type": "ride_request_rejected", "ride_id": ride_id, "reason": reason},
        )

    @staticmethod
    async def send_ride_completed(buyer_uid: str, vendor_uid: str, ride_id: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="¡Raite completado!",
            body="Llegaste a tu destino. ¡Que te vaya bien!",
            data={"type": "ride_completed", "ride_id": ride_id},
        )
        await NotificationService.send_to_user(
            uid=vendor_uid,
            title="Raite completado",
            body="El viaje terminó exitosamente.",
            data={"type": "ride_completed", "ride_id": ride_id},
        )

    @staticmethod
    async def send_ride_vendor_arrived(buyer_uid: str, ride_id: str) -> None:
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="¡El vendedor llegó!",
            body="El vendedor está esperándote en el punto de recogida.",
            data={"type": "ride_vendor_arrived", "ride_id": ride_id},
        )

    @staticmethod
    async def send_ride_cancelled_by_buyer(vendor_uid: str, ride_id: str) -> None:
        await NotificationService.send_to_user(
            uid=vendor_uid,
            title="Raite cancelado",
            body="El pasajero canceló el raite.",
            data={"type": "ride_cancelled_by_buyer", "ride_id": ride_id},
        )

    @staticmethod
    async def send_ride_expired(vendor_uid: str, ride_id: str) -> None:
        await NotificationService.send_to_user(
            uid=vendor_uid,
            title="Solicitud expirada",
            body="La solicitud de raite expiró sin respuesta.",
            data={"type": "ride_request_expired", "ride_id": ride_id},
        )

    @staticmethod
    async def send_route_zone_warning(
        buyer_uid: str, request_id: str, zone_count: int, *, is_ride: bool
    ) -> None:
        """Notifies the buyer that the vendor's route passes through MEDIUM risk zones."""
        id_key = "ride_id" if is_ride else "stop_id"
        await NotificationService.send_to_user(
            uid=buyer_uid,
            title="Advertencia de ruta",
            body=f"La ruta pasa por {zone_count} zona(s) de riesgo MEDIO.",
            data={
                "type": "route_zone_warning",
                id_key: request_id,
                "zone_count": str(zone_count),
                "risk_level": "MEDIUM",
            },
        )

    @staticmethod
    async def send_lot_resolved(
        reporter_uid: str,
        supporter_uids: list[str],
        report_id: str,
        resolved_by_uid: str,
    ) -> None:
        data = {
            "type": "lot_resolved",
            "report_id": report_id,
            "resolved_by_uid": resolved_by_uid,
        }
        recipients = list({reporter_uid} | set(supporter_uids))
        for uid in recipients:
            await NotificationService.send_to_user(
                uid=uid,
                title="Lote baldío resuelto",
                body="Un lote baldío que seguías fue marcado como resuelto.",
                data=data,
            )

    @staticmethod
    async def send_group_stay_cancelled(
        attendee_uids: list[str],
        stay_id: str,
        reason: str,
    ) -> None:
        data = {
            "type": "group_stay_cancelled",
            "group_stay_id": stay_id,
            "reason": reason,
        }
        for uid in attendee_uids:
            await NotificationService.send_to_user(
                uid=uid,
                title="Estancia grupal cancelada",
                body="Una estancia grupal que confirmaste fue cancelada.",
                data=data,
            )

    @staticmethod
    async def send_group_stay_cancelled_nearby(
        tokens: list[str], stay_id: str, reason: str, vendor_uid: str = ""
    ) -> None:
        """Multicast group_stay_cancelled to all nearby users (not just confirmed attendees)."""
        if not tokens:
            return
        fcm = FirebaseAdminInit.get_fcm()
        data = {
            "type": "group_stay_cancelled",
            "group_stay_id": stay_id,
            "reason": reason,
            "vendor_uid": vendor_uid,
        }
        chunk_size = 500
        for i in range(0, len(tokens), chunk_size):
            chunk = tokens[i : i + chunk_size]
            try:
                message = fcm.MulticastMessage(data=data, tokens=chunk)
                await asyncio.to_thread(fcm.send_each_for_multicast, message)
            except Exception as exc:
                logger.error("FCM group_stay_cancelled multicast failed: %s", exc)

    @staticmethod
    async def send_group_stay_created(tokens: list[str], stay_id: str) -> None:
        """Multicast group_stay_created to all nearby users so their maps update."""
        if not tokens:
            return
        fcm = FirebaseAdminInit.get_fcm()
        data = {"type": "group_stay_created", "group_stay_id": stay_id}
        chunk_size = 500
        for i in range(0, len(tokens), chunk_size):
            chunk = tokens[i : i + chunk_size]
            try:
                message = fcm.MulticastMessage(data=data, tokens=chunk)
                await asyncio.to_thread(fcm.send_each_for_multicast, message)
            except Exception as exc:
                logger.error("FCM group_stay_created multicast failed: %s", exc)

    @staticmethod
    async def send_risk_zone_dismissed(reporter_uid: str, zone_id: str) -> None:
        """Notifica al reportante que su zona fue desmentida por la comunidad."""
        await NotificationService.send_to_user(
            uid=reporter_uid,
            title="Tu zona de riesgo fue desmentida",
            body="La comunidad indicó que esta zona ya no representa un riesgo.",
            data={"type": "risk_zone_dismissed", "risk_zone_id": zone_id},
        )

    @staticmethod
    async def send_subscription_created(vendor_uid: str, buyer_name: str) -> None:
        """Notifica al vendedor que un comprador se suscribió a su actividad."""
        await NotificationService.send_to_user(
            uid=vendor_uid,
            title="Nueva suscripción",
            body=f"{buyer_name} se suscribió a tu actividad.",
            data={"type": "subscription_created", "buyer_name": buyer_name},
        )

    @staticmethod
    async def notify_risk_zone_alert(
        fcm_tokens: list[str],
        data: dict,
    ) -> None:
        """Multicast FCM alert to all users with a registered token."""
        if not fcm_tokens:
            return
        fcm = FirebaseAdminInit.get_fcm()
        data_str = {k: str(v) for k, v in data.items()}
        chunk_size = 500
        for i in range(0, len(fcm_tokens), chunk_size):
            chunk = fcm_tokens[i : i + chunk_size]
            try:
                message = fcm.MulticastMessage(data=data_str, tokens=chunk)
                await asyncio.to_thread(fcm.send_each_for_multicast, message)
            except Exception as exc:
                logger.error("FCM multicast failed: %s", exc)
