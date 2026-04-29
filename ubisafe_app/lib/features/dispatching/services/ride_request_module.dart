import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/ride.dart';

const _kRideTtlSeconds = 60;

class RideRequestModule {
  RideRequestModule(this._dio, this._firestore);

  final Dio _dio;
  final FirebaseFirestore _firestore;

  Timer? _expiryTimer;

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
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/rides/$rideId/status',
      data: {
        'status': status,
        if (rejectedReason != null) 'rejected_reason': rejectedReason,
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
    } catch (_) {}
  }

  /// Starts a 60-second timer that marks the ride as expired if not answered.
  void startExpiryTimer(String rideId, {required void Function() onExpired}) {
    cancelExpiryTimer();
    _expiryTimer = Timer(
      const Duration(seconds: _kRideTtlSeconds),
      () async {
        await expireRide(rideId);
        onExpired();
      },
    );
  }

  void cancelExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
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
