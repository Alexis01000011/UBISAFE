import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stop_request.dart';

/// Handles creating and cancelling stop requests.
class StopRequestModule {
  StopRequestModule(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('stop_requests');

  /// Creates a new [StopRequest] and returns its Firestore document ID.
  Future<String> create(StopRequest request) async {
    final doc = await _col.add(request.toMap());
    return doc.id;
  }

  /// Cancels a pending stop request.
  Future<void> cancel(String requestId) =>
      _col.doc(requestId).update({'status': StopRequestStatus.cancelled.name});

  /// Stream of a single stop request.
  Stream<StopRequest?> watch(String requestId) => _col
      .doc(requestId)
      .snapshots()
      .map((s) => s.exists ? StopRequest.fromMap(s.id, s.data()!) : null);
}

final stopRequestModuleProvider = Provider<StopRequestModule>((ref) {
  return StopRequestModule(FirebaseFirestore.instance);
});
