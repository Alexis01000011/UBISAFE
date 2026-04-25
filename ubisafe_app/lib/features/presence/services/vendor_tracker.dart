import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vendor_marker.dart';

/// Listens to the Firestore `vendors` collection and emits
/// the list of currently active [VendorMarker] objects.
final vendorTrackerProvider = StreamProvider<List<VendorMarker>>((ref) {
  return FirebaseFirestore.instance
      .collection('vendors')
      .where('is_active', isEqualTo: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => VendorMarker.fromMap(doc.id, doc.data()))
            .toList(),
      );
});
