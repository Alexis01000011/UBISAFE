import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presence/services/gps_service.dart';
import '../models/risk_zone.dart';

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = pow(sin(dLat / 2), 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * pow(sin(dLng / 2), 2);
  return r * 2 * asin(sqrt(a));
}

/// Real-time stream de zonas de riesgo activas dentro de 5 km de la posición GPS.
///
/// Se suscribe directamente a Firestore, por lo que cualquier cambio —
/// expiración automática vía Cloud Function, eliminación manual en la consola
/// de Firebase o expiración por API (DELETE /risk-zones/{id}) — se refleja
/// en el mapa de forma inmediata sin polling ni FCM.
///
/// Cuando la app está en background, el FCM `risk_zone_expired` dispara
/// ref.invalidate() que cancela y re-suscribe el stream al volver al primer plano.
final activeRiskZonesProvider =
    StreamProvider.autoDispose<List<RiskZone>>((ref) {
  final pos = ref.read(gpsServiceProvider).valueOrNull;
  if (pos == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('risk_zones')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => RiskZone.fromFirestore(d.id, d.data()))
          .where((z) =>
              _haversineKm(pos.latitude, pos.longitude, z.latitude, z.longitude) <=
              5.0)
          .toList());
});
