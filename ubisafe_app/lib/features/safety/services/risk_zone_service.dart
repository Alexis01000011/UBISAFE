import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/api/api_client.dart';
import '../models/risk_zone.dart';

/// Incremented when an FCM risk_zone_alert is received to trigger provider refresh.
final riskZoneRefreshProvider = StateProvider<int>((ref) => 0);

/// Fetches active risk zones around [center] within a 5 km radius.
/// Re-executes when [riskZoneRefreshProvider] changes (FCM push).
final activeRiskZonesProvider =
    FutureProvider.autoDispose.family<List<RiskZone>, LatLng>(
  (ref, center) async {
    ref.watch(riskZoneRefreshProvider);
    final dio = ref.read(apiClientProvider);
    final response = await dio.get<dynamic>(
      '/risk-zones',
      queryParameters: {
        'lat': center.latitude,
        'lng': center.longitude,
        'radius_km': 5,
      },
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => RiskZone.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);
