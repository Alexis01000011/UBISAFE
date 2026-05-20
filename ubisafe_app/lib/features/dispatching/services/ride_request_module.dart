import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/ride.dart';

const _kRideTtlSeconds = 60;

class RideRequestModule {
  RideRequestModule(this._dio, this._firestore);

  final Dio _dio;
  final FirebaseFirestore _firestore;

  final _expiryTimers = <String, Timer>{};

  Future<Ride> createRide({
    required String vendorUid,
    required double pickupLat,
    required double pickupLng,
    required double destinationLat,
    required double destinationLng,
    String? routePolyline,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/rides',
      data: {
        'vendor_uid': vendorUid,
        'pickup_location': {'lat': pickupLat, 'lng': pickupLng},
        'destination': {'lat': destinationLat, 'lng': destinationLng},
        if (routePolyline != null) 'route_polyline': routePolyline,
      },
    );
    return Ride.fromJson(res.data!);
  }

  Future<Ride> updateStatus(
    String rideId,
    String status, {
    String? rejectedReason,
    List<String> routeWarnings = const [],
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/rides/$rideId/status',
      data: {
        'status': status,
        if (rejectedReason != null) 'rejected_reason': rejectedReason,
        if (routeWarnings.isNotEmpty) 'route_warnings': routeWarnings,
      },
    );
    return Ride.fromJson(res.data!);
  }

  Future<void> vendorArrived(String rideId) async {
    await _dio.post<void>('/rides/$rideId/vendor_arrived');
  }

  Future<void> expireRide(String rideId) async {
    try {
      await updateStatus(rideId, 'expired');
    } on DioException catch (e) {
      // 409 = already processed concurrently; swallow silently.
      if (e.response?.statusCode == 409) return;
      rethrow;
    }
  }

  /// Starts a 60-second timer that marks the ride as expired if not answered.
  /// Each rideId gets its own timer; a second call for the same id replaces
  /// the previous timer (same semantics as StopRequestModule._startTimer).
  /// [onExpired] is always called — even if the network request fails — so
  /// the buyer UI never stays stuck in a pending state after the TTL elapses.
  void startExpiryTimer(String rideId, {required void Function() onExpired}) {
    _expiryTimers[rideId]?.cancel();
    _expiryTimers[rideId] = Timer(
      const Duration(seconds: _kRideTtlSeconds),
      () async {
        _expiryTimers.remove(rideId);
        try {
          await expireRide(rideId);
        } on DioException catch (e) {
          // 409 = already processed concurrently — expected, swallow silently.
          // Any other error is unexpected; log it but still notify the UI.
          if (e.response?.statusCode != 409) {
            if (kDebugMode) debugPrint('RideRequestModule: expiry failed — $e');
          }
        }
        onExpired();
      },
    );
  }

  Future<void> abandonRide(String rideId) =>
      updateStatus(rideId, 'abandoned').then((_) {}).catchError((_) {});

  void cancelExpiryTimer() {
    for (final t in _expiryTimers.values) { t.cancel(); }
    _expiryTimers.clear();
  }

  Stream<Ride?> watchRide(String rideId) => _firestore
      .collection('rides')
      .doc(rideId)
      .snapshots()
      .map((s) => s.exists ? Ride.fromMap(s.id, s.data()!) : null);
}

final rideRequestModuleProvider = Provider<RideRequestModule>((ref) {
  return RideRequestModule(
    ref.read(apiClientProvider),
    FirebaseFirestore.instance,
  );
});
