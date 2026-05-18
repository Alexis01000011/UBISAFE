"""Cloud Functions gen2 — UBISAFE iter. 2.

aggregateDuplicateReports: Firestore onCreate trigger on community_reports/{id}.
Detects spatial duplicates within 100 m of the same threat_type and marks
the new report with is_duplicate=True + canonical_report_id.
"""
from __future__ import annotations

import firebase_admin
from firebase_admin import firestore
from firebase_functions import firestore_fn, options

from services.duplicate_detector import find_canonical

firebase_admin.initialize_app()

options.set_global_options(region="us-central1")


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
