import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../presence/services/gps_service.dart';
import '../../../features/shared/widgets/gps_required_empty_state.dart';

/// Real-time tracking screen.
///
/// Reused for both stop-request tracking and ride tracking (CU-04)
/// without structural changes.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({
    super.key,
    this.rideId,
    this.stopRequestId,
  });

  /// When non-null, tracks the active ride with this ID.
  final String? rideId;

  /// When non-null, tracks the active stop request with this ID.
  final String? stopRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(gpsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento')),
      body: positionAsync.when(
        data: (position) {
          if (position == null) return const GpsRequiredEmptyState();

          final initialCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16,
          );

          return GoogleMap(
            initialCameraPosition: initialCamera,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            // TODO: draw route polyline and track counterpart's position.
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error GPS: $e')),
      ),
    );
  }
}
