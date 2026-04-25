import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../presence/services/gps_service.dart';
import '../../presence/services/vendor_tracker.dart';
import '../../../features/shared/widgets/gps_required_empty_state.dart';
import '../../identity/profile/widgets/drawer_module.dart';

/// Main map screen for buyers.
///
/// [iter.2 ext] Will add:
///   • SpeedDial FAB (raite + community reports).
///   • Community-report markers overlay.
class MapScreenBuyer extends ConsumerWidget {
  const MapScreenBuyer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(gpsServiceProvider);
    final vendorsAsync = ref.watch(vendorTrackerProvider);

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
                    infoWindow: InfoWindow(title: v.displayName ?? v.uid),
                  ),
                )
                .toSet(),
            orElse: () => <Marker>{},
          );

          return GoogleMap(
            initialCameraPosition: initialCamera,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: markers,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error GPS: $e')),
      ),
    );
  }
}
