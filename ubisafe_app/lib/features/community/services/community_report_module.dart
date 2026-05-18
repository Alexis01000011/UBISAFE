import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/community_report.dart';

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
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      try {
        final res = await _dio.post<Map<String, dynamic>>(
          '/community-reports',
          data: {
            'threat_type': threatType,
            'location': {'lat': lat, 'lng': lng},
          },
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

/// Holds the latest list of active community reports for the current map view.
/// Refreshed by FCM community_report_nearby and after successful POST.
final activeCommunityReportsProvider = StateNotifierProvider<
    _CommunityReportsNotifier, AsyncValue<List<CommunityReport>>>(
  (ref) => _CommunityReportsNotifier(ref.read(communityReportModuleProvider)),
);

class _CommunityReportsNotifier
    extends StateNotifier<AsyncValue<List<CommunityReport>>> {
  _CommunityReportsNotifier(this._module) : super(const AsyncValue.loading());

  final CommunityReportModule _module;
  double? _lat;
  double? _lng;

  /// True if [load] has been called at least once (from a map screen or the
  /// ActiveReportsScreen itself). Used to detect the "never loaded" state.
  bool get hasCoordinates => _lat != null && _lng != null;

  Future<void> load({required double lat, required double lng}) async {
    _lat = lat;
    _lng = lng;
    // B27 — Only show the loading spinner on the first fetch. On subsequent
    // refreshes, keep the existing data visible while the request is in flight
    // so map markers don't flicker off for 2-5 s on every FCM refresh.
    if (state is! AsyncData<List<CommunityReport>>) {
      state = const AsyncValue.loading();
    }
    try {
      final reports = await _module.fetchReports(lat: lat, lng: lng);
      state = AsyncValue.data(reports);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    if (_lat != null && _lng != null) {
      await load(lat: _lat!, lng: _lng!);
    }
  }

  /// Called by [ActiveReportsScreen] when GPS is not available and load was
  /// never triggered. Replaces the eternal loading spinner with an error state.
  void setGpsUnavailable() {
    state = AsyncValue.error('gps_unavailable', StackTrace.current);
  }
}
