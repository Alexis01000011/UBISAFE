import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design_system/colors.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡El vendedor llegó!'),
            backgroundColor: AppColors.success500,
          ),
        );
        Navigator.of(context).pop();
      }
    });

    // Unconditional listener — derive vendor_uid from Firestore stream
    ref.listen<AsyncValue<StopRequest?>>(
      _stopRequestStreamProvider(stopId),
      (_, asyncStop) {
        final stop = asyncStop.valueOrNull;
        if (stop?.vendorUid != null && _vendorUid == null) {
          setState(() => _vendorUid = stop!.vendorUid);
        }
      },
    );

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

          final vendorMarker = _vendorUid == null
              ? null
              : vendorsAsync.maybeWhen(
                  data: (vendors) {
                    try {
                      return vendors.firstWhere((v) => v.uid == _vendorUid);
                    } catch (_) {
                      return null;
                    }
                  },
                  orElse: () => null,
                );

          final markers = <Marker>{};
          if (vendorMarker != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('tracked_vendor'),
                position: LatLng(vendorMarker.latitude, vendorMarker.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
                infoWindow: const InfoWindow(title: 'Vendedor'),
              ),
            );
          }

          final distanceKm = vendorMarker == null
              ? null
              : _haversineKm(
                  position.latitude,
                  position.longitude,
                  vendorMarker.latitude,
                  vendorMarker.longitude,
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
        await ref.read(stopRequestModuleProvider).expireStopRequest(stopId);
      } catch (_) {}
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
