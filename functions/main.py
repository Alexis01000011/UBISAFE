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
from services.fan_out import haversine_km as _fan_haversine_km
from services.fan_out import send_multicast as _fan_send_multicast

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


# ─── CU-09-D: Expiración y cancelación reactiva de estancias ────────────────

def _notify_stay_cancelled(
    db, stay_id: str, vendor_uid: str | None, reason: str
) -> None:
    """Multicast group_stay_cancelled FCM to vendor + confirmed attendees."""
    tokens: list[str] = []

    if vendor_uid:
        vendor_doc = db.collection("users").document(vendor_uid).get()
        if vendor_doc.exists:
            token = (vendor_doc.to_dict() or {}).get("fcm_token")
            if token:
                tokens.append(token)

    for att_doc in (
        db.collection("group_stays")
        .document(stay_id)
        .collection("attendances")
        .stream()
    ):
        buyer_doc = db.collection("users").document(att_doc.id).get()
        if buyer_doc.exists:
            token = (buyer_doc.to_dict() or {}).get("fcm_token")
            if token:
                tokens.append(token)

    _fan_send_multicast(tokens, data={
        "type": "group_stay_cancelled",
        "group_stay_id": stay_id,
        "reason": reason,
    })


@scheduler_fn.on_schedule(schedule="every 5 minutes")
def expire_group_stays(event: scheduler_fn.ScheduledEvent) -> None:
    """Transition group stays automatically.

    scheduled → active  when start_at  <= now
    active    → ended   when end_at    <= now

    start_at and end_at are stored as ISO 8601 UTC strings, so string
    comparison is valid here (all values share the same format/timezone).
    A batch write avoids partial updates if the function is interrupted.
    """
    now_iso = datetime.now(tz=UTC).isoformat()
    db = firestore.client()

    to_activate = (
        db.collection("group_stays")
        .where("status", "==", "scheduled")
        .where("start_at", "<=", now_iso)
        .stream()
    )
    to_end = (
        db.collection("group_stays")
        .where("status", "==", "active")
        .where("end_at", "<=", now_iso)
        .stream()
    )

    batch = db.batch()
    for s in to_activate:
        batch.update(
            s.reference,
            {"status": "active", "updated_at": firestore.SERVER_TIMESTAMP},
        )
    for s in to_end:
        batch.update(
            s.reference,
            {"status": "ended", "updated_at": firestore.SERVER_TIMESTAMP},
        )
    batch.commit()


@firestore_fn.on_document_updated(document="risk_zones/{zone_id}")
def cancel_stay_on_risk_zone_change(
    event: firestore_fn.Event[
        firestore_fn.Change[firestore_fn.DocumentSnapshot | None]
    ],
) -> None:
    """Cancel scheduled/active stays inside a risk zone that transitions to HIGH.

    Guards:
    - Only fires on the LOW/MEDIUM → HIGH transition (not on every update).
    - Zone must be active at the time of the write.
    """
    before_snap = event.data.before
    after_snap = event.data.after

    before = before_snap.to_dict() if before_snap and before_snap.exists else {}
    after = after_snap.to_dict() if after_snap and after_snap.exists else {}

    # Guard: only react when risk_level transitions TO HIGH
    if after.get("risk_level") != "HIGH" or not after.get("active", False):
        return
    if before.get("risk_level") == "HIGH":
        return  # was already HIGH — no transition to handle

    zone_loc = after.get("location") or {}
    if hasattr(zone_loc, "latitude"):
        zone_lat, zone_lng = zone_loc.latitude, zone_loc.longitude
    else:
        zone_lat = zone_loc.get("lat")
        zone_lng = zone_loc.get("lng")
    if zone_lat is None or zone_lng is None:
        return

    zone_radius_m: float = float(after.get("radius_meters", 100))
    db = firestore.client()

    for s in (
        db.collection("group_stays")
        .where("status", "in", ["scheduled", "active"])
        .stream()
    ):
        data = s.to_dict() or {}
        loc = data.get("location") or {}
        if hasattr(loc, "latitude"):
            slat, slng = loc.latitude, loc.longitude
        else:
            slat = loc.get("lat", 0.0)
            slng = loc.get("lng", 0.0)

        if _haversine_km(zone_lat, zone_lng, slat, slng) * 1000 <= zone_radius_m:
            s.reference.update({
                "status": "cancelled",
                "cancellation_reason": "risk_zone_high",
                "updated_at": firestore.SERVER_TIMESTAMP,
            })
            _notify_stay_cancelled(
                db, s.id, data.get("vendor_uid"), reason="risk_zone_high"
            )


# ─── CU-09-C: Notificación de estancia grupal en radio ──────────────────────

_GROUP_STAY_NOTIFY_RADIUS_KM = 0.5


def _find_nearby_users(
    db,
    lat: float,
    lng: float,
    *,
    radius_km: float,
    exclude_uid: str | None,
    role_filter: str,
) -> list[str]:
    """Return FCM tokens for users matching role_filter within radius_km.

    Skips the user with UID == exclude_uid (e.g., the vendor who created the stay).
    Only returns tokens for users who have a registered FCM token and a recent
    last_location.
    """
    tokens: list[str] = []
    for user_doc in db.collection("users").stream():
        data = user_doc.to_dict() or {}
        if user_doc.id == exclude_uid:
            continue
        if data.get("role") != role_filter:
            continue
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
        if _fan_haversine_km(lat, lng, ulat, ulng) <= radius_km:
            tokens.append(token)
    return tokens


@firestore_fn.on_document_created(document="group_stays/{stay_id}")
def notify_group_stay_in_radius(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """Send rsvp_group_stay FCM to BUYERS within 500 m when a stay is created.

    Payload (all strings for FCM data messages):
      type, group_stay_id, vendor_uid, vendor_name (best-effort),
      start_at (ISO string from start_at_iso field), duration_minutes,
      location_lat, location_lng.
    """
    stay_id: str = event.params["stay_id"]
    snapshot = event.data
    if snapshot is None:
        return

    stay = snapshot.to_dict() or {}
    loc = stay.get("location", {})
    if hasattr(loc, "latitude"):
        lat, lng = loc.latitude, loc.longitude
    else:
        lat = loc.get("lat")
        lng = loc.get("lng")
    if lat is None or lng is None:
        return

    vendor_uid: str = stay.get("vendor_uid", "")
    db = firestore.client()

    tokens = _find_nearby_users(
        db,
        lat,
        lng,
        radius_km=_GROUP_STAY_NOTIFY_RADIUS_KM,
        exclude_uid=vendor_uid,
        role_filter="BUYER",
    )
    if not tokens:
        return

    payload: dict[str, str] = {
        "type": "rsvp_group_stay",
        "group_stay_id": stay_id,
        "vendor_uid": vendor_uid,
        "start_at": stay.get("start_at_iso", ""),
        "duration_minutes": str(stay.get("duration_minutes", 60)),
        "location_lat": str(lat),
        "location_lng": str(lng),
    }

    # Best-effort: add vendor name for a friendlier notification body
    vendor_doc = db.collection("users").document(vendor_uid).get()
    if vendor_doc.exists:
        vendor_data = vendor_doc.to_dict() or {}
        payload["vendor_name"] = vendor_data.get("name", "Un vendedor")

    _fan_send_multicast(tokens, data=payload)


# ─── CU-08-C: Notificación de proximidad a suscriptores ─────────────────────

_PROXIMITY_RADIUS_KM = 4.0


@firestore_fn.on_document_updated(document="users/{uid}")
def notify_vendor_proximity_to_subscribers(
    event: firestore_fn.Event[
        firestore_fn.Change[firestore_fn.DocumentSnapshot | None]
    ],
) -> None:
    """Notify buyers subscribed to a vendor when the vendor activates their radar.

    Fires only on the False/None → True transition of is_active_radar so that
    repeated document updates (location sync, token refresh, etc.) do not
    generate spurious notifications.
    """
    before_snap = event.data.before
    after_snap = event.data.after

    before = before_snap.to_dict() if before_snap and before_snap.exists else {}
    after = after_snap.to_dict() if after_snap and after_snap.exists else {}

    # Guard: only when is_active_radar transitions to True
    if after.get("is_active_radar") is not True:
        return
    if before.get("is_active_radar") is True:
        return  # was already True — no transition

    if after.get("role") != "VENDOR":
        return

    vendor_uid: str = event.params["uid"]
    vendor_loc = after.get("last_location") or {}
    vendor_lat = vendor_loc.get("lat")
    vendor_lng = vendor_loc.get("lng")
    if vendor_lat is None or vendor_lng is None:
        return

    db = firestore.client()

    # Collect FCM tokens of subscribed buyers within _PROXIMITY_RADIUS_KM
    tokens: list[str] = []
    subs = (
        db.collection("subscriptions")
        .where("vendor_uid", "==", vendor_uid)
        .where("active", "==", True)
        .stream()
    )
    for sub in subs:
        buyer_uid = (sub.to_dict() or {}).get("buyer_uid")
        if not buyer_uid:
            continue
        buyer_doc = db.collection("users").document(buyer_uid).get()
        if not buyer_doc.exists:
            continue
        buyer = buyer_doc.to_dict() or {}
        token = buyer.get("fcm_token")
        if not token:
            continue
        loc = buyer.get("last_location") or {}
        buyer_lat = loc.get("lat")
        buyer_lng = loc.get("lng")
        if buyer_lat is None or buyer_lng is None:
            continue
        if _fan_haversine_km(vendor_lat, vendor_lng, buyer_lat, buyer_lng) <= _PROXIMITY_RADIUS_KM:
            tokens.append(token)

    _fan_send_multicast(tokens, data={
        "type": "vendor_proximity_alert",
        "vendor_uid": vendor_uid,
        "vendor_lat": str(vendor_lat),
        "vendor_lng": str(vendor_lng),
    })
