import 'package:cloud_firestore/cloud_firestore.dart';

enum RiskLevel { high, medium, low }

class RiskZone {
  const RiskZone({
    required this.id,
    required this.reporterUid,
    required this.threatType,
    required this.riskLevel,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.active,
    required this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String reporterUid;
  final String threatType;
  final RiskLevel riskLevel;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool active;
  final DateTime createdAt;
  final DateTime? expiresAt;

  static RiskLevel _parseLevel(String raw) {
    switch (raw.toUpperCase()) {
      case 'HIGH':
        return RiskLevel.high;
      case 'LOW':
        return RiskLevel.low;
      default:
        return RiskLevel.medium;
    }
  }

  factory RiskZone.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['location'];
    double lat = 0;
    double lng = 0;
    if (raw is GeoPoint) {
      lat = raw.latitude;
      lng = raw.longitude;
    } else if (raw is Map) {
      lat = (raw['lat'] as num).toDouble();
      lng = (raw['lng'] as num).toDouble();
    }
    return RiskZone(
      id: id,
      reporterUid: map['reporter_uid'] as String,
      threatType: map['threat_type'] as String,
      riskLevel: _parseLevel(map['risk_level'] as String),
      latitude: lat,
      longitude: lng,
      radiusMeters: (map['radius_meters'] as num?)?.toInt() ?? 100,
      active: map['active'] as bool? ?? true,
      createdAt: map['created_at'] is Timestamp
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'] as String)
          : null,
    );
  }

  factory RiskZone.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>;
    return RiskZone(
      id: json['id'] as String,
      reporterUid: json['reporter_uid'] as String,
      threatType: json['threat_type'] as String,
      riskLevel: _parseLevel(json['risk_level'] as String),
      latitude: (loc['lat'] as num).toDouble(),
      longitude: (loc['lng'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 100,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }
}
