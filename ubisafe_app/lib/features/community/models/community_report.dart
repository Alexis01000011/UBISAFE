import 'package:cloud_firestore/cloud_firestore.dart';

// SDD2_FASE3B §7.2.5 — community_reports schema
enum ThreatType {
  animalMuerto('animal_muerto'),
  zonaSucia('zona_sucia');

  const ThreatType(this.value);
  final String value;

  static ThreatType fromString(String s) => values.firstWhere(
        (e) => e.value == s,
        orElse: () => ThreatType.zonaSucia,
      );
}

enum ReportStatus {
  pendingValidation('pending_validation'),
  confirmed('confirmed'),
  dismissed('dismissed'),
  expired('expired');

  const ReportStatus(this.value);
  final String value;

  static ReportStatus fromString(String s) => values.firstWhere(
        (e) => e.value == s,
        orElse: () => ReportStatus.pendingValidation,
      );
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.reporterUid,
    required this.threatType,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 15,
    required this.status,
    this.validations = const [],
    this.confirmCount = 0,
    this.dismissCount = 0,
    this.isDuplicate = false,
    this.canonicalReportId,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  final String id;
  final String reporterUid;
  final ThreatType threatType;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final ReportStatus status;
  final List<Map<String, dynamic>> validations;
  final int confirmCount;
  final int dismissCount;
  final bool isDuplicate;
  final String? canonicalReportId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  static DateTime? _parseTimestamp(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // Reads from Firestore snapshot
  static CommunityReport fromMap(Map<String, dynamic> map) {
    final loc = map['location'];
    double lat = 0, lng = 0;
    if (loc is GeoPoint) {
      lat = loc.latitude;
      lng = loc.longitude;
    } else if (loc is Map) {
      lat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
      lng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
    }
    return CommunityReport(
      id: map['id'] as String? ?? '',
      reporterUid: map['reporter_uid'] as String? ?? '',
      threatType: ThreatType.fromString(map['threat_type'] as String? ?? ''),
      latitude: lat,
      longitude: lng,
      radiusMeters: (map['radius_meters'] as num?)?.toInt() ?? 15,
      status: ReportStatus.fromString(map['status'] as String? ?? ''),
      validations:
          (map['validations'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      confirmCount: (map['confirm_count'] as num?)?.toInt() ?? 0,
      dismissCount: (map['dismiss_count'] as num?)?.toInt() ?? 0,
      isDuplicate: map['is_duplicate'] as bool? ?? false,
      canonicalReportId: map['canonical_report_id'] as String?,
      createdAt: _parseTimestamp(map['created_at']),
      updatedAt: _parseTimestamp(map['updated_at']),
      expiresAt: _parseTimestamp(map['expires_at']),
    );
  }

  // Reads from FastAPI REST response
  static CommunityReport fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    return CommunityReport(
      id: json['id'] as String? ?? '',
      reporterUid: json['reporter_uid'] as String? ?? '',
      threatType: ThreatType.fromString(json['threat_type'] as String? ?? ''),
      latitude: (loc['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (loc['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 15,
      status: ReportStatus.fromString(json['status'] as String? ?? ''),
      validations:
          (json['validations'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      confirmCount: (json['confirm_count'] as num?)?.toInt() ?? 0,
      dismissCount: (json['dismiss_count'] as num?)?.toInt() ?? 0,
      isDuplicate: json['is_duplicate'] as bool? ?? false,
      canonicalReportId: json['canonical_report_id'] as String?,
      createdAt: _parseTimestamp(json['created_at']),
      updatedAt: _parseTimestamp(json['updated_at']),
      expiresAt: _parseTimestamp(json['expires_at']),
    );
  }
}
