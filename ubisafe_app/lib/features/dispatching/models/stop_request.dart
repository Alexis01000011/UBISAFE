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
    this.updatedAt,
    this.expiresAt,
    this.acceptedAt,
    this.completedAt,
  });

  final String id;
  final String buyerUid;
  final String? vendorUid;
  final StopRequestStatus status;
  final double buyerLat;
  final double buyerLng;
  final DateTime createdAt;
  final DateTime? updatedAt;    // Última modificación del documento
  final DateTime? expiresAt;    // created_at + 60s — límite de respuesta del vendedor
  final DateTime? acceptedAt;   // Momento en que el vendedor aceptó (pending→accepted)
  final DateTime? completedAt;  // Momento en que el vendedor completó (accepted→completed)

  // ─── Helpers de parsing ────────────────────────────────────────────────────

  static DateTime? _tsToDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ─── Firestore deserialization ─────────────────────────────────────────────

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
      createdAt: _tsToDate(map['created_at']) ?? DateTime.now(),
      updatedAt: _tsToDate(map['updated_at']),
      expiresAt: _tsToDate(map['expires_at']),
      acceptedAt: _tsToDate(map['accepted_at']),
      completedAt: _tsToDate(map['completed_at']),
    );
  }

  // ─── REST/JSON deserialization (respuesta FastAPI) ─────────────────────────

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
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  // ─── Firestore serialization ───────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'buyer_uid': buyerUid,
        if (vendorUid != null) 'vendor_uid': vendorUid,
        'status': status.name,
        'buyer_location': GeoPoint(buyerLat, buyerLng),
        'created_at': FieldValue.serverTimestamp(),
      };

  // ─── Immutable update ──────────────────────────────────────────────────────

  StopRequest copyWith({
    String? id,
    String? buyerUid,
    String? vendorUid,
    StopRequestStatus? status,
    double? buyerLat,
    double? buyerLng,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
  }) {
    return StopRequest(
      id: id ?? this.id,
      buyerUid: buyerUid ?? this.buyerUid,
      vendorUid: vendorUid ?? this.vendorUid,
      status: status ?? this.status,
      buyerLat: buyerLat ?? this.buyerLat,
      buyerLng: buyerLng ?? this.buyerLng,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
