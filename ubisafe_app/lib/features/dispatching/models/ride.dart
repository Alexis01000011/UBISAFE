import 'package:cloud_firestore/cloud_firestore.dart';

enum RideStatus { pending, accepted, inprogress, completed, cancelled }

/// ☆ [iter.2] Modelo Ride — CU-04.
///
/// Fields: id, buyer_uid, vendor_uid, status, route, timestamps.
class Ride {
  const Ride({
    required this.id,
    required this.buyerUid,
    required this.vendorUid,
    required this.status,
    required this.destinationLat,
    required this.destinationLng,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.routePolyline,
  });

  final String id;
  final String buyerUid;
  final String vendorUid;
  final RideStatus status;
  final double destinationLat;
  final double destinationLng;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  /// Encoded polyline string of the agreed route.
  final String? routePolyline;

  factory Ride.fromMap(String id, Map<String, dynamic> map) {
    final GeoPoint dest = map['destination'] as GeoPoint;
    return Ride(
      id: id,
      buyerUid: map['buyer_uid'] as String,
      vendorUid: map['vendor_uid'] as String,
      status: RideStatus.values.byName(map['status'] as String),
      destinationLat: dest.latitude,
      destinationLng: dest.longitude,
      createdAt: (map['created_at'] as Timestamp).toDate(),
      acceptedAt: map['accepted_at'] != null
          ? (map['accepted_at'] as Timestamp).toDate()
          : null,
      completedAt: map['completed_at'] != null
          ? (map['completed_at'] as Timestamp).toDate()
          : null,
      routePolyline: map['route_polyline'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'buyer_uid': buyerUid,
        'vendor_uid': vendorUid,
        'status': status.name,
        'destination': GeoPoint(destinationLat, destinationLng),
        'created_at': FieldValue.serverTimestamp(),
        if (routePolyline != null) 'route_polyline': routePolyline,
      };
}
