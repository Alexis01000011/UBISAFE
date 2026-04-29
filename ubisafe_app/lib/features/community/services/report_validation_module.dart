import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/community_report.dart';

/// CU-06 — Validation service: calls PATCH /community-reports/{id}/validations.
/// Rules enforced by the API: no self-vote, no double-vote, only pending_validation.
class ReportValidationModule {
  ReportValidationModule(this._dio);

  final Dio _dio;

  /// Cast a [vote] ("confirm" or "dismiss") on [reportId].
  /// Returns the updated [CommunityReport] on success.
  /// Throws [DioException] on 403 (self-vote), 409 (already voted / wrong status).
  Future<CommunityReport> vote({
    required String reportId,
    required String vote,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/community-reports/$reportId/validations',
      data: {'vote': vote},
    );
    return CommunityReport.fromJson(res.data!);
  }
}

final reportValidationModuleProvider = Provider<ReportValidationModule>(
  (ref) => ReportValidationModule(ref.read(apiClientProvider)),
);
