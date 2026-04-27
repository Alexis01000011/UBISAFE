import json
import os

import firebase_admin
from firebase_admin import credentials, firestore, messaging


class FirebaseAdminInit:
    _initialized: bool = False

    @classmethod
    def initialize(cls) -> None:
        if cls._initialized:
            return
        service_account_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if service_account_json:
            cred = credentials.Certificate(json.loads(service_account_json))
        else:
            cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
        cls._initialized = True

    @staticmethod
    def get_firestore():
        return firestore.client()

    @staticmethod
    def get_fcm():
        return messaging
