import 'package:cloud_firestore/cloud_firestore.dart';

enum StopRequestStatus { pending, accepted, arrived, completed, cancelled }

/// Represents a buyer's request for a vendor to stop at their location.
class StopRequest {
  const StopRequest({
    required this.id,
    required this.buyerUid,
    required this.vendorUid,
    required this.status,
    required this.buyerLat,
    required this.buyerLng,
    required this.createdAt,
  });

  final String id;
  final String buyerUid;
  final String vendorUid;
  final StopRequestStatus status;
  final double buyerLat;
  final double buyerLng;
  final DateTime createdAt;

  factory StopRequest.fromMap(String id, Map<String, dynamic> map) {
    final GeoPoint geoPoint = map['buyer_location'] as GeoPoint;
    return StopRequest(
      id: id,
      buyerUid: map['buyer_uid'] as String,
      vendorUid: map['vendor_uid'] as String,
      status: StopRequestStatus.values.byName(map['status'] as String),
      buyerLat: geoPoint.latitude,
      buyerLng: geoPoint.longitude,
      createdAt: (map['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'buyer_uid': buyerUid,
        'vendor_uid': vendorUid,
        'status': status.name,
        'buyer_location': GeoPoint(buyerLat, buyerLng),
        'created_at': FieldValue.serverTimestamp(),
      };
}
