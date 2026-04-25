import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityReportStatus { active, dismissed }

/// ☆ [iter.2] Community report model — CU-05/CU-06.
class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.reporterUid,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.votes = 0,
    this.dismissVotes = 0,
  });

  final String id;
  final String reporterUid;
  final double latitude;
  final double longitude;
  final String category;
  final String description;
  final CommunityReportStatus status;
  final DateTime createdAt;
  final int votes;
  final int dismissVotes;

  factory CommunityReport.fromMap(String id, Map<String, dynamic> map) {
    final GeoPoint geoPoint = map['location'] as GeoPoint;
    return CommunityReport(
      id: id,
      reporterUid: map['reporter_uid'] as String,
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
      category: map['category'] as String,
      description: map['description'] as String,
      status: CommunityReportStatus.values
          .byName(map['status'] as String? ?? 'active'),
      createdAt: (map['created_at'] as Timestamp).toDate(),
      votes: map['votes'] as int? ?? 0,
      dismissVotes: map['dismiss_votes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'reporter_uid': reporterUid,
        'location': GeoPoint(latitude, longitude),
        'category': category,
        'description': description,
        'status': status.name,
        'created_at': FieldValue.serverTimestamp(),
        'votes': votes,
        'dismiss_votes': dismissVotes,
      };
}
