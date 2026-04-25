import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a community-reported risk zone on the map.
class RiskZone {
  const RiskZone({
    required this.id,
    required this.reporterUid,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.description,
    required this.createdAt,
    this.confirmations = 0,
  });

  final String id;
  final String reporterUid;
  final double latitude;
  final double longitude;

  /// E.g. 'robbery', 'harassment', 'accident', 'other'.
  final String category;

  final String description;
  final DateTime createdAt;
  final int confirmations;

  factory RiskZone.fromMap(String id, Map<String, dynamic> map) {
    final GeoPoint geoPoint = map['location'] as GeoPoint;
    return RiskZone(
      id: id,
      reporterUid: map['reporter_uid'] as String,
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
      category: map['category'] as String,
      description: map['description'] as String,
      createdAt: (map['created_at'] as Timestamp).toDate(),
      confirmations: map['confirmations'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'reporter_uid': reporterUid,
        'location': GeoPoint(latitude, longitude),
        'category': category,
        'description': description,
        'created_at': FieldValue.serverTimestamp(),
        'confirmations': confirmations,
      };
}
