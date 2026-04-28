import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

/// Combined GPS permission + service-availability state.
///
/// Consumed by [GpsRequiredEmptyState] and map screens.
enum GpsStatus {
  /// The user has not granted location permission.
  permissionDenied,

  /// Permission is granted but the device GPS is turned off.
  serviceOff,

  /// Permission granted AND GPS active — position can be read.
  ready,
}

/// Operational state of the active RTDB transmission.
enum GPSServiceState {
  /// Stream is active and positions are being written to RTDB.
  active,

  /// Transmission stopped (stopTransmission called).
  inactive,

  /// GPS fix timed out; last known position retained in RTDB.
  // ignore: constant_identifier_names
  error_no_signal,
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Real [StreamProvider] that reflects OS permission + GPS service status.
/// Replaces the F1 mock [StateProvider].
///
/// SDD §5.3.2.1 — gpsStatusProvider
final gpsStatusProvider = StreamProvider<GpsStatus>((ref) => _statusStream());

/// Continuous [Position] stream for the buyer's device location.
/// Used by [VendorTracker] and map screens.
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
  ).map((p) => p as Position?);
});

/// Singleton [GPSService] instance managed by Riverpod.
final gpsServiceInstanceProvider = Provider<GPSService>((ref) {
  final service = GPSService();
  ref.onDispose(service.dispose);
  return service;
});

// ─── Type aliases (for dependency injection / testing) ────────────────────────

typedef PositionStreamFactory = Stream<Position> Function(LocationSettings);
typedef RtdbRefFactory = DatabaseReference Function(String vendorUid);

const _kVendorsPath = 'vendedores_activos';

// ─── GPSService ───────────────────────────────────────────────────────────────

/// Reads device GPS and writes vendor positions directly to Firebase RTDB.
///
/// GPS → RTDB (no FastAPI involved — ADR #2).
///
/// Inject [positionStreamFactory] and [rtdbRefFactory] in tests to avoid
/// real hardware / Firebase calls.
class GPSService {
  GPSService({
    PositionStreamFactory? positionStreamFactory,
    RtdbRefFactory? rtdbRefFactory,
  })  : _positionStreamFactory =
            positionStreamFactory ?? _defaultPositionStream,
        _rtdbRefFactory = rtdbRefFactory ?? _defaultRtdbRef;

  static const _kNoSignalTimeout = Duration(seconds: 10);
  static const _kRetryDelay = Duration(seconds: 5);

  final PositionStreamFactory _positionStreamFactory;
  final RtdbRefFactory _rtdbRefFactory;

  final _stateCtrl = StreamController<GPSServiceState>.broadcast();
  StreamSubscription<Position>? _posSub;
  Timer? _retryTimer;
  String? _activeUid;

  /// Broadcasts [GPSServiceState] transitions.
  Stream<GPSServiceState> get stateStream => _stateCtrl.stream;

  /// Activates GPS stream and RTDB writes for [vendorUid].
  ///
  /// Registers onDisconnect().remove() before the first write so that a
  /// crash or network drop automatically removes the stale RTDB node.
  void startTransmission(String vendorUid) {
    _activeUid = vendorUid;
    _stateCtrl.add(GPSServiceState.active);
    _subscribe(vendorUid);
  }

  /// Stops the GPS stream, removes the RTDB node, and emits [inactive].
  Future<void> stopTransmission(String vendorUid) async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _posSub?.cancel();
    _posSub = null;
    await _rtdbRefFactory(vendorUid).remove();
    if (!_stateCtrl.isClosed) _stateCtrl.add(GPSServiceState.inactive);
    _activeUid = null;
  }

  void _subscribe(String vendorUid) {
    // Register the disconnect handler BEFORE any write (safety invariant).
    _rtdbRefFactory(vendorUid).onDisconnect().remove();

    _posSub?.cancel();
    _posSub = _positionStreamFactory(
      const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: _kNoSignalTimeout,
      ),
    ).listen(
      (pos) {
        _retryTimer?.cancel();
        _retryTimer = null;
        _rtdbRefFactory(vendorUid).set({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'activo': true,
        });
        if (!_stateCtrl.isClosed) _stateCtrl.add(GPSServiceState.active);
      },
      onError: (_) {
        if (!_stateCtrl.isClosed) {
          _stateCtrl.add(GPSServiceState.error_no_signal);
        }
        _scheduleRetry(vendorUid);
      },
    );
  }

  void _scheduleRetry(String vendorUid) {
    _retryTimer?.cancel();
    _retryTimer = Timer(_kRetryDelay, () {
      if (_activeUid == vendorUid) _subscribe(vendorUid);
    });
  }

  void dispose() {
    _posSub?.cancel();
    _retryTimer?.cancel();
    if (!_stateCtrl.isClosed) _stateCtrl.close();
  }
}

// ─── Private helpers ──────────────────────────────────────────────────────────

Stream<Position> _defaultPositionStream(LocationSettings settings) =>
    Geolocator.getPositionStream(locationSettings: settings);

DatabaseReference _defaultRtdbRef(String vendorUid) =>
    FirebaseDatabase.instance.ref('$_kVendorsPath/$vendorUid');

Stream<GpsStatus> _statusStream() async* {
  final permission = await Geolocator.checkPermission();
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  yield _toStatus(permission, serviceEnabled);

  await for (final serviceStatus in Geolocator.getServiceStatusStream()) {
    final perm = await Geolocator.checkPermission();
    yield _toStatus(perm, serviceStatus == ServiceStatus.enabled);
  }
}

GpsStatus _toStatus(LocationPermission permission, bool serviceEnabled) {
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return GpsStatus.permissionDenied;
  }
  return serviceEnabled ? GpsStatus.ready : GpsStatus.serviceOff;
}
