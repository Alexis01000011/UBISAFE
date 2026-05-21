import json
import os

import firebase_admin
from firebase_admin import credentials, firestore, messaging


class _EmulatorCredential(credentials.Base):
    """No-op credential for emulator-only development.

    Firebase emulators do not verify Admin SDK credentials, so any credential
    object satisfies the SDK.  Using AnonymousCredentials avoids the
    google.auth.default() call that requires ADC or a real service-account file.
    Only used when FIREBASE_AUTH_EMULATOR_HOST is set and no service account JSON
    is provided.
    """

    def get_credential(self):
        from google.auth.credentials import AnonymousCredentials  # type: ignore[import]

        return AnonymousCredentials()


class FirebaseAdminInit:
    _initialized: bool = False

    @classmethod
    def initialize(cls) -> None:
        if cls._initialized:
            return
        service_account_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if service_account_json:
            cred = credentials.Certificate(json.loads(service_account_json))
        elif os.environ.get("FIREBASE_AUTH_EMULATOR_HOST"):
            # Emulator mode: no real credentials needed — emulators bypass auth.
            cred = _EmulatorCredential()
        else:
            cred = credentials.ApplicationDefault()
        # The Admin SDK must know the project ID to verify emulator tokens
        # (aud: <project-id>) and to route Firestore calls correctly.
        project_id = os.environ.get("FIREBASE_PROJECT_ID", "demo-ubisafe")
        firebase_admin.initialize_app(cred, {"projectId": project_id})
        cls._initialized = True

    @staticmethod
    def get_firestore():
        return firestore.client()

    @staticmethod
    def get_fcm():
        return messaging
