import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/stop_request.dart';

class StopRequestModule {
  StopRequestModule(this._dio, this._firestore);

  final Dio _dio;
  final FirebaseFirestore _firestore;
  Timer? _timeoutTimer;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('stop_requests');

  Future<StopRequest> createStopRequest({
    required String vendorUid,
    required double buyerLat,
    required double buyerLng,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/stops',
      data: {
        'vendor_uid': vendorUid,
        'buyer_location': {'lat': buyerLat, 'lng': buyerLng},
      },
    );
    final req = StopRequest.fromJson(res.data!);
    _startTimer(req.id);
    return req;
  }

  void _startTimer(String stopId) {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 60), () async {
      try {
        await expireStopRequest(stopId);
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) return;
      }
    });
  }

  void cancelTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  Future<void> expireStopRequest(String stopId) =>
      _dio.patch('/stops/$stopId/status', data: {'status': 'expired'});

  Future<void> rejectStopRequest(String stopId) =>
      _dio.patch('/stops/$stopId/status', data: {'status': 'rejected'});

  Future<void> acceptStopRequest(String stopId) =>
      _dio.patch('/stops/$stopId/status', data: {'status': 'accepted'});

  Future<void> completeStopRequest(String stopId) =>
      _dio.patch('/stops/$stopId/status', data: {'status': 'completed'});

  Stream<StopRequest?> watchStopRequest(String stopId) => _col
      .doc(stopId)
      .snapshots()
      .map((s) => s.exists ? StopRequest.fromMap(s.id, s.data()!) : null);
}

class ActiveStopNotifier extends StateNotifier<StopRequest?> {
  ActiveStopNotifier() : super(null);

  void set(StopRequest req) => state = req;
  void clear() => state = null;
}

final activeStopProvider =
    StateNotifierProvider<ActiveStopNotifier, StopRequest?>(
  (ref) => ActiveStopNotifier(),
);

final stopRequestModuleProvider = Provider<StopRequestModule>((ref) {
  return StopRequestModule(
    ref.read(apiClientProvider),
    FirebaseFirestore.instance,
  );
});
