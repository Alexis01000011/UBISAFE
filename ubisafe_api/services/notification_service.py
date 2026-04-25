from firebase_admin import messaging

from services.firebase_admin_init import FirebaseAdminInit


class NotificationService:
    @staticmethod
    def send(token: str, title: str, body: str, data: dict | None = None) -> str:
        fcm = FirebaseAdminInit.get_fcm()
        message = fcm.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            token=token,
        )
        return fcm.send(message)
