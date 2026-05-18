import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/risk_zone.dart';

class RiskReportModule {
  RiskReportModule(this._dio);

  final Dio _dio;

  Future<RiskZone> createRiskZone({
    required String threatType,
    required String riskLevel,
    required double lat,
    required double lng,
    int radiusMeters = 100,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/risk-zones',
      data: {
        'threat_type': threatType,
        'risk_level': riskLevel,
        'location': {'lat': lat, 'lng': lng},
        'radius_meters': radiusMeters,
      },
    );
    return RiskZone.fromJson(res.data!);
  }

  Future<List<RiskZone>> getActiveZones({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/risk-zones',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
      },
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(RiskZone.fromJson)
        .toList();
  }
}

final riskReportModuleProvider = Provider<RiskReportModule>(
  (ref) => RiskReportModule(ref.read(apiClientProvider)),
);

/// Holds the latest list of active risk zones for the current map view.
/// Invalidated when a risk_zone_alert FCM arrives or after a successful POST.
final activeRiskZonesProvider =
    StateNotifierProvider<_RiskZonesNotifier, AsyncValue<List<RiskZone>>>(
  (ref) => _RiskZonesNotifier(ref.read(riskReportModuleProvider)),
);

class _RiskZonesNotifier extends StateNotifier<AsyncValue<List<RiskZone>>> {
  _RiskZonesNotifier(this._module) : super(const AsyncValue.loading());

  final RiskReportModule _module;
  double? _lat;
  double? _lng;

  Future<void> load({required double lat, required double lng}) async {
    _lat = lat;
    _lng = lng;
    state = const AsyncValue.loading();
    try {
      final zones = await _module.getActiveZones(lat: lat, lng: lng);
      state = AsyncValue.data(zones);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    if (_lat != null && _lng != null) {
      await load(lat: _lat!, lng: _lng!);
    }
  }
}
