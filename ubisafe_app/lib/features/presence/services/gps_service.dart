import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Provides a continuous stream of the device's [Position].
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
