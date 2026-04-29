import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design_system/colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../community/models/community_report.dart';
import '../../community/screens/community_form_bottom_sheet.dart';
import '../../community/services/community_report_module.dart';
import '../../identity/profile/widgets/drawer_module.dart';
import '../../presence/services/gps_service.dart';
import '../../safety/models/risk_zone.dart';
import '../../safety/screens/risk_form_bottom_sheet.dart';
import '../../safety/services/risk_report_module.dart';
import '../../shared/notifications/notification_handler.dart';
import '../../shared/widgets/gps_required_empty_state.dart';
import '../models/ride.dart';
import '../services/ride_request_module.dart';
import '../services/stop_request_module.dart';

// Replace via --dart-define=MAPS_API_KEY=<key> at build/run time.
const _kMapsApiKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');

/// Main map screen for vendors — GPS visibility toggle + CU-01 responder.
class MapScreenVendor extends ConsumerStatefulWidget {
  const MapScreenVendor({super.key});

  @override
  ConsumerState<MapScreenVendor> createState() => _MapScreenVendorState();
}

class _MapScreenVendorState extends ConsumerState<MapScreenVendor> {
  bool _isVisible = false;
  bool _isNavigating = false;
  bool _riskZonesLoaded = false;
  bool _communityReportsLoaded = false;
  bool _speedDialOpen = false;
  String? _activeStopId;
  String? _activeRideId;
  // 1 = going to pickup, 2 = ride in progress (passenger aboard)
  int _ridePhase = 0;
  List<LatLng> _routePolyline = [];

  StreamSubscription<Ride?>? _rideSub;

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(gpsServiceProvider);
    final riskZonesAsync = ref.watch(activeRiskZonesProvider);
    final communityReportsAsync = ref.watch(activeCommunityReportsProvider);

    // Listen for incoming stop requests (vendor receives FCM)
    ref.listen<Map<String, dynamic>?>(incomingStopRequestProvider, (_, data) {
      if (data == null) return;
      _showIncomingDialog(
        context,
        stopId: data['stop_id'] as String? ?? '',
        buyerLat: data['buyer_lat'] as String? ?? '0',
        buyerLng: data['buyer_lng'] as String? ?? '0',
      );
    });

    // Listen for incoming ride requests and ride events (vendor receives FCM)
    ref.listen<Map<String, dynamic>?>(incomingRideProvider, (_, data) {
      if (data == null) return;
      final type = data['type'] as String? ?? '';
      if (type == 'ride_destination_too_far') {
        final rideId = data['ride_id'] as String? ?? '';
        final distKm = data['distance_km'] as String? ?? '?';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(incomingRideProvider.notifier).state = null;
        });
        _showRideTooFarDialog(context, rideId: rideId, distanceKm: distKm);
      } else {
        _showIncomingRideDialog(
          context,
          rideId: data['ride_id'] as String? ?? '',
          pickupLat: data['pickup_lat'] as String? ?? '0',
          pickupLng: data['pickup_lng'] as String? ?? '0',
          destinationLat: data['destination_lat'] as String? ?? '0',
          destinationLng: data['destination_lng'] as String? ?? '0',
        );
      }
    });

    ref.listen<RideEvent?>(rideEventProvider, (_, event) {
      if (event == null) return;
      if (_activeRideId != null && event.rideId != _activeRideId) return;
      if (event.type == RideEventType.cancelledByBuyer) {
        _rideSub?.cancel();
        _rideSub = null;
        setState(() {
          _activeRideId = null;
          _ridePhase = 0;
          _routePolyline = [];
          _isNavigating = false;
        });
        ref.read(rideEventProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El pasajero canceló el raite.')),
        );
      }
    });

    return Scaffold(
      drawer: const DrawerModule(),
      appBar: AppBar(
        title: const Text('UbiSafe — Vendedor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _VisibilityBadge(isVisible: _isVisible),
          ),
        ],
      ),
      floatingActionButton: _VendorSpeedDial(
        open: _speedDialOpen,
        onToggle: () => setState(() => _speedDialOpen = !_speedDialOpen),
        onRiskZone: () {
          setState(() => _speedDialOpen = false);
          _onFabPressed(positionAsync.valueOrNull);
        },
        onCommunityReport: () {
          setState(() => _speedDialOpen = false);
          _onCommunityFabPressed(positionAsync.valueOrNull);
        },
      ),
      body: positionAsync.when(
        data: (position) {
          if (position == null) return const GpsRequiredEmptyState();

          final initialCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          );

          final polylines = _routePolyline.isNotEmpty
              ? {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: _routePolyline,
                    color: AppColors.primary500,
                    width: 5,
                  ),
                }
              : <Polyline>{};

          // Load risk zones once when position is first available
          if (!_riskZonesLoaded) {
            _riskZonesLoaded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(activeRiskZonesProvider.notifier).load(
                    lat: position.latitude,
                    lng: position.longitude,
                  );
            });
          }

          // Load community reports once
          if (!_communityReportsLoaded) {
            _communityReportsLoaded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(activeCommunityReportsProvider.notifier).load(
                    lat: position.latitude,
                    lng: position.longitude,
                  );
            });
          }

          final riskCircles = riskZonesAsync.valueOrNull
                  ?.map((z) => _riskZoneToCircle(z))
                  .toSet() ??
              <Circle>{};

          final communityMarkers = (communityReportsAsync.valueOrNull ?? [])
              .where((r) =>
                  !r.isDuplicate &&
                  r.status != ReportStatus.expired &&
                  r.status != ReportStatus.dismissed)
              .map((r) => _communityReportToMarker(r, context))
              .toSet();

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: initialCamera,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                polylines: polylines,
                circles: riskCircles,
                markers: communityMarkers,
              ),
              // Visibility toggle button
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(child: _buildToggle(context, position)),
              ),
              // Confirm delivery bottom sheet when navigating to stop buyer
              if (_isNavigating && _activeRideId == null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _ConfirmDeliverySheet(
                    onConfirm: () => _confirmDelivery(context),
                  ),
                ),
              // Ride phase 1: vendor heading to pickup
              if (_ridePhase == 1)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _RideActionSheet(
                    label: 'Dirígete al punto de recogida del pasajero.',
                    buttonText: 'Llegué al punto de recogida',
                    buttonColor: AppColors.primary700,
                    onAction: () => _signalVendorArrived(context),
                  ),
                ),
              // Ride phase 2: passenger aboard
              if (_ridePhase == 2)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _RideActionSheet(
                    label: 'Pasajero a bordo. Dirígete al destino.',
                    buttonText: 'Completar raite',
                    buttonColor: AppColors.success500,
                    onAction: () => _completeRide(context),
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

  Widget _buildToggle(BuildContext context, dynamic position) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _isVisible ? AppColors.success500 : AppColors.neutral400,
        foregroundColor: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      icon: Icon(_isVisible ? Icons.visibility : Icons.visibility_off),
      label: Text(_isVisible ? 'Ahora eres Visible' : 'Activar Visibilidad'),
      onPressed: () => _onToggle(context),
    );
  }

  Future<void> _onToggle(BuildContext context) async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile?.uid == null) return;

    if (_isVisible) {
      await ref.read(gpsServiceInstanceProvider).stopTransmission(profile!.uid);
      setState(() => _isVisible = false);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Activar visibilidad'),
          content: const Text(
            '¿Deseas iniciar la transmisión de tu ubicación?\n'
            'Los compradores cercanos podrán verte en el mapa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Activar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      ref.read(gpsServiceInstanceProvider).startTransmission(profile!.uid);
      setState(() => _isVisible = true);
    }
  }

  void _showIncomingDialog(
    BuildContext context, {
    required String stopId,
    required String buyerLat,
    required String buyerLng,
  }) {
    // Clear the provider so it doesn't re-trigger on rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(incomingStopRequestProvider.notifier).state = null;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IncomingStopDialog(
        buyerLat: double.tryParse(buyerLat) ?? 0,
        buyerLng: double.tryParse(buyerLng) ?? 0,
        onAccept: () async {
          Navigator.of(context).pop();
          await _acceptStop(context, stopId, buyerLat, buyerLng);
        },
        onReject: () async {
          Navigator.of(context).pop();
          try {
            await ref.read(stopRequestModuleProvider).rejectStopRequest(stopId);
          } catch (_) {}
        },
      ),
    );
  }

  Future<void> _acceptStop(
    BuildContext context,
    String stopId,
    String buyerLatStr,
    String buyerLngStr,
  ) async {
    // GPS check before accepting
    final position = ref.read(gpsServiceProvider).valueOrNull;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('GPS no disponible. Activa el GPS para aceptar.')),
      );
      return;
    }

    try {
      await ref.read(stopRequestModuleProvider).acceptStopRequest(stopId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar: $e')),
      );
      return;
    }

    setState(() => _activeStopId = stopId);

    // Route around HIGH-risk zones using via: waypoints
    final highZones = ref
            .read(activeRiskZonesProvider)
            .valueOrNull
            ?.where((z) => z.riskLevel == RiskLevel.high)
            .toList() ??
        [];
    await _fetchRoute(
      originLat: position.latitude,
      originLng: position.longitude,
      destLat: double.tryParse(buyerLatStr) ?? 0,
      destLng: double.tryParse(buyerLngStr) ?? 0,
      avoidZones: highZones,
    );

    setState(() => _isNavigating = true);
  }

  Future<void> _fetchRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<RiskZone> avoidZones = const [],
  }) async {
    if (_kMapsApiKey.isEmpty) return;

    try {
      final dio = Dio();

      // Compute via: waypoints that steer around each HIGH-risk zone on the route
      final viaPoints = avoidZones
          .where(
        (z) => _isNearRoute(
          originLat: originLat,
          originLng: originLng,
          destLat: destLat,
          destLng: destLng,
          zoneLat: z.latitude,
          zoneLng: z.longitude,
          radiusMeters: z.radiusMeters.toDouble(),
        ),
      )
          .map((z) {
        final bypass = _bypassPoint(
          originLat: originLat,
          originLng: originLng,
          destLat: destLat,
          destLng: destLng,
          zoneLat: z.latitude,
          zoneLng: z.longitude,
          offsetMeters: z.radiusMeters + 50.0,
        );
        return 'via:${bypass.latitude},${bypass.longitude}';
      }).join('|');

      final params = <String, dynamic>{
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'key': _kMapsApiKey,
        if (viaPoints.isNotEmpty) 'waypoints': viaPoints,
      };

      final res = await dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: params,
      );
      final routes = res.data?['routes'] as List?;
      if (routes == null || routes.isEmpty) return;
      final encoded =
          (routes[0] as Map)['overview_polyline']?['points'] as String?;
      if (encoded == null) return;
      final points = _decodePolyline(encoded);
      setState(() => _routePolyline = points);
    } catch (_) {
      // Route fetch is non-critical; map still shows without polyline
    }
  }

  Future<void> _confirmDelivery(BuildContext context) async {
    final stopId = _activeStopId;
    if (stopId == null) return;
    try {
      await ref.read(stopRequestModuleProvider).completeStopRequest(stopId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al confirmar: $e')),
      );
      return;
    }
    setState(() {
      _isNavigating = false;
      _activeStopId = null;
      _routePolyline = [];
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrega confirmada. ¡Buen trabajo!'),
          backgroundColor: AppColors.success500,
        ),
      );
    }
  }

  void _showIncomingRideDialog(
    BuildContext context, {
    required String rideId,
    required String pickupLat,
    required String pickupLng,
    required String destinationLat,
    required String destinationLng,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(incomingRideProvider.notifier).state = null;
    });
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IncomingRideDialog(
        pickupLat: double.tryParse(pickupLat) ?? 0,
        pickupLng: double.tryParse(pickupLng) ?? 0,
        destinationLat: double.tryParse(destinationLat) ?? 0,
        destinationLng: double.tryParse(destinationLng) ?? 0,
        onAccept: () async {
          Navigator.of(context).pop();
          await _acceptRide(context, rideId,
              pickupLat: pickupLat, pickupLng: pickupLng);
        },
        onReject: () async {
          Navigator.of(context).pop();
          try {
            await ref.read(rideRequestModuleProvider).updateStatus(
                rideId, 'rejected',
                rejectedReason: 'vendor_rejected');
          } catch (_) {}
        },
      ),
    );
  }

  void _showRideTooFarDialog(
    BuildContext context, {
    required String rideId,
    required String distanceKm,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Destino fuera de rango'),
        content: Text(
          'El destino del pasajero está a $distanceKm km, que supera el límite de 4 km. '
          'Debes rechazar este raite.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger500,
              foregroundColor: AppColors.surface,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(rideRequestModuleProvider).updateStatus(
                    rideId, 'rejected',
                    rejectedReason: 'destination_too_far');
              } catch (_) {}
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRide(
    BuildContext context,
    String rideId, {
    required String pickupLat,
    required String pickupLng,
  }) async {
    final position = ref.read(gpsServiceProvider).valueOrNull;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('GPS no disponible. Activa el GPS para aceptar.')),
      );
      return;
    }
    try {
      await ref
          .read(rideRequestModuleProvider)
          .updateStatus(rideId, 'accepted');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar raite: $e')),
      );
      return;
    }
    setState(() {
      _activeRideId = rideId;
      _ridePhase = 1;
    });

    // Watch the ride for status changes (in_progress triggered by vendor action)
    await _rideSub?.cancel();
    _rideSub =
        ref.read(rideRequestModuleProvider).watchRide(rideId).listen((ride) {
      if (ride == null) return;
      if (ride.status == RideStatus.inProgress && _ridePhase == 1) {
        setState(() => _ridePhase = 2);
      } else if (ride.status == RideStatus.completed ||
          ride.status == RideStatus.rejected ||
          ride.status == RideStatus.expired) {
        _rideSub?.cancel();
        _rideSub = null;
        setState(() {
          _activeRideId = null;
          _ridePhase = 0;
          _routePolyline = [];
        });
      }
    });
  }

  Future<void> _signalVendorArrived(BuildContext context) async {
    final rideId = _activeRideId;
    if (rideId == null) return;
    try {
      await ref.read(rideRequestModuleProvider).vendorArrived(rideId);
      // Transition to in_progress (passenger boards)
      await ref
          .read(rideRequestModuleProvider)
          .updateStatus(rideId, 'in_progress');
      setState(() => _ridePhase = 2);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _completeRide(BuildContext context) async {
    final rideId = _activeRideId;
    if (rideId == null) return;
    try {
      await ref
          .read(rideRequestModuleProvider)
          .updateStatus(rideId, 'completed');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al completar raite: $e')),
      );
      return;
    }
    await _rideSub?.cancel();
    _rideSub = null;
    setState(() {
      _activeRideId = null;
      _ridePhase = 0;
      _routePolyline = [];
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Raite completado!'),
          backgroundColor: AppColors.success500,
        ),
      );
    }
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    super.dispose();
  }

  void _onFabPressed(dynamic position) {
    final gpsStatus = ref.read(gpsStatusProvider).valueOrNull;
    if (gpsStatus != GpsStatus.ready || position == null) {
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const GpsRequiredEmptyState(),
      );
      return;
    }
    RiskFormBottomSheet.show(
      context,
      lat: position.latitude,
      lng: position.longitude,
    );
  }

  void _onCommunityFabPressed(dynamic position) {
    final gpsStatus = ref.read(gpsStatusProvider).valueOrNull;
    if (gpsStatus != GpsStatus.ready || position == null) {
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const GpsRequiredEmptyState(),
      );
      return;
    }
    CommunityFormBottomSheet.show(
      context,
      lat: position.latitude,
      lng: position.longitude,
    );
  }

  Marker _communityReportToMarker(
      CommunityReport report, BuildContext context) {
    final hue = report.threatType == ThreatType.animalMuerto
        ? BitmapDescriptor.hueRose
        : BitmapDescriptor.hueOrange;
    final label = report.threatType == ThreatType.animalMuerto
        ? 'Animal muerto'
        : 'Zona sucia';
    final statusLabel = report.status == ReportStatus.confirmed
        ? ' · Validado'
        : ' · Pendiente';
    return Marker(
      markerId: MarkerId('cr_${report.id}'),
      position: LatLng(report.latitude, report.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(title: label, snippet: statusLabel),
      onTap: () => context.push('/community/reports/detail', extra: report),
    );
  }

  /// Returns true if [zone] is within [radiusMeters]+50 m of the route segment.
  static bool _isNearRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required double zoneLat,
    required double zoneLng,
    required double radiusMeters,
  }) {
    final dx = destLat - originLat;
    final dy = destLng - originLng;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return false;
    final t = ((zoneLat - originLat) * dx + (zoneLng - originLng) * dy) / lenSq;
    final ct = t.clamp(0.0, 1.0);
    final closestLat = originLat + ct * dx;
    final closestLng = originLng + ct * dy;
    final dLat = (zoneLat - closestLat) * 111320;
    final dLng =
        (zoneLng - closestLng) * 111320 * math.cos(zoneLat * math.pi / 180);
    return math.sqrt(dLat * dLat + dLng * dLng) <= radiusMeters + 50;
  }

  /// Returns a point perpendicular to the route, [offsetMeters] away from the zone.
  static LatLng _bypassPoint({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required double zoneLat,
    required double zoneLng,
    required double offsetMeters,
  }) {
    final dLat = destLat - originLat;
    final dLng = destLng - originLng;
    final len = math.sqrt(dLat * dLat + dLng * dLng);
    if (len == 0) return LatLng(zoneLat, zoneLng);
    // Perpendicular unit vector (rotated 90°)
    final perpLat = -dLng / len;
    final perpLng = dLat / len;
    final latOffset = offsetMeters / 111320;
    final lngOffset =
        offsetMeters / (111320 * math.cos(zoneLat * math.pi / 180));
    return LatLng(
      zoneLat + perpLat * latOffset,
      zoneLng + perpLng * lngOffset,
    );
  }

  static Circle _riskZoneToCircle(RiskZone zone) {
    final Color fill;
    final Color stroke;
    switch (zone.riskLevel) {
      case RiskLevel.high:
        fill = AppColors.danger700.withValues(alpha: 0.35);
        stroke = AppColors.danger700;
      case RiskLevel.medium:
        fill = AppColors.warning500.withValues(alpha: 0.30);
        stroke = AppColors.warning500;
      case RiskLevel.low:
        fill = AppColors.info500.withValues(alpha: 0.25);
        stroke = AppColors.info500;
    }
    return Circle(
      circleId: CircleId(zone.id),
      center: LatLng(zone.latitude, zone.longitude),
      radius: zone.radiusMeters.toDouble(),
      fillColor: fill,
      strokeColor: stroke,
      strokeWidth: 2,
    );
  }
}

// ── SpeedDial FAB — CU-03 + CU-05 (vendor map) ───────────────────────────────
class _VendorSpeedDial extends StatelessWidget {
  const _VendorSpeedDial({
    required this.open,
    required this.onToggle,
    required this.onRiskZone,
    required this.onCommunityReport,
  });

  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onRiskZone;
  final VoidCallback onCommunityReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open) ...[
          _VendorMiniAction(
            icon: Icons.coronavirus_outlined,
            label: 'Foco de infección',
            color: const Color(0xFF795548),
            onTap: onCommunityReport,
          ),
          const SizedBox(height: 8),
          _VendorMiniAction(
            icon: Icons.shield_outlined,
            label: 'Zona de riesgo',
            color: AppColors.warning700,
            onTap: onRiskZone,
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          backgroundColor: AppColors.warning700,
          foregroundColor: AppColors.surface,
          onPressed: onToggle,
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _VendorMiniAction extends StatelessWidget {
  const _VendorMiniAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
              )
            ],
          ),
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: 'vendor_$label',
          backgroundColor: color,
          foregroundColor: AppColors.surface,
          onPressed: onTap,
          child: Icon(icon),
        ),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Decodes a Google Maps encoded polyline string to a list of LatLng points.
List<LatLng> _decodePolyline(String encoded) {
  final result = <LatLng>[];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int shift = 0;
    int result0 = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result0 |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);

    shift = 0;
    result0 = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result0 |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);

    result.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return result;
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.isVisible});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success500,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Visible',
        style: TextStyle(color: AppColors.surface, fontSize: 12),
      ),
    );
  }
}

class _IncomingStopDialog extends StatelessWidget {
  const _IncomingStopDialog({
    required this.buyerLat,
    required this.buyerLng,
    required this.onAccept,
    required this.onReject,
  });

  final double buyerLat;
  final double buyerLng;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva solicitud de parada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Un comprador cercano solicita que te detengas.'),
          const SizedBox(height: 8),
          Text(
            'Ubicación: ${buyerLat.toStringAsFixed(4)}, ${buyerLng.toStringAsFixed(4)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger500),
          onPressed: onReject,
          child: const Text('Rechazar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary700,
            foregroundColor: AppColors.surface,
          ),
          onPressed: onAccept,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

class _ConfirmDeliverySheet extends StatelessWidget {
  const _ConfirmDeliverySheet({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
          const Text(
            'Ruta activa',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dirígete hacia el comprador y confirma la entrega cuando llegues.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success500,
              foregroundColor: AppColors.surface,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onConfirm,
            child: const Text('Confirmar Entrega'),
          ),
        ],
      ),
    );
  }
}

class _IncomingRideDialog extends StatelessWidget {
  const _IncomingRideDialog({
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.onAccept,
    required this.onReject,
  });

  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva solicitud de raite'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Un pasajero quiere un raite a:'),
          const SizedBox(height: 8),
          Text(
            'Recogida: ${pickupLat.toStringAsFixed(4)}, ${pickupLng.toStringAsFixed(4)}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            'Destino: ${destinationLat.toStringAsFixed(4)}, ${destinationLng.toStringAsFixed(4)}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger500),
          onPressed: onReject,
          child: const Text('Rechazar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success500,
            foregroundColor: AppColors.surface,
          ),
          onPressed: onAccept,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

class _RideActionSheet extends StatelessWidget {
  const _RideActionSheet({
    required this.label,
    required this.buttonText,
    required this.buttonColor,
    required this.onAction,
  });

  final String label;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
          const Icon(Icons.electric_rickshaw_outlined, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: AppColors.surface,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onAction,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
