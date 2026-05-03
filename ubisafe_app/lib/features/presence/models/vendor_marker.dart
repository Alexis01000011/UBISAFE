/// Represents a vendor pin on the buyer's map.
///
/// Built from RTDB /vendedores_activos/{uid} nodes, which store flat numeric
/// fields (lat/lng) — NOT Firestore GeoPoint objects.
///
/// [iter.2] rideEnabled will be written to the RTDB node when the vendor
/// activates ride mode (CU-04), so the buyer can see it on the marker.
class VendorMarker {
  const VendorMarker({
    required this.uid,
    required this.latitude,
    required this.longitude,
    this.rideEnabled = false,
  });

  final String uid;
  final double latitude;
  final double longitude;

  /// [iter.2] When true the vendor accepts ride requests (CU-04).
  final bool rideEnabled;

  factory VendorMarker.fromMap(String uid, Map<dynamic, dynamic> map) {
    return VendorMarker(
      uid: uid,
      latitude: num.parse(map['lat'].toString()).toDouble(),
      longitude: num.parse(map['lng'].toString()).toDouble(),
      rideEnabled: map['ride_enabled'] as bool? ?? false,
    );
  }
}
