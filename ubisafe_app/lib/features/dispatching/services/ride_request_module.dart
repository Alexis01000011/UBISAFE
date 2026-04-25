import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ride.dart';

/// ☆ [iter.2] CU-04 — Full ride-request lifecycle.
///
/// Handles creating, accepting, completing and cancelling rides.
class RideRequestModule {
  RideRequestModule(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('rides');

  /// Buyer requests a ride to [destinationLat]/[destinationLng].
  Future<String> requestRide({
    required String buyerUid,
    required String vendorUid,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final ride = Ride(
      id: '',
      buyerUid: buyerUid,
      vendorUid: vendorUid,
      status: RideStatus.pending,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      createdAt: DateTime.now(),
    );
    final doc = await _col.add(ride.toMap());
    return doc.id;
  }

  /// Vendor accepts an incoming ride.
  Future<void> acceptRide(String rideId) =>
      _col.doc(rideId).update({'status': RideStatus.accepted.name});

  /// Marks a ride as completed.
  Future<void> completeRide(String rideId) => _col.doc(rideId).update({
        'status': RideStatus.completed.name,
        'completed_at': FieldValue.serverTimestamp(),
      });

  /// Either party can cancel a pending/accepted ride.
  Future<void> cancelRide(String rideId) =>
      _col.doc(rideId).update({'status': RideStatus.cancelled.name});

  /// Watch a single ride in real time.
  Stream<Ride?> watchRide(String rideId) => _col
      .doc(rideId)
      .snapshots()
      .map((s) => s.exists ? Ride.fromMap(s.id, s.data()!) : null);
}

final rideRequestModuleProvider = Provider<RideRequestModule>((ref) {
  return RideRequestModule(FirebaseFirestore.instance);
});
