import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design_system/colors.dart';
import '../../presence/models/vendor_marker.dart';
import '../../presence/services/gps_service.dart';
import '../../presence/services/vendor_tracker.dart';
import '../../shared/notifications/notification_handler.dart';
import '../../shared/widgets/gps_required_empty_state.dart';
import '../models/stop_request.dart';
import '../services/stop_request_module.dart';

// Provider that streams a single stop request from Firestore.
// Returns an empty stream when stopId is empty (rideId-only mode).
final _stopRequestStreamProvider =
    StreamProvider.autoDispose.family<StopRequest?, String>((ref, stopId) {
  if (stopId.isEmpty) return const Stream.empty();
  return ref.read(stopRequestModuleProvider).watchStopRequest(stopId);
});

/// Real-time vendor tracking screen — shown to buyer after stop accepted.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({
    super.key,
    this.rideId,
    this.stopRequestId,
  });

  final String? rideId;
  final String? stopRequestId;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  String? _vendorUid;

  // Last known vendor position — shown as a frozen orange marker when the
  // vendor goes offline (RTDB timestamp stops updating or node disappears).
  LatLng? _lastKnownVendorPos;

  // True once the "tracking paused" snackbar has been shown for the current
  // offline event; reset when the vendor comes back online.
  bool _vendorOfflineNotified = false;

  // Fires every 10 s to detect when the RTDB timestamp stops updating
  // (vendor lost internet but onDisconnect didn't fire — e.g., emulator via
  // ADB tunnel stays alive when mobile data is off).
  Timer? _stalenessTimer;

  @override
  void initState() {
    super.initState();
    if (widget.stopRequestId != null) {
      // Belt-and-suspenders: cancel the 60-second expiry timer that
      // StopRequestModule started when the buyer sent the stop request.
      // map_screen_buyer.dart already calls cancelTimer() on the accepted FCM
      // event, but if FCM and the timer race (FCM arrives within the last ~1s),
      // the timer callback fires anyway and hits a 400 on the already-accepted
      // stop.  Cancelling here guarantees the timer is dead before it can fire.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(stopRequestModuleProvider).cancelTimer();
      });
    }
    _stalenessTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkStaleness());
  }

  @override
  void dispose() {
    _stalenessTimer?.cancel();
    super.dispose();
  }

  /// Checks whether the tracked vendor's RTDB timestamp stopped updating —
  /// primary offline-detection mechanism when onDisconnect doesn't fire.
  void _checkStaleness() {
    if (!mounted || _vendorUid == null) return;
    final uid = _vendorUid!;
    final vendors = ref.read(vendorMarkersProvider).valueOrNull;
    if (vendors == null) return;

    VendorMarker? vendor;
    try {
      vendor = vendors.firstWhere((v) => v.uid == uid);
    } catch (_) {}

    if (vendor != null) {
      // Vendor is still in RTDB — check if timestamp went stale.
      final ts = vendor.lastTimestamp;
      if (ts != null) {
        final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
        if (ageMs > 30000) {
          _notifyVendorOffline();
        } else {
          // Timestamp is fresh — vendor is live, reset the offline flag.
          _vendorOfflineNotified = false;
        }
      } else {
        // No timestamp field — treat as live.
        _vendorOfflineNotified = false;
      }
    } else if (_lastKnownVendorPos != null) {
      // Vendor node was removed (onDisconnect or stopTransmission) — show orange marker.
      _notifyVendorOffline();
    }
  }

  void _notifyVendorOffline() {
    if (_vendorOfflineNotified) return;
    _vendorOfflineNotified = true;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El seguimiento en tiempo real se ha pausado.'),
        duration: Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(gpsServiceProvider);
    final vendorsAsync = ref.watch(vendorMarkersProvider);
    final stopId = widget.stopRequestId ?? '';

    // Unconditional listener — stop request status changes (completed)
    ref.listen<StopEvent?>(stopRequestEventProvider, (_, event) {
      if (event == null || stopId.isEmpty) return;
      if (event.stopId != stopId) return;
      if (event.status == StopRequestStatus.completed) {
        ref.read(stopRequestEventProvider.notifier).state = null;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡El vendedor llegó!'),
            backgroundColor: AppColors.success500,
          ),
        );
        Navigator.of(context).pop();
      } else if (event.status == StopRequestStatus.abandoned) {
        ref.read(stopRequestEventProvider.notifier).state = null;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El vendedor abandonó la aplicación.'),
            backgroundColor: AppColors.warning500,
          ),
        );
        Navigator.of(context).pop();
      }
    });

    // Unconditional listener — derive vendor_uid from Firestore stream.
    // Seeds _lastKnownVendorPos immediately so the orange marker has a position
    // to fall back to even if vendorMarkersProvider doesn't emit again (G05).
    ref.listen<AsyncValue<StopRequest?>>(
      _stopRequestStreamProvider(stopId),
      (_, asyncStop) {
        final stop = asyncStop.valueOrNull;
        if (stop?.vendorUid != null && _vendorUid == null) {
          final uid = stop!.vendorUid!;
          setState(() {
            _vendorUid = uid;
            VendorMarker? v;
            try {
              v = ref
                  .read(vendorMarkersProvider)
                  .valueOrNull
                  ?.firstWhere((m) => m.uid == uid);
            } catch (_) {}
            if (v != null) {
              _lastKnownVendorPos = LatLng(v.latitude, v.longitude);
            }
          });
        }
      },
    );

    // Keep _lastKnownVendorPos fresh so the frozen marker is always accurate.
    // Notification logic lives in _checkStaleness() (timer) instead of here
    // to handle both cases: stale RTDB node AND disappeared node.
    ref.listen<AsyncValue<List<VendorMarker>>>(vendorMarkersProvider, (_, next) {
      final uid = _vendorUid;
      if (uid == null) return;
      VendorMarker? vendor;
      try {
        vendor = next.valueOrNull?.firstWhere((v) => v.uid == uid);
      } catch (_) {}
      if (vendor != null) {
        setState(() {
          _lastKnownVendorPos = LatLng(vendor!.latitude, vendor.longitude);
        });
        _vendorOfflineNotified = false;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento'),
        backgroundColor: AppColors.primary700,
        foregroundColor: AppColors.surface,
      ),
      body: positionAsync.when(
        data: (position) {
          if (position == null) return const GpsRequiredEmptyState();

          final initialCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16,
          );

          // Live vendor position from RTDB (null when offline or not yet loaded).
          VendorMarker? vendorMarker;
          if (_vendorUid != null) {
            try {
              vendorMarker = vendorsAsync.valueOrNull
                  ?.firstWhere((v) => v.uid == _vendorUid);
            } catch (_) {}
          }

          // Display position: prefer live, fallback to cached last-known.
          final displayPos = vendorMarker != null
              ? LatLng(vendorMarker.latitude, vendorMarker.longitude)
              : _lastKnownVendorPos;

          final markers = <Marker>{};
          if (displayPos != null) {
            final isLive = vendorMarker != null;
            markers.add(
              Marker(
                markerId: const MarkerId('tracked_vendor'),
                position: displayPos,
                // Blue = live position. Orange = last-known (vendor offline).
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  isLive
                      ? BitmapDescriptor.hueBlue
                      : BitmapDescriptor.hueOrange,
                ),
                infoWindow: InfoWindow(
                  title: isLive ? 'Vendedor' : 'Última posición conocida',
                ),
              ),
            );
          }

          final distanceKm = displayPos == null
              ? null
              : _haversineKm(
                  position.latitude,
                  position.longitude,
                  displayPos.latitude,
                  displayPos.longitude,
                );

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: initialCamera,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                markers: markers,
              ),
              if (distanceKm != null)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _DistanceBadge(distanceKm: distanceKm),
                  ),
                ),
              if (vendorMarker == null && _vendorUid != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Material(
                    color: AppColors.warning500,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Vendedor perdió conexión GPS',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.surface),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 32,
                left: 24,
                right: 24,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger500),
                    foregroundColor: AppColors.danger500,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _confirmCancel(context),
                  child: const Text('Cancelar solicitud'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error GPS: $e')),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: const Text('¿Deseas cancelar la solicitud de parada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final stopId = widget.stopRequestId;
    if (stopId != null) {
      try {
        await ref.read(stopRequestModuleProvider).cancelStopRequest(stopId);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e')),
        );
        return;
      }
    }
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.distanceKm});

  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final label = distanceKm < 1
        ? '${(distanceKm * 1000).round()} m'
        : '${distanceKm.toStringAsFixed(1)} km';
    return Material(
      color: AppColors.primary700,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'Vendedor a $label',
          style: const TextStyle(
            color: AppColors.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _deg2rad(double deg) => deg * math.pi / 180;
