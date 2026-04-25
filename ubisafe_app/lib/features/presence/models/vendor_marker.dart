import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a vendor pin shown on the map.
///
/// [iter.2] Adds `rideEnabled` field to opt-in to ride requests (CU-04).
class VendorMarker {
  const VendorMarker({
    required this.uid,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    this.rideEnabled = false, // [iter.2]
    this.displayName,
  });

  final String uid;
  final double latitude;
  final double longitude;
  final bool isActive;

  /// [iter.2] When true the vendor accepts ride requests (CU-04).
  final bool rideEnabled;

  final String? displayName;

  factory VendorMarker.fromMap(String uid, Map<String, dynamic> map) {
    final GeoPoint geoPoint = map['location'] as GeoPoint;
    return VendorMarker(
      uid: uid,
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
      isActive: map['is_active'] as bool? ?? false,
      rideEnabled: map['ride_enabled'] as bool? ?? false,
      displayName: map['display_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'location': GeoPoint(latitude, longitude),
        'is_active': isActive,
        'ride_enabled': rideEnabled,
        if (displayName != null) 'display_name': displayName,
      };
}
