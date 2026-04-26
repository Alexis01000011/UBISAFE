import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Represents the combined GPS + permission state of the device.
///
/// Consumed by [GpsRequiredEmptyState] and map screens.
/// The real StreamProvider implementation lives in F3 (GPSService full build).
enum GpsStatus {
  /// Location permission has not been granted by the user.
  permissionDenied,

  /// Permission is granted but the device location service is turned off.
  serviceOff,

  /// Permission granted + GPS active — position can be read.
  ready,
}

/// F1 mock: manual StateProvider so [GpsRequiredEmptyState] can be built and
/// tested independently of the real GPSService (implemented in F3).
///
/// In F3 this provider is replaced with a StreamProvider that derives its
/// value from geolocator permission + service status events.
final gpsStatusProvider = StateProvider<GpsStatus>((ref) => GpsStatus.ready);

/// Continuous stream of the device's [Position].
///
/// Requests permission on first use and emits null while permission is denied.
final gpsServiceProvider = StreamProvider<Position?>((ref) async* {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever ||
      permission == LocationPermission.denied) {
    yield null;
    return;
  }

  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
});
