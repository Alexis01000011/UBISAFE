import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/vendor_marker.dart';
import 'gps_service.dart';

const double _kRadiusKm = 4.0;
const Duration _kReconnectDelay = Duration(seconds: 5);
// Vendors whose lastTimestamp is older than this are excluded from _emit()
// regardless of their activo flag, guarding against zombie RTDB state when
// the listener missed the node-deletion event.
const int _kMaxVendorAgeMs = 5 * 60 * 1000; // 5 minutes

/// Subscribes to /vendedores_activos in RTDB and emits filtered
/// [VendorMarker] lists within [_kRadiusKm] of the buyer's position.
///
/// Inject [rtdbRef] or use [VendorTracker.fromStream] in tests to avoid
/// real Firebase calls.
///
/// SDD §5.3.2.2
class VendorTracker {
  VendorTracker({DatabaseReference? rtdbRef})
      : _rtdbRef = rtdbRef ?? FirebaseDatabase.instance.ref('vendedores_activos') {
    _subscribe();
  }

  /// Test-friendly constructor: inject a raw map stream directly.
  /// Converts to broadcast so tests can attach multiple listeners (e.g. the
  /// provider + the test assertion) without a StateError.
  VendorTracker.fromStream(Stream<Map> rawStream) : _rtdbRef = null {
    _init(rawStream.isBroadcast ? rawStream : rawStream.asBroadcastStream());
  }

  /// Null only in the [fromStream] test constructor.
  final DatabaseReference? _rtdbRef;
  final _controller = StreamController<List<VendorMarker>>.broadcast();
  final _offlineCtrl = StreamController<String>.broadcast();
  StreamSubscription<Map<dynamic, dynamic>>? _sub;
  Timer? _reconnectTimer;
  Map<String, VendorMarker> _vendors = {};
  double? _buyerLat;
  double? _buyerLng;

  /// Filtered stream of active vendors within [_kRadiusKm].
  Stream<List<VendorMarker>> get vendorStream => _controller.stream;

  /// Emits the UID of a vendor whose connection just dropped (activo → false).
  Stream<String> get vendorOfflineStream => _offlineCtrl.stream;

  /// Creates a fresh RTDB subscription. Called on construction and after any
  /// RTDB error that closes the underlying stream (e.g. permission_denied after
  /// Firebase Auth token expiry). Not used by the [fromStream] test path.
  void _subscribe() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final ref = _rtdbRef;
    if (ref == null) return;
    _sub?.cancel();
    _sub = null;
    _init(
      ref.onValue
          .map((event) {
            final v = event.snapshot.value;
            return v is Map ? v : const <Object?, Object?>{};
          })
          .asBroadcastStream(),
    );
  }

  void _init(Stream<Map> stream) {
    _sub = stream.listen(
      (raw) {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        final updated = <String, VendorMarker>{};
        for (final e in raw.entries) {
          try {
            final key = e.key?.toString();
            final value = e.value;
            if (key == null || value is! Map) continue;
            updated[key] = VendorMarker.fromMap(key, value);
          } catch (err) {
            if (kDebugMode) {
              debugPrint('VendorTracker: entry ${e.key} malformed — $err');
            }
          }
        }
        // Detect vendors that transitioned activo: true → false (lost internet).
        for (final entry in updated.entries) {
          final prev = _vendors[entry.key];
          if (prev != null && prev.activo && !entry.value.activo) {
            if (!_offlineCtrl.isClosed) _offlineCtrl.add(entry.key);
          }
        }
        // Detect vendors whose node was deleted from RTDB (onDisconnect.remove fired).
        for (final key in _vendors.keys) {
          if (!updated.containsKey(key) && (_vendors[key]?.activo ?? false)) {
            if (!_offlineCtrl.isClosed) _offlineCtrl.add(key);
          }
        }
        _vendors = updated;
        _emit();
      },
      onError: (Object err) {
        // Typical cause: permission_denied after Firebase Auth token expiry.
        // The underlying stream closes on error, so cancelOnError:false alone
        // is not enough — _sub would stay alive but receive no more events
        // (zombie state). Re-subscribe after a short delay so the next SDK
        // reconnect cycle delivers a fresh snapshot.
        if (kDebugMode) debugPrint('VendorTracker RTDB error: $err');
        if (!_controller.isClosed) _controller.add([]);
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(_kReconnectDelay, () {
          if (!_controller.isClosed) _subscribe();
        });
      },
      cancelOnError: false,
    );
  }

  /// Forces a clean RTDB re-subscription. Call when the app returns to the
  /// foreground after a long background period (token may have expired).
  void reconnect() => _subscribe();

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
    final now = DateTime.now().millisecondsSinceEpoch;
    _controller.add(
      List.unmodifiable(
        _vendors.values.where(
          (v) {
            if (!v.activo) return false;
            // Guard against zombie RTDB state: if the listener missed the
            // node-deletion event, the vendor's lastTimestamp will stop
            // advancing. Treat vendors whose last write is older than
            // _kMaxVendorAgeMs as offline so the stale marker disappears.
            final ts = v.lastTimestamp;
            if (ts != null && now - ts > _kMaxVendorAgeMs) return false;
            return haversineKm(lat, lng, v.latitude, v.longitude) <= _kRadiusKm;
          },
        ),
      ),
    );
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    if (!_controller.isClosed) _controller.close();
    if (!_offlineCtrl.isClosed) _offlineCtrl.close();
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

final vendorTrackerInstanceProvider = Provider<VendorTracker>((ref) {
  final tracker = VendorTracker();

  // Seed with the current GPS position if already available.
  // ref.listen only fires on *subsequent* changes — without this read the
  // tracker's _buyerLat/_buyerLng stays null if GPS was already streaming
  // when this provider was first created, causing _emit() to always return
  // an empty vendor list regardless of active vendors in RTDB.
  final initialPos = ref.read(gpsServiceProvider).valueOrNull;
  if (initialPos != null) {
    tracker.updateBuyerPosition(initialPos.latitude, initialPos.longitude);
  } else {
    // Stream hasn't emitted yet (GPS permission still being resolved or first
    // fix not received). Try the last cached OS position as an immediate seed
    // so RTDB events that arrive before the first GPS fix are not filtered out.
    Geolocator.getLastKnownPosition().then((pos) {
      if (pos != null) tracker.updateBuyerPosition(pos.latitude, pos.longitude);
    }).catchError((_) {});
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
  return ref.watch(vendorTrackerInstanceProvider).vendorStream;
});

/// Emits the UID of a vendor whose RTDB connection just dropped (activo → false).
/// Consumed by MapScreenBuyer to show a "tracking paused" snackbar.
final vendorOfflineEventProvider = StreamProvider.autoDispose<String>((ref) {
  return ref.watch(vendorTrackerInstanceProvider).vendorOfflineStream;
});
