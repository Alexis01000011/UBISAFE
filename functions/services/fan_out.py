"""Shared fan-out helpers for Cloud Functions (iter. 3).

These utilities are used by notify_vendor_proximity_to_subscribers and
future CFs that need to multicast FCM to nearby users. They coexist with
the older _haversine_km / _get_nearby_fcm_tokens helpers in main.py
without modifying them.
"""
from __future__ import annotations

import math

from firebase_admin import messaging


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
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


def send_multicast(tokens: list[str], data: dict[str, str]) -> None:
    """Send a data-only FCM multicast. Silently ignores send errors."""
    if not tokens:
        return
    messaging.send_each_for_multicast(
        messaging.MulticastMessage(
            tokens=tokens,
            data=data,
            android=messaging.AndroidConfig(priority="high"),
        )
    )
