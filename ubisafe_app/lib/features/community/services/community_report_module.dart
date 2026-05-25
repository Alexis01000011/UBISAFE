import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../presence/services/gps_service.dart';
import '../models/community_report.dart';

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = pow(sin(dLat / 2), 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * pow(sin(dLng / 2), 2);
  return r * 2 * asin(sqrt(a));
}

// Retry delays per SDD2_FASE4B §9.6.D: 2 s → 4 s → 8 s, max 3 attempts.
const _retryDelays = [
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8)
];

class CommunityReportModule {
  CommunityReportModule(this._dio);

  final Dio _dio;

  /// POST /community-reports — creates the report with retry backoff (CU-05 E1).
  /// Throws on permanent failure after [_retryDelays.length] attempts.
  Future<CommunityReport> createReport({
    required String threatType,
    required double lat,
    required double lng,
    String? description,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      try {
        final body = <String, dynamic>{
          'threat_type': threatType,
          'location': {'lat': lat, 'lng': lng},
        };
        if (description != null && description.isNotEmpty) {
          body['description'] = description;
        }
        final res = await _dio.post<Map<String, dynamic>>(
          '/community-reports',
          data: body,
        );
        return CommunityReport.fromJson(res.data!);
      } on DioException catch (e) {
        // Don't retry on business-logic errors (400, 401, 403, 409)
        final code = e.response?.statusCode;
        if (code != null && code < 500) rethrow;
        lastError = e;
      } catch (e) {
        lastError = e;
      }
      if (attempt < _retryDelays.length) {
        await Future<void>.delayed(_retryDelays[attempt]);
      }
    }
    throw lastError!;
  }

  /// POST /community-reports/{id}/support — adds current user as supporter.
  Future<CommunityReport> supportReport(String reportId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/community-reports/$reportId/support',
    );
    return CommunityReport.fromJson(res.data!);
  }

  /// PATCH /community-reports/{id}/resolve — marks lote_baldio as resolved.
  Future<CommunityReport> resolveLot(String reportId) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/community-reports/$reportId/resolve',
    );
    return CommunityReport.fromJson(res.data!);
  }

  /// GET /community-reports — fetches pending_validation + confirmed in bbox.
  Future<List<CommunityReport>> fetchReports({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/community-reports',
      queryParameters: {'lat': lat, 'lng': lng, 'radius_km': radiusKm},
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(CommunityReport.fromJson)
        .toList();
  }
}

final communityReportModuleProvider = Provider<CommunityReportModule>(
  (ref) => CommunityReportModule(ref.read(apiClientProvider)),
);

/// Real-time stream of active community reports within 5 km of the current GPS.
///
/// Subscribes directly to Firestore so any vote, confirmation, or dismissal is
/// reflected immediately on all devices without polling or manual refresh.
/// Mirror of [activeRiskZonesProvider] pattern.
///
/// GPS position is captured once at stream creation. Call
/// ref.invalidate(activeCommunityReportsProvider) to re-subscribe with an
/// updated position (done automatically by the map-screen GPS listeners when
/// the user moves >500 m, and by ActiveReportsScreen when GPS first becomes
/// available).
final activeCommunityReportsProvider =
    StreamProvider.autoDispose<List<CommunityReport>>((ref) {
  final pos = ref.read(gpsServiceProvider).valueOrNull;
  if (pos == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('community_reports')
      .where('status', whereIn: ['pending_validation', 'confirmed'])
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => CommunityReport.fromFirestore(d.id, d.data()))
          .where((r) =>
              _haversineKm(pos.latitude, pos.longitude, r.latitude, r.longitude) <=
              5.0)
          .toList());
});
