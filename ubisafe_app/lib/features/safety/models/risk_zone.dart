import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a community-reported risk zone (CU-03).
/// Schema matches SDD §7.2.3.
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
    required this.expiresAt,
    this.expiredAt,
    this.dismissedAt,
    this.dismissCount = 0,
    this.dismissers = const [],
  });

  final String id;
  final String reporterUid;
  final String threatType;

  /// 'HIGH' | 'MEDIUM' | 'LOW'
  final String riskLevel;

  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool active;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? expiredAt;
  final DateTime? dismissedAt;
  final int dismissCount;
  final List<String> dismissers;

  factory RiskZone.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>;
    return RiskZone(
      id: json['id'] as String,
      reporterUid: json['reporter_uid'] as String,
      threatType: json['threat_type'] as String,
      riskLevel: json['risk_level'] as String,
      latitude: (loc['lat'] as num).toDouble(),
      longitude: (loc['lng'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toInt(),
      active: json['active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      dismissedAt: json['dismissed_at'] != null
          ? DateTime.parse(json['dismissed_at'] as String)
          : null,
      dismissCount: (json['dismiss_count'] as num?)?.toInt() ?? 0,
      dismissers: (json['dismissers'] as List?)?.cast<String>() ?? const [],
    );
  }

  /// Constructs a RiskZone from a Firestore document snapshot.
  /// Handles date fields stored as Firestore Timestamp (created_at, expired_at)
  /// or as ISO 8601 strings (expires_at — set by the Python backend).
  factory RiskZone.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.parse(v);
      return DateTime.now();
    }

    final loc = data['location'] as Map<String, dynamic>;
    return RiskZone(
      id: id,
      reporterUid: data['reporter_uid'] as String,
      threatType: data['threat_type'] as String,
      riskLevel: data['risk_level'] as String,
      latitude: (loc['lat'] as num).toDouble(),
      longitude: (loc['lng'] as num).toDouble(),
      radiusMeters: (data['radius_meters'] as num).toInt(),
      active: data['active'] as bool,
      createdAt: parseDate(data['created_at']),
      expiresAt: parseDate(data['expires_at']),
      expiredAt: data['expired_at'] != null ? parseDate(data['expired_at']) : null,
      dismissedAt: data['dismissed_at'] != null ? parseDate(data['dismissed_at']) : null,
      dismissCount: (data['dismiss_count'] as num?)?.toInt() ?? 0,
      dismissers: (data['dismissers'] as List?)?.cast<String>() ?? const [],
    );
  }
}
