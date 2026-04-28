import 'package:cloud_firestore/cloud_firestore.dart';

enum StopRequestStatus { pending, accepted, rejected, completed, expired }

class StopRequest {
  const StopRequest({
    required this.id,
    required this.buyerUid,
    this.vendorUid,
    required this.status,
    required this.buyerLat,
    required this.buyerLng,
    required this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String buyerUid;
  final String? vendorUid;
  final StopRequestStatus status;
  final double buyerLat;
  final double buyerLng;
  final DateTime createdAt;
  final DateTime? expiresAt;

  factory StopRequest.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['buyer_location'];
    double lat;
    double lng;
    if (raw is GeoPoint) {
      lat = raw.latitude;
      lng = raw.longitude;
    } else if (raw is Map) {
      lat = (raw['lat'] as num).toDouble();
      lng = (raw['lng'] as num).toDouble();
    } else {
      lat = 0;
      lng = 0;
    }
    return StopRequest(
      id: id,
      buyerUid: map['buyer_uid'] as String,
      vendorUid: map['vendor_uid'] as String?,
      status: StopRequestStatus.values.byName(map['status'] as String),
      buyerLat: lat,
      buyerLng: lng,
      createdAt: map['created_at'] is Timestamp
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: map['expires_at'] is Timestamp
          ? (map['expires_at'] as Timestamp).toDate()
          : map['expires_at'] != null
              ? DateTime.tryParse(map['expires_at'] as String)
              : null,
    );
  }

  factory StopRequest.fromJson(Map<String, dynamic> json) {
    final loc = json['buyer_location'] as Map<String, dynamic>;
    return StopRequest(
      id: json['id'] as String,
      buyerUid: json['buyer_uid'] as String,
      vendorUid: json['vendor_uid'] as String?,
      status: StopRequestStatus.values.byName(json['status'] as String),
      buyerLat: (loc['lat'] as num).toDouble(),
      buyerLng: (loc['lng'] as num).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'buyer_uid': buyerUid,
        if (vendorUid != null) 'vendor_uid': vendorUid,
        'status': status.name,
        'buyer_location': GeoPoint(buyerLat, buyerLng),
        'created_at': FieldValue.serverTimestamp(),
      };
}
