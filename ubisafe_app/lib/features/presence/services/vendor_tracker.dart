import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/vendor_marker.dart';
import 'gps_service.dart';

const double _kRadiusKm = 4.0;

/// Subscribes to /vendedores_activos in RTDB and emits filtered
/// [VendorMarker] lists within [_kRadiusKm] of the buyer's position.
///
/// Inject [rtdbRef] or use [VendorTracker.fromStream] in tests to avoid
/// real Firebase calls.
///
/// SDD §5.3.2.2
class VendorTracker {
  VendorTracker({DatabaseReference? rtdbRef}) {
    final ref = rtdbRef ?? FirebaseDatabase.instance.ref('vendedores_activos');
    _init(ref.onValue
        .map((event) => event.snapshot.value as Map<dynamic, dynamic>? ?? {})
        .asBroadcastStream());
  }

  /// Test-friendly constructor: inject a raw map stream directly.
  /// Converts to broadcast so tests can attach multiple listeners (e.g. the
  /// provider + the test assertion) without a StateError.
  VendorTracker.fromStream(Stream<Map<dynamic, dynamic>> rawStream) {
    _init(rawStream.isBroadcast ? rawStream : rawStream.asBroadcastStream());
  }

  final _controller = StreamController<List<VendorMarker>>.broadcast();
  StreamSubscription<Map<dynamic, dynamic>>? _sub;
  Map<String, VendorMarker> _vendors = {};
  double? _buyerLat;
  double? _buyerLng;

  /// Filtered stream of active vendors within [_kRadiusKm].
  Stream<List<VendorMarker>> get vendorStream => _controller.stream;

  void _init(Stream<Map<dynamic, dynamic>> stream) {
    _sub = stream.listen(
      (raw) {
        final updated = <String, VendorMarker>{};
        for (final e in raw.entries) {
          try {
            updated[e.key as String] = VendorMarker.fromMap(
              e.key as String,
              e.value as Map<dynamic, dynamic>,
            );
          } catch (err) {
            if (kDebugMode) {
              debugPrint('VendorTracker: entry ${e.key} malformed — $err');
            }
          }
        }
        _vendors = updated;
        _emit();
      },
      onError: (Object err) {
        // Typical cause: RTDB permission_denied (missing .read rule) or
        // no connectivity. Logged in debug so the error is visible without
        // crashing the stream.
        if (kDebugMode) debugPrint('VendorTracker RTDB error: $err');
        if (!_controller.isClosed) _controller.add([]);
      },
    );
  }

  /// Call whenever the buyer's position changes to re-filter the marker list.
  void updateBuyerPosition(double lat, double lng) {
    _buyerLat = lat;
    _buyerLng = lng;
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) return;
    final lat = _buyerLat;
    final lng = _buyerLng;
    if (lat == null || lng == null) {
      _controller.add(const []);
      return;
    }
    _controller.add(
      List.unmodifiable(
        _vendors.values.where(
          (v) => haversineKm(lat, lng, v.latitude, v.longitude) <= _kRadiusKm,
        ),
      ),
    );
  }

  void dispose() {
    _sub?.cancel();
    if (!_controller.isClosed) _controller.close();
  }

  /// Great-circle distance in kilometres (Haversine formula).
  static double haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _vendorTrackerInstanceProvider = Provider<VendorTracker>((ref) {
  final tracker = VendorTracker();

  // Seed with the current GPS position if already available.
  // ref.listen only fires on *subsequent* changes — without this read the
  // tracker's _buyerLat/_buyerLng stays null if GPS was already streaming
  // when this provider was first created, causing _emit() to always return
  // an empty vendor list regardless of active vendors in RTDB.
  final initialPos = ref.read(gpsServiceProvider).valueOrNull;
  if (initialPos != null) {
    tracker.updateBuyerPosition(initialPos.latitude, initialPos.longitude);
  }

  // Keep in sync with subsequent GPS position changes.
  ref.listen<AsyncValue<Position?>>(gpsServiceProvider, (_, next) {
    final pos = next.valueOrNull;
    if (pos != null) tracker.updateBuyerPosition(pos.latitude, pos.longitude);
  });

  ref.onDispose(tracker.dispose);
  return tracker;
});

/// Emits filtered [VendorMarker] lists in real time.
///
/// SDD §5.3.2.2 — vendorMarkersProvider
final vendorMarkersProvider = StreamProvider<List<VendorMarker>>((ref) {
  return ref.watch(_vendorTrackerInstanceProvider).vendorStream;
});
