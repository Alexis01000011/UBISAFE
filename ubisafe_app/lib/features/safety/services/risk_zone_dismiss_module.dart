import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/risk_zone.dart';

/// CU-03 — Dismiss service: calls POST /risk-zones/{id}/dismiss.
/// Rules enforced by the API: no self-dismiss, no double-vote, zone must be active.
class RiskZoneDismissModule {
  RiskZoneDismissModule(this._dio);

  final Dio _dio;

  /// Registers a dismiss vote for [zoneId].
  /// Returns the updated [RiskZone] on success.
  /// Throws [DioException] on:
  ///   403 — reporter cannot dismiss their own zone
  ///   404 — zone not found
  ///   409 — already voted or zone already inactive
  Future<RiskZone> dismiss(String zoneId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/risk-zones/$zoneId/dismiss',
    );
    return RiskZone.fromJson(res.data!);
  }
}

final riskZoneDismissModuleProvider = Provider<RiskZoneDismissModule>(
  (ref) => RiskZoneDismissModule(ref.read(apiClientProvider)),
);
