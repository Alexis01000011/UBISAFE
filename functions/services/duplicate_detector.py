from __future__ import annotations

import math

_EARTH_RADIUS_KM = 6371.0
_DUPLICATE_RADIUS_M = 100.0


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Return great-circle distance in metres between two points."""
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlng / 2) ** 2
    )
    return _EARTH_RADIUS_KM * 2 * math.asin(math.sqrt(a)) * 1000


def find_canonical(
    db,
    new_id: str,
    threat_type: str,
    new_lat: float,
    new_lng: float,
) -> str | None:
    """Return the ID of an existing canonical report within 100 m, or None.

    Queries active (pending_validation or confirmed), non-duplicate reports of
    the same threat_type and applies a Haversine post-filter at 100 m.
    """
    candidates = (
        db.collection("community_reports")
        .where("threat_type", "==", threat_type)
        .where("status", "in", ["pending_validation", "confirmed"])
        .where("is_duplicate", "==", False)
        .stream()
    )

    for doc in candidates:
        if doc.id == new_id:
            continue
        data = doc.to_dict() or {}
        loc = data.get("location")
        if loc is None:
            continue
        if hasattr(loc, "latitude"):
            c_lat, c_lng = loc.latitude, loc.longitude
        else:
            c_lat = loc.get("lat", 0.0)
            c_lng = loc.get("lng", 0.0)

        if haversine_m(new_lat, new_lng, c_lat, c_lng) <= _DUPLICATE_RADIUS_M:
            return doc.id

    return None
