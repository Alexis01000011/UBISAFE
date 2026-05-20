import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design_system/colors.dart';
import '../../community/models/community_report.dart';
import '../../community/screens/community_form_bottom_sheet.dart';
import '../../community/services/community_report_module.dart';
import '../../identity/profile/widgets/drawer_module.dart';
import '../../presence/services/gps_service.dart';
import '../../presence/models/vendor_marker.dart';
import '../../presence/services/vendor_tracker.dart';
import '../../safety/models/risk_zone.dart';
import '../../safety/screens/risk_form_bottom_sheet.dart';
import '../../safety/services/risk_zone_service.dart';
import '../../shared/notifications/notification_handler.dart';
import '../../shared/widgets/gps_required_empty_state.dart';
import '../models/stop_request.dart';
import '../services/ride_request_module.dart';
import '../services/stop_request_module.dart';
import '../widgets/destination_picker.dart';

enum _BuyerMapState { idle, waiting, waitingRide }

/// Main map screen for buyers — vendor markers, stop-request flow (CU-01).
class MapScreenBuyer extends ConsumerStatefulWidget {
  const MapScreenBuyer({super.key});

  @override
  ConsumerState<MapScreenBuyer> createState() => _MapScreenBuyerState();
}

class _MapScreenBuyerState extends ConsumerState<MapScreenBuyer> {
  _BuyerMapState _mapState = _BuyerMapState.idle;
  String? _activeStopId;
  String? _activeRideId;
  String? _activeVendorUid;
  bool _communityReportsLoaded = false;
  bool _speedDialOpen = false;
  bool _selectingRiskPoint = false;
  final Map<String, BitmapDescriptor> _markerIconCache = {};
  Position? _riskZoneAnchorPos;

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(gpsServiceProvider);
    ref.watch(locationSyncProvider);
    final vendorsAsync = ref.watch(vendorMarkersProvider);
    final communityReportsAsync = ref.watch(activeCommunityReportsProvider);

    // Re-subscribe the risk zones stream when the user moves >500 m from the
    // position that was captured when the stream was last built (frozen closure fix).
    ref.listen(gpsServiceProvider, (_, next) {
      final current = next.valueOrNull;
      if (current == null) return;
      final anchor = _riskZoneAnchorPos;
      if (anchor == null) {
        _riskZoneAnchorPos = current;
        // Provider may have been built while GPS was null → re-subscribe now.
        ref.invalidate(activeRiskZonesProvider);
        return;
      }
      if (Geolocator.distanceBetween(
            anchor.latitude, anchor.longitude,
            current.latitude, current.longitude,
          ) >
          500) {
        _riskZoneAnchorPos = current;
        ref.invalidate(activeRiskZonesProvider);
      }
    });

    // Listen for FCM events (accepted/rejected/expired)
    ref.listen<StopEvent?>(stopRequestEventProvider, (_, event) {
      if (event == null) return;
      if (_activeStopId != null && event.stopId != _activeStopId) return;

      if (event.status == StopRequestStatus.accepted) {
        // Guard: if the local 60-s timer already fired (_mapState went to idle
        // via onExpired), a late-arriving accepted FCM must be discarded.
        // Without this check _activeStopId is null and the guard at line 51
        // never filters it out, causing the buyer to navigate to /tracking
        // even after the stop was locally expired (B-new).
        if (_mapState != _BuyerMapState.waiting) {
          ref.read(stopRequestEventProvider.notifier).state = null;
          return;
        }
        ref.read(stopRequestModuleProvider).cancelTimer();
        setState(() {
          _mapState = _BuyerMapState.idle;
          _activeStopId = null;
          _activeVendorUid = null;
        });
        ref.read(stopRequestEventProvider.notifier).state = null;
        if (!context.mounted) return;
        context.push('/tracking?stop_id=${event.stopId}');
      } else if (event.status == StopRequestStatus.rejected) {
        setState(() {
          _mapState = _BuyerMapState.idle;
          _activeStopId = null;
          _activeVendorUid = null;
        });
        ref.read(stopRequestEventProvider.notifier).state = null;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El vendedor no pudo atenderte.')),
        );
      } else if (event.status == StopRequestStatus.expired) {
        // B06: limpiar el provider primero; si el timer local ya procesó el
        // evento (_mapState ya es idle), salir sin mostrar un segundo SnackBar.
        ref.read(stopRequestEventProvider.notifier).state = null;
        if (_mapState == _BuyerMapState.idle) return;
        setState(() {
          _mapState = _BuyerMapState.idle;
          _activeStopId = null;
          _activeVendorUid = null;
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiempo de espera agotado.')),
        );
      } else if (event.status == StopRequestStatus.abandoned) {
        ref.read(stopRequestEventProvider.notifier).state = null;
        // Si el comprador está en TrackingScreen, ese listener ya maneja el pop.
        if (_mapState == _BuyerMapState.idle) return;
        ref.read(stopRequestModuleProvider).cancelTimer();
        setState(() {
          _mapState = _BuyerMapState.idle;
          _activeStopId = null;
          _activeVendorUid = null;
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El vendedor abandonó la aplicación.')),
        );
      }
    });

    // Listen for ride FCM events (accepted/rejected/expired/vendor_arrived)
    ref.listen<RideEvent?>(rideEventProvider, (_, event) {
      if (event == null) return;
      if (_activeRideId != null && event.rideId != _activeRideId) return;
      switch (event.type) {
        case RideEventType.accepted:
          ref.read(rideRequestModuleProvider).cancelExpiryTimer();
          final rideId = _activeRideId;
          setState(() {
            _mapState = _BuyerMapState.idle;
            _activeRideId = null;
          });
          ref.read(rideEventProvider.notifier).state = null;
          if (rideId != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('¡El vendedor aceptó tu raite! Se está acercando.')),
            );
          }
        case RideEventType.rejected:
        case RideEventType.expired:
          ref.read(rideRequestModuleProvider).cancelExpiryTimer();
          setState(() {
            _mapState = _BuyerMapState.idle;
            _activeRideId = null;
          });
          ref.read(rideEventProvider.notifier).state = null;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                event.type == RideEventType.expired
                    ? 'Tiempo agotado. El vendedor no respondió.'
                    : 'El vendedor no pudo llevarte.',
              ),
            ),
          );
        case RideEventType.vendorArrived:
          ref.read(rideEventProvider.notifier).state = null;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡El vendedor llegó al punto de recogida!'),
              backgroundColor: AppColors.success500,
            ),
          );
        case RideEventType.completed:
          setState(() {
            _mapState = _BuyerMapState.idle;
            _activeRideId = null;
          });
          ref.read(rideEventProvider.notifier).state = null;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Raite completado! Que te vaya bien.'),
              backgroundColor: AppColors.success500,
            ),
          );
        case RideEventType.cancelledByBuyer:
          break;
        case RideEventType.abandoned:
          ref.read(rideRequestModuleProvider).cancelExpiryTimer();
          setState(() {
            _mapState = _BuyerMapState.idle;
            _activeRideId = null;
          });
          ref.read(rideEventProvider.notifier).state = null;
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El vendedor abandonó la aplicación.'),
            ),
          );
      }
    });

    // Notifica al comprador cuando el vendedor que está esperando pierde conexión.
    // Detecta desaparición de vendorMarkersProvider en lugar de depender de
    // vendorOfflineEventProvider (que requiere que onDisconnect.update ejecute
    // en RTDB — no garantizado en el emulador si el nodo se elimina directamente).
    ref.listen<AsyncValue<List<VendorMarker>>>(vendorMarkersProvider, (prev, next) {
      final uid = _activeVendorUid;
      if (uid == null || _mapState != _BuyerMapState.waiting) return;
      final wasVisible = prev?.valueOrNull?.any((v) => v.uid == uid) ?? false;
      final isVisible = next.valueOrNull?.any((v) => v.uid == uid) ?? false;
      if (wasVisible && !isVisible) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El seguimiento en tiempo real se ha pausado.'),
            duration: Duration(seconds: 6),
          ),
        );
      }
    });

    return Scaffold(
      drawer: const DrawerModule(),
      appBar: AppBar(title: const Text('UbiSafe — Mapa')),
      floatingActionButton: _SpeedDial(
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

          final markers = vendorsAsync.maybeWhen(
            data: (vendors) {
              final missing = vendors
                  .where((v) => !_markerIconCache.containsKey(v.product ?? ''))
                  .toList();
              if (missing.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _buildMissingIcons(vendors));
              }
              return vendors
                  .map(
                    (v) => Marker(
                      markerId: MarkerId(v.uid),
                      position: LatLng(v.latitude, v.longitude),
                      icon: _markerIconCache[v.product ?? ''] ??
                          BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen),
                      onTap: () => _onVendorTap(
                        context,
                        vendorUid: v.uid,
                        rideEnabled: v.rideEnabled,
                        buyerLat: position.latitude,
                        buyerLng: position.longitude,
                      ),
                    ),
                  )
                  .toSet();
            },
            orElse: () => <Marker>{},
          );

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

          final zonesAsync = ref.watch(activeRiskZonesProvider);
          final circles = zonesAsync.maybeWhen(
            data: (zones) => zones
                .map(
                  (z) => Circle(
                    circleId: CircleId(z.id),
                    center: LatLng(z.latitude, z.longitude),
                    radius: z.radiusMeters.toDouble(),
                    fillColor: _riskFillColor(z.riskLevel),
                    strokeColor: _riskStrokeColor(z.riskLevel),
                    strokeWidth: 2,
                  ),
                )
                .toSet(),
            orElse: () => <Circle>{},
          );

          // Community report markers: skip duplicates (grouped under canonical pin)
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
                markers: markers.union(communityMarkers),
                circles: circles,
                onTap: _onMapTap,
              ),
              if (_mapState == _BuyerMapState.waiting)
                _WaitingOverlay(
                  label: 'Esperando respuesta del vendedor…',
                  onCancel: () async {
                    final stopId = _activeStopId;
                    if (stopId == null) return;
                    // Cancel the local 60-s timer BEFORE changing state so the
                    // timer callback cannot fire and show a stale "timed out"
                    // snackbar after the user explicitly cancelled (BUG-A).
                    ref.read(stopRequestModuleProvider).cancelTimer();
                    setState(() {
                      _mapState = _BuyerMapState.idle;
                      _activeStopId = null;
                      _activeVendorUid = null;
                    });
                    try {
                      await ref
                          .read(stopRequestModuleProvider)
                          .cancelStopRequest(stopId);
                    } catch (_) {}
                  },
                ),
              if (_mapState == _BuyerMapState.waitingRide)
                _WaitingOverlay(
                  label: 'Esperando que el vendedor acepte tu raite…',
                  onCancel: () async {
                    final rideId = _activeRideId;
                    ref.read(rideRequestModuleProvider).cancelExpiryTimer();
                    setState(() {
                      _mapState = _BuyerMapState.idle;
                      _activeRideId = null;
                    });
                    if (rideId != null) {
                      try {
                        await ref.read(rideRequestModuleProvider).updateStatus(
                            rideId, 'cancelled');
                      } catch (_) {}
                    }
                  },
                ),
              // Instruction banner while user selects a risk zone point
              if (_selectingRiskPoint)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _RiskPointSelectionBanner(
                    onCancel: () =>
                        setState(() => _selectingRiskPoint = false),
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

  Future<void> _buildMissingIcons(List<VendorMarker> vendors) async {
    bool changed = false;
    for (final v in vendors) {
      final key = v.product ?? '';
      if (_markerIconCache.containsKey(key)) continue;
      final icon = await _buildVendorIcon(v.product);
      if (!mounted) return;
      _markerIconCache[key] = icon;
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  // Paints a rounded-rect label (when product is set) above a circle pin.
  // Rendered at 2× resolution so it looks sharp on high-DPI screens
  // (google_maps_flutter 2.5.x lacks imagePixelRatio on fromBytes).
  static Future<BitmapDescriptor> _buildVendorIcon(String? product) async {
    const double s = 2.0; // scale factor
    const double pinR = 18.0 * s;
    const double padH = 8.0 * s;
    const double padV = 4.0 * s;
    const double gap = 4.0 * s;

    TextPainter? tp;
    if (product != null && product.isNotEmpty) {
      tp = TextPainter(
        text: TextSpan(
          text: product,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0 * s,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 140.0 * s);
    }

    final labelH = tp != null ? tp.height + padV * 2 : 0.0;
    final labelW = tp != null ? tp.width + padH * 2 : 0.0;
    final bitmapW = labelW > pinR * 2 ? labelW : pinR * 2;
    final bitmapH = labelH + (tp != null ? gap : 0) + pinR * 2;
    final cx = bitmapW / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    double y = 0;

    if (tp != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - labelW / 2, 0, labelW, labelH),
          const Radius.circular(8.0 * s),
        ),
        Paint()..color = const Color(0xFF1B5E20),
      );
      tp.paint(canvas, Offset(cx - tp.width / 2, padV));
      y = labelH + gap;
    }

    canvas.drawCircle(
      Offset(cx, y + pinR),
      pinR,
      Paint()..color = const Color(0xFF2E7D32),
    );
    canvas.drawCircle(
      Offset(cx, y + pinR),
      pinR * 0.35,
      Paint()..color = Colors.white,
    );

    final img = await recorder
        .endRecording()
        .toImage(bitmapW.ceil(), bitmapH.ceil());
    final bytes =
        (await img.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
    return BitmapDescriptor.bytes(bytes, imagePixelRatio: 2.0);
  }

  Future<void> _onVendorTap(
    BuildContext context, {
    required String vendorUid,
    required bool rideEnabled,
    required double buyerLat,
    required double buyerLng,
  }) async {
    if (_mapState != _BuyerMapState.idle) return;

    // Block any request when the buyer is inside a HIGH risk zone (SDD §8.3.A).
    // Use the cached provider value — if zones haven't loaded yet, allow through.
    final zones = ref.read(activeRiskZonesProvider).valueOrNull;
    if (zones != null) {
      final inHighZone = zones.any((RiskZone z) =>
          z.riskLevel == 'HIGH' &&
          Geolocator.distanceBetween(
                buyerLat, buyerLng, z.latitude, z.longitude) <=
              z.radiusMeters);
      if (inHighZone) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No puedes solicitar desde una zona de alto riesgo.',
            ),
          ),
        );
        return;
      }
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _VendorBottomSheet(
        vendorUid: vendorUid,
        rideEnabled: rideEnabled,
      ),
    );

    if (result == null || !context.mounted) return;

    if (result == 'stop') {
      await _requestStop(context,
          vendorUid: vendorUid, buyerLat: buyerLat, buyerLng: buyerLng);
    } else if (result == 'ride') {
      await _requestRide(context,
          vendorUid: vendorUid, buyerLat: buyerLat, buyerLng: buyerLng);
    }
  }

  Future<void> _requestStop(
    BuildContext context, {
    required String vendorUid,
    required double buyerLat,
    required double buyerLng,
  }) async {
    setState(() => _mapState = _BuyerMapState.waiting);
    _activeVendorUid = vendorUid;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final stop = await ref.read(stopRequestModuleProvider).createStopRequest(
            vendorUid: vendorUid,
            buyerLat: buyerLat,
            buyerLng: buyerLng,
          );
      _activeStopId = stop.id;
      ref.read(activeStopProvider.notifier).set(stop);
      ref.read(stopRequestModuleProvider).startTimer(
        stop.id,
        onExpired: () {
          if (!mounted) return;
          setState(() {
            _mapState = _BuyerMapState.idle;
            _activeStopId = null;
            _activeVendorUid = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tiempo de espera agotado.')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mapState = _BuyerMapState.idle;
        _activeVendorUid = null;
      });
      String msg = 'Error al solicitar parada. Intenta de nuevo.';
      if (e is DioException && e.response?.statusCode == 409) {
        final detail =
            (e.response?.data as Map<String, dynamic>?)?['detail'] as String?;
        if (detail == 'vendor_not_available') {
          msg = 'El vendedor está atendiendo otra solicitud.';
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _requestRide(
    BuildContext context, {
    required String vendorUid,
    required double buyerLat,
    required double buyerLng,
  }) async {
    if (!context.mounted) return;
    final destination = await DestinationPicker.show(
      context,
      LatLng(buyerLat, buyerLng),
    );
    if (destination == null || !context.mounted) return;

    setState(() => _mapState = _BuyerMapState.waitingRide);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ride = await ref.read(rideRequestModuleProvider).createRide(
            vendorUid: vendorUid,
            pickupLat: buyerLat,
            pickupLng: buyerLng,
            destinationLat: destination.latitude,
            destinationLng: destination.longitude,
          );
      _activeRideId = ride.id;
      ref.read(rideRequestModuleProvider).startExpiryTimer(
        ride.id,
        onExpired: () {
          if (!mounted) return;
          setState(() {
            _mapState = _BuyerMapState.idle;
            _activeRideId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Tiempo agotado. El vendedor no respondió.')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _mapState = _BuyerMapState.idle);
      String msg = 'Error al solicitar raite. Intenta de nuevo.';
      if (e is DioException && e.response?.statusCode == 409) {
        final detail =
            (e.response?.data as Map<String, dynamic>?)?['detail'] as String?;
        if (detail == 'vendor_ride_disabled') {
          msg = 'El vendedor tiene el servicio de raite desactivado.';
        } else if (detail == 'vendor_not_available') {
          msg = 'El vendedor está atendiendo otra solicitud.';
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _onFabPressed(dynamic position) {
    if (position == null) {
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const GpsRequiredEmptyState(),
      );
      return;
    }
    setState(() => _selectingRiskPoint = true);
  }

  Future<void> _onMapTap(LatLng point) async {
    if (!_selectingRiskPoint) return;
    setState(() => _selectingRiskPoint = false);

    final currentPosition = ref.read(gpsServiceProvider).valueOrNull;
    if (currentPosition != null) {
      final distanceMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        point.latitude,
        point.longitude,
      );
      if (distanceMeters > 4000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Solo puedes reportar zonas dentro de un radio de 4 km desde tu ubicación.',
              ),
            ),
          );
        }
        return;
      }
    }

    final submitted = await RiskFormBottomSheet.show(context, point);
    if (submitted && mounted) {
      ref.invalidate(activeRiskZonesProvider);
    }
  }

  void _onCommunityFabPressed(dynamic position) {
    if (position == null) {
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

  // Flujo 9.6.C: duplicates are hidden; canonical pin opens ReportDetailScreen.
  Marker _communityReportToMarker(
      CommunityReport report, BuildContext context) {
    final hue = report.threatType == ThreatType.animalMuerto
        ? BitmapDescriptor.hueRose // closest to black in Maps SDK hues
        : BitmapDescriptor.hueOrange; // café approximation
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

}

// ── Risk point selection banner ───────────────────────────────────────────────

class _RiskPointSelectionBanner extends StatelessWidget {
  const _RiskPointSelectionBanner({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xE6F57C00), // warning amber with ~90% opacity
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.touch_app, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Toca el mapa para marcar la zona de riesgo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SpeedDial FAB — CU-03 + CU-05 ───────────────────
class _SpeedDial extends StatelessWidget {
  const _SpeedDial({
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
          _MiniAction(
            icon: Icons.coronavirus_outlined,
            label: 'Foco de infección',
            color: const Color(0xFF795548),
            onTap: onCommunityReport,
          ),
          const SizedBox(height: 8),
          _MiniAction(
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

class _MiniAction extends StatelessWidget {
  const _MiniAction({
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
          heroTag: label,
          backgroundColor: color,
          foregroundColor: AppColors.surface,
          onPressed: onTap,
          child: Icon(icon),
        ),
      ],
    );
  }
}

// ─── Risk zone color helpers ──────────────────────────────────────────────────

Color _riskFillColor(String level) => switch (level) {
      'HIGH' => const Color(0x59C62828),
      'MEDIUM' => const Color(0x4DF57C00),
      _ => const Color(0x400277BD),
    };

Color _riskStrokeColor(String level) => switch (level) {
      'HIGH' => const Color(0xFFC62828),
      'MEDIUM' => const Color(0xFFF57C00),
      _ => const Color(0xFF0277BD),
    };

// ─────────────────────────────────────────────────────────────────────────────

class _WaitingOverlay extends StatelessWidget {
  const _WaitingOverlay({required this.onCancel, required this.label});

  final VoidCallback onCancel;
  final String label;

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
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
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
  const _VendorBottomSheet(
      {required this.vendorUid, required this.rideEnabled});

  final String vendorUid;
  final bool rideEnabled;

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
            'Vendedor cercano',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige qué tipo de servicio quieres solicitar.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary700,
              foregroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.pan_tool_outlined),
            label: const Text('Solicitar Parada'),
            onPressed: () => Navigator.of(context).pop('stop'),
          ),
          if (rideEnabled) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success500,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.electric_rickshaw_outlined),
              label: const Text('Solicitar Raite'),
              onPressed: () => Navigator.of(context).pop('ride'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
