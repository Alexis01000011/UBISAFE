import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design_system/colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../identity/profile/widgets/drawer_module.dart';
import '../../presence/services/gps_service.dart';
import '../../presence/services/vendor_tracker.dart';
import '../../shared/notifications/notification_handler.dart';
import '../../shared/widgets/gps_required_empty_state.dart';
import '../models/stop_request.dart';
import '../services/stop_request_module.dart';

enum _BuyerMapState { idle, waiting }

/// Main map screen for buyers — vendor markers, stop-request flow (CU-01).
class MapScreenBuyer extends ConsumerStatefulWidget {
  const MapScreenBuyer({super.key});

  @override
  ConsumerState<MapScreenBuyer> createState() => _MapScreenBuyerState();
}

class _MapScreenBuyerState extends ConsumerState<MapScreenBuyer> {
  _BuyerMapState _mapState = _BuyerMapState.idle;
  String? _activeStopId;

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(gpsServiceProvider);
    final vendorsAsync = ref.watch(vendorMarkersProvider);

    // Listen for FCM events (accepted/rejected/expired)
    ref.listen<StopEvent?>(stopRequestEventProvider, (_, event) {
      if (event == null) return;
      if (_activeStopId != null && event.stopId != _activeStopId) return;

      if (event.status == StopRequestStatus.accepted) {
        ref.read(stopRequestModuleProvider).cancelTimer();
        setState(() => _mapState = _BuyerMapState.idle);
        context.push('/tracking?stop_id=${event.stopId}');
        ref.read(stopRequestEventProvider.notifier).state = null;
      } else if (event.status == StopRequestStatus.rejected) {
        setState(() {
          _mapState = _BuyerMapState.idle;
          _activeStopId = null;
        });
        ref.read(stopRequestEventProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El vendedor no pudo atenderte.')),
        );
      } else if (event.status == StopRequestStatus.expired) {
        setState(() {
          _mapState = _BuyerMapState.idle;
          _activeStopId = null;
        });
        ref.read(stopRequestEventProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiempo de espera agotado.')),
        );
      }
    });

    return Scaffold(
      drawer: const DrawerModule(),
      appBar: AppBar(title: const Text('UbiSafe — Mapa')),
      body: positionAsync.when(
        data: (position) {
          if (position == null) return const GpsRequiredEmptyState();

          final initialCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          );

          final markers = vendorsAsync.maybeWhen(
            data: (vendors) => vendors
                .map(
                  (v) => Marker(
                    markerId: MarkerId(v.uid),
                    position: LatLng(v.latitude, v.longitude),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                    infoWindow: const InfoWindow(title: 'Vendedor'),
                    onTap: () => _onVendorTap(
                      context,
                      vendorUid: v.uid,
                      buyerLat: position.latitude,
                      buyerLng: position.longitude,
                    ),
                  ),
                )
                .toSet(),
            orElse: () => <Marker>{},
          );

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: initialCamera,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: markers,
              ),
              if (_mapState == _BuyerMapState.waiting)
                _WaitingOverlay(
                  onCancel: () async {
                    final stopId = _activeStopId;
                    if (stopId == null) return;
                    setState(() {
                      _mapState = _BuyerMapState.idle;
                      _activeStopId = null;
                    });
                    try {
                      await ref
                          .read(stopRequestModuleProvider)
                          .expireStopRequest(stopId);
                    } catch (_) {}
                  },
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error GPS: $e')),
      ),
    );
  }

  Future<void> _onVendorTap(
    BuildContext context, {
    required String vendorUid,
    required double buyerLat,
    required double buyerLng,
  }) async {
    if (_mapState != _BuyerMapState.idle) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _VendorBottomSheet(vendorUid: vendorUid),
    );

    if (confirmed != true || !context.mounted) return;

    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;

    setState(() => _mapState = _BuyerMapState.waiting);

    final messenger = ScaffoldMessenger.of(context);
    try {
      final stop = await ref.read(stopRequestModuleProvider).createStopRequest(
            vendorUid: vendorUid,
            buyerLat: buyerLat,
            buyerLng: buyerLng,
          );
      _activeStopId = stop.id;
      ref.read(activeStopProvider.notifier).set(stop);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mapState = _BuyerMapState.idle);
      messenger.showSnackBar(
        SnackBar(content: Text('Error al solicitar parada: $e')),
      );
    }
  }
}

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Esperando respuesta del vendedor…',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'El vendedor tiene 60 segundos para responder.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onCancel,
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorBottomSheet extends StatelessWidget {
  const _VendorBottomSheet({required this.vendorUid});

  final String vendorUid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Solicitar parada',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vendedor cercano disponible',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary700,
              foregroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Solicitar Parada'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
