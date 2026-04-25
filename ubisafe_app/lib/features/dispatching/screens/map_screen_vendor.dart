import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../presence/services/gps_service.dart';
import '../../../features/shared/widgets/gps_required_empty_state.dart';
import '../../identity/profile/widgets/drawer_module.dart';

/// Main map screen for vendors.
///
/// Shows vendor's own location and allows toggling visibility.
///
/// [iter.2 ext] Will add:
///   • Incoming ride-request dialog.
///   • Community-report markers overlay.
class MapScreenVendor extends ConsumerWidget {
  const MapScreenVendor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(gpsServiceProvider);

    return Scaffold(
      drawer: const DrawerModule(),
      appBar: AppBar(title: const Text('UbiSafe — Vendedor')),
      body: positionAsync.when(
        data: (position) {
          if (position == null) return const GpsRequiredEmptyState();

          final initialCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          );

          return GoogleMap(
            initialCameraPosition: initialCamera,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error GPS: $e')),
      ),
    );
  }
}
