import 'package:cloud_firestore/cloud_firestore.dart';

enum RideStatus {
  pending,
  accepted,
  inProgress,
  completed,
  rejected,
  expired,
  cancelled,
  abandoned,
}

RideStatus _statusFromString(String s) {
  switch (s) {
    case 'pending':
      return RideStatus.pending;
    case 'accepted':
      return RideStatus.accepted;
    case 'in_progress':
      return RideStatus.inProgress;
    case 'completed':
      return RideStatus.completed;
    case 'rejected':
      return RideStatus.rejected;
    case 'expired':
      return RideStatus.expired;
    case 'cancelled':
      return RideStatus.cancelled;
    case 'abandoned':
      return RideStatus.abandoned;
    default:
      return RideStatus.pending;
  }
}

String _statusToString(RideStatus s) {
  switch (s) {
    case RideStatus.pending:
      return 'pending';
    case RideStatus.accepted:
      return 'accepted';
    case RideStatus.inProgress:
      return 'in_progress';
    case RideStatus.completed:
      return 'completed';
    case RideStatus.rejected:
      return 'rejected';
    case RideStatus.expired:
      return 'expired';
    case RideStatus.cancelled:
      return 'cancelled';
    case RideStatus.abandoned:
      return 'abandoned';
  }
}

DateTime? _parseTimestamp(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is String) return DateTime.tryParse(val);
  return null;
}

class Ride {
  const Ride({
    required this.id,
    required this.buyerUid,
    required this.vendorUid,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.status,
    this.routePolyline,
    this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.expiresAt,
    this.rejectedReason,
  });

  final String id;
  final String buyerUid;
  final String vendorUid;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;
  final RideStatus status;
  final String? routePolyline;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final String? rejectedReason;

  factory Ride.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup_location'] as Map<String, dynamic>;
    final dest = json['destination'] as Map<String, dynamic>;
    return Ride(
      id: json['id'] as String,
      buyerUid: json['buyer_uid'] as String,
      vendorUid: json['vendor_uid'] as String,
      pickupLat: (pickup['lat'] as num).toDouble(),
      pickupLng: (pickup['lng'] as num).toDouble(),
      destinationLat: (dest['lat'] as num).toDouble(),
      destinationLng: (dest['lng'] as num).toDouble(),
      status: _statusFromString(json['status'] as String),
      routePolyline: json['route_polyline'] as String?,
      createdAt: _parseTimestamp(json['created_at']),
      updatedAt: _parseTimestamp(json['updated_at']),
      acceptedAt: _parseTimestamp(json['accepted_at']),
      startedAt: _parseTimestamp(json['started_at']),
      completedAt: _parseTimestamp(json['completed_at']),
      expiresAt: _parseTimestamp(json['expires_at']),
      rejectedReason: json['rejected_reason'] as String?,
    );
  }

  factory Ride.fromMap(String id, Map<String, dynamic> map) {
    double geo(dynamic field, String key) {
      if (field is GeoPoint) {
        return key == 'lat' ? field.latitude : field.longitude;
      }
      final m = field as Map<dynamic, dynamic>;
      return (m[key] as num).toDouble();
    }

    final pickup = map['pickup_location'];
    final dest = map['destination'];
    return Ride(
      id: id,
      buyerUid: map['buyer_uid'] as String,
      vendorUid: map['vendor_uid'] as String,
      pickupLat: geo(pickup, 'lat'),
      pickupLng: geo(pickup, 'lng'),
      destinationLat: geo(dest, 'lat'),
      destinationLng: geo(dest, 'lng'),
      status: _statusFromString(map['status'] as String),
      routePolyline: map['route_polyline'] as String?,
      createdAt: _parseTimestamp(map['created_at']),
      updatedAt: _parseTimestamp(map['updated_at']),
      acceptedAt: _parseTimestamp(map['accepted_at']),
      startedAt: _parseTimestamp(map['started_at']),
      completedAt: _parseTimestamp(map['completed_at']),
      expiresAt: _parseTimestamp(map['expires_at']),
      rejectedReason: map['rejected_reason'] as String?,
    );
  }

  String get statusString => _statusToString(status);
}
