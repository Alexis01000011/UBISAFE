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
    this.activo = true,
    this.product,
    this.lastTimestamp,
  });

  final String uid;
  final double latitude;
  final double longitude;

  /// [iter.2] When true the vendor accepts ride requests (CU-04).
  final bool rideEnabled;

  /// False when Firebase executes the onDisconnect handler (vendor lost internet).
  final bool activo;

  /// Product the vendor sells; shown as a label above the map pin.
  final String? product;

  /// Epoch-milliseconds of the last RTDB write. Used by TrackingScreen to detect
  /// when the vendor's internet dropped without onDisconnect firing (timestamp
  /// stops updating while the node stays in RTDB with activo:true).
  final int? lastTimestamp;

  factory VendorMarker.fromMap(String uid, Map map) {
    return VendorMarker(
      uid: uid,
      latitude: num.parse((map['lat'] ?? 0).toString()).toDouble(),
      longitude: num.parse((map['lng'] ?? 0).toString()).toDouble(),
      rideEnabled: map['ride_enabled'] as bool? ?? false,
      activo: map['activo'] != false,
      product: map['product'] as String?,
      lastTimestamp: map['timestamp'] as int?,
    );
  }
}
