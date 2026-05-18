"""Cloud Functions gen2 — UBISAFE iter. 2.

aggregateDuplicateReports: Firestore onCreate trigger on community_reports/{id}.
  Detects spatial duplicates within 100 m of the same threat_type and marks
  the new report with is_duplicate=True + canonical_report_id.

expireRiskZones: Cloud Scheduler trigger every 30 minutes.
  Expires active risk_zones whose expires_at has passed (24-hour TTL).
  The onRiskZoneWrite trigger handles sending FCM after this batch update.

onRiskZoneWrite: Firestore onWrite trigger on risk_zones/{zone_id}.
  Fires on ANY deactivation source — scheduled job, REST API DELETE, or
  manual edit/delete in the Firebase console — and sends FCM
  risk_zone_expired to nearby users (<5 km) so their maps update in real-time.
"""
from __future__ import annotations

import math
from datetime import UTC, datetime

import firebase_admin
from firebase_admin import firestore, messaging
from firebase_functions import firestore_fn, options, scheduler_fn

from services.duplicate_detector import find_canonical

firebase_admin.initialize_app()

options.set_global_options(region="us-central1")

_NEARBY_RADIUS_KM = 5.0


# ─── Utilidades ──────────────────────────────────────────────────────────────

def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(d_lng / 2) ** 2
    )
    return r * 2 * math.asin(math.sqrt(a))


def _get_nearby_fcm_tokens(db, lat: float, lng: float) -> list[str]:
    """Return FCM tokens for users whose last_location is within _NEARBY_RADIUS_KM."""
    tokens: list[str] = []
    for user_doc in db.collection("users").stream():
        data = user_doc.to_dict() or {}
        token = data.get("fcm_token")
        if not token:
            continue
        loc = data.get("last_location")
        if not loc:
            continue
        if hasattr(loc, "latitude"):
            ulat, ulng = loc.latitude, loc.longitude
        else:
            ulat = loc.get("lat", 0.0)
            ulng = loc.get("lng", 0.0)
        if _haversine_km(lat, lng, ulat, ulng) <= _NEARBY_RADIUS_KM:
            tokens.append(token)
    return tokens


@firestore_fn.on_document_created(document="community_reports/{report_id}")
def aggregate_duplicate_reports(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """Mark new community report as duplicate if one exists within 100 m."""
    report_id: str = event.params["report_id"]
    snapshot = event.data

    if snapshot is None:
        return

    data = snapshot.to_dict() or {}
    threat_type: str = data.get("threat_type", "")
    loc = data.get("location")

    if loc is None:
        return

    if hasattr(loc, "latitude"):
        new_lat, new_lng = loc.latitude, loc.longitude
    else:
        new_lat = loc.get("lat", 0.0)
        new_lng = loc.get("lng", 0.0)

    db = firestore.client()
    canonical_id = find_canonical(db, report_id, threat_type, new_lat, new_lng)

    if canonical_id:
        db.collection("community_reports").document(report_id).update(
            {
                "is_duplicate": True,
                "canonical_report_id": canonical_id,
                "updated_at": firestore.SERVER_TIMESTAMP,
            }
        )


# ─── Expiración automática de zonas de riesgo ────────────────────────────────

@scheduler_fn.on_schedule(schedule="every 30 minutes")
def expire_risk_zones(event: scheduler_fn.ScheduledEvent) -> None:
    """Expire active risk zones that have passed their 24-hour TTL.

    Queries all active zones and expires those whose expires_at <= now.
    expires_at is stored as an ISO 8601 string by the Python API backend,
    so comparison is done in Python after parsing, not in Firestore.
    The onRiskZoneWrite trigger fires after each update and sends FCM.
    """
    db = firestore.client()
    now = datetime.now(tz=UTC)

    for doc in db.collection("risk_zones").where("active", "==", True).stream():
        data = doc.to_dict() or {}
        expires_raw = data.get("expires_at")
        if expires_raw is None:
            continue
        if isinstance(expires_raw, str):
            expires_dt = datetime.fromisoformat(expires_raw)
        elif hasattr(expires_raw, "timestamp"):
            expires_dt = datetime.fromtimestamp(expires_raw.timestamp(), tz=UTC)
        else:
            continue
        if expires_dt <= now:
            doc.reference.update(
                {
                    "active": False,
                    "expired_at": firestore.SERVER_TIMESTAMP,
                }
            )


@firestore_fn.on_document_written(document="risk_zones/{zone_id}")
def on_risk_zone_write(
    event: firestore_fn.Event[
        firestore_fn.Change[firestore_fn.DocumentSnapshot | None]
    ],
) -> None:
    """Send FCM risk_zone_expired when a zone transitions to inactive.

    Covers all deactivation sources:
      - expire_risk_zones scheduled job (active: True → False)
      - REST API DELETE /risk-zones/{id} (active: True → False)
      - Manual edit or delete in the Firebase console
    """
    before_snap = event.data.before
    after_snap = event.data.after

    before = before_snap.to_dict() if before_snap and before_snap.exists else None
    after = after_snap.to_dict() if after_snap and after_snap.exists else None

    was_active = before is not None and before.get("active") is True
    is_now_inactive = after is None or not after.get("active", True)

    if not was_active or not is_now_inactive:
        return

    loc = before.get("location") or {}
    if hasattr(loc, "latitude"):
        lat, lng = loc.latitude, loc.longitude
    else:
        lat = loc.get("lat", 0.0)
        lng = loc.get("lng", 0.0)

    db = firestore.client()
    tokens = _get_nearby_fcm_tokens(db, lat, lng)
    if not tokens:
        return

    zone_id: str = event.params["zone_id"]
    messaging.send_each_for_multicast(
        messaging.MulticastMessage(
            tokens=tokens,
            data={"type": "risk_zone_expired", "risk_zone_id": zone_id},
            android=messaging.AndroidConfig(priority="high"),
        )
    )
