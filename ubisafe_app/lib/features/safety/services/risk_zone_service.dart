import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../presence/services/gps_service.dart';
import '../models/risk_zone.dart';

/// Incremented when an FCM risk_zone_alert is received to trigger provider refresh.
final riskZoneRefreshProvider = StateProvider<int>((ref) => 0);

/// Fetches active risk zones within 5 km of the device's current GPS position.
/// Only re-executes on explicit events: FCM push (riskZoneRefreshProvider) or
/// ref.invalidate. GPS position changes do NOT trigger refetches.
final activeRiskZonesProvider =
    FutureProvider.autoDispose<List<RiskZone>>((ref) async {
  ref.watch(riskZoneRefreshProvider);
  final pos = ref.read(gpsServiceProvider).valueOrNull;
  if (pos == null) return [];
  final dio = ref.read(apiClientProvider);
  final response = await dio.get<dynamic>(
    '/risk-zones',
    queryParameters: {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'radius_km': 5,
    },
  );
  final data = response.data as List<dynamic>;
  return data
      .map((e) => RiskZone.fromJson(e as Map<String, dynamic>))
      .toList();
});
