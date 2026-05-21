import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../models/group_stay.dart';

class GroupStayModule {
  GroupStayModule(this._dio);

  final Dio _dio;

  /// POST /group-stays — schedules a new group stay.
  Future<CreateGroupStayResponse> createStay({
    required double lat,
    required double lng,
    required DateTime startAt,
    required int durationMinutes,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/group-stays',
      data: {
        'location': {'lat': lat, 'lng': lng},
        'start_at': startAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
      },
    );
    return CreateGroupStayResponse.fromJson(res.data!);
  }

  /// PATCH /group-stays/{id}/cancel — cancels a stay (vendor only, Sesión 7).
  Future<GroupStay> cancelStay(String stayId) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/group-stays/$stayId/cancel',
    );
    return GroupStay.fromJson(res.data!);
  }

  /// POST /group-stays/{id}/attendances — confirms attendance (buyer, Sesión 7).
  Future<void> confirmAttendance(String stayId) async {
    await _dio.post<void>('/group-stays/$stayId/attendances');
  }

  /// GET /group-stays/{id} — fetches a single stay (Sesión 7).
  Future<GroupStay> getStay(String stayId) async {
    final res = await _dio.get<Map<String, dynamic>>('/group-stays/$stayId');
    return GroupStay.fromJson(res.data!);
  }

  /// GET /group-stays — fetches active stays in bounding box (Sesión 7).
  Future<List<GroupStay>> fetchActive({
    required double lat,
    required double lng,
    double radiusKm = 1.0,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/group-stays',
      queryParameters: {'lat': lat, 'lng': lng, 'radius_km': radiusKm},
    );
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(GroupStay.fromJson)
        .toList();
  }
}

final groupStayModuleProvider = Provider<GroupStayModule>(
  (ref) => GroupStayModule(ref.read(apiClientProvider)),
);

/// Holds the latest active group stays for the current map view.
/// Call [load] once per map build to fetch from the backend.
final activeGroupStaysProvider = StateNotifierProvider<
    _GroupStaysNotifier, AsyncValue<List<GroupStay>>>(
  (ref) => _GroupStaysNotifier(ref.read(groupStayModuleProvider)),
);

class _GroupStaysNotifier extends StateNotifier<AsyncValue<List<GroupStay>>> {
  _GroupStaysNotifier(this._module) : super(const AsyncValue.data([]));

  final GroupStayModule _module;

  Future<void> load(double lat, double lng) async {
    if (state is! AsyncData<List<GroupStay>>) {
      state = const AsyncValue.loading();
    }
    try {
      final stays = await _module.fetchActive(lat: lat, lng: lng);
      state = AsyncValue.data(stays);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
