import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../safety/models/risk_zone.dart';

// ─── Zone-on-route detection ──────────────────────────────────────────────────

class RouteZones {
  const RouteZones({required this.mediumZones, required this.lowCount});
  final List<RiskZone> mediumZones;
  final int lowCount;
}

/// Returns MEDIUM/LOW zones whose circles intersect the origin→dest segment.
/// Uses the same metric-space projection as [buildAvoidWaypoints].
RouteZones zonesOnRoute({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  required List<RiskZone> zones,
}) {
  final midLat = (originLat + destLat) / 2;
  final cosLat = math.cos(midLat * math.pi / 180);
  const metersPerDegLat = 111000.0;
  final metersPerDegLng = metersPerDegLat * cosLat;

  final dLatM = (destLat - originLat) * metersPerDegLat;
  final dLngM = (destLng - originLng) * metersPerDegLng;
  final length = math.sqrt(dLatM * dLatM + dLngM * dLngM);
  if (length == 0) return const RouteZones(mediumZones: [], lowCount: 0);

  final mediumZones = <RiskZone>[];
  int lowCount = 0;

  for (final z in zones) {
    if (z.riskLevel == 'HIGH') continue;
    final zLatM = (z.latitude - originLat) * metersPerDegLat;
    final zLngM = (z.longitude - originLng) * metersPerDegLng;
    final t =
        ((zLatM * dLatM + zLngM * dLngM) / (length * length)).clamp(0.0, 1.0);
    final distM = math.sqrt(
      math.pow(zLatM - dLatM * t, 2) + math.pow(zLngM - dLngM * t, 2),
    );
    if (distM > z.radiusMeters) continue;
    if (z.riskLevel == 'MEDIUM') {
      mediumZones.add(z);
    } else {
      lowCount++;
    }
  }
  return RouteZones(mediumZones: mediumZones, lowCount: lowCount);
}

/// Returns LOW/MEDIUM zones whose circle contains the given point.
/// A zone "contains" a point when the Haversine distance from the zone centre
/// to the point is ≤ radiusMeters. HIGH zones are skipped — they are handled
/// exclusively via [buildAvoidWaypoints].
RouteZones zonesAtPoint({
  required double lat,
  required double lng,
  required List<RiskZone> zones,
}) {
  final mediumZones = <RiskZone>[];
  int lowCount = 0;
  for (final z in zones) {
    if (z.riskLevel == 'HIGH') continue;
    if (distanceMeters(lat, lng, z.latitude, z.longitude) > z.radiusMeters) {
      continue;
    }
    if (z.riskLevel == 'MEDIUM') {
      mediumZones.add(z);
    } else {
      lowCount++;
    }
  }
  return RouteZones(mediumZones: mediumZones, lowCount: lowCount);
}

// ─── Waypoint builder (HIGH zone avoidance) ───────────────────────────────────

List<String> buildAvoidWaypoints({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  required List<RiskZone> highZones,
}) {
  if (highZones.isEmpty) return const [];

  final midLat = (originLat + destLat) / 2;
  final cosLat = math.cos(midLat * math.pi / 180);
  const metersPerDegLat = 111000.0;
  final metersPerDegLng = metersPerDegLat * cosLat;

  final dLatM = (destLat - originLat) * metersPerDegLat;
  final dLngM = (destLng - originLng) * metersPerDegLng;
  final length = math.sqrt(dLatM * dLatM + dLngM * dLngM);
  if (length == 0) return const [];

  final perpLatM = -dLngM / length;
  final perpLngM = dLatM / length;

  final waypoints = <String>[];
  for (final z in highZones) {
    final zLatM = (z.latitude - originLat) * metersPerDegLat;
    final zLngM = (z.longitude - originLng) * metersPerDegLng;
    final t = ((zLatM * dLatM + zLngM * dLngM) / (length * length))
        .clamp(0.0, 1.0);
    final closestLatM = dLatM * t;
    final closestLngM = dLngM * t;
    final distM = math.sqrt(
      math.pow(zLatM - closestLatM, 2) + math.pow(zLngM - closestLngM, 2),
    );
    if (distM > z.radiusMeters) continue;
    final cross = dLatM * zLngM - dLngM * zLatM;
    final side = cross >= 0 ? 1.0 : -1.0;
    final offsetMeters = (z.radiusMeters + 50).toDouble();
    final wpLat = z.latitude + perpLatM * offsetMeters * side / metersPerDegLat;
    final wpLng = z.longitude + perpLngM * offsetMeters * side / metersPerDegLng;
    waypoints.add('$wpLat,$wpLng');
  }
  return waypoints;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Haversine distance in meters between two WGS-84 coordinates.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLam = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLam / 2) * math.sin(dLam / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Decodes a Google Maps encoded polyline string to a list of LatLng points.
List<LatLng> decodePolyline(String encoded) {
  final result = <LatLng>[];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int shift = 0;
    int result0 = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result0 |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);

    shift = 0;
    result0 = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result0 |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);

    result.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return result;
}
