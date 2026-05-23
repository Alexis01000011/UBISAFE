import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/design_system/colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../identity/auth/auth_module.dart';
import '../../community/models/community_report.dart';
import '../../community/screens/community_form_bottom_sheet.dart';
import '../../community/screens/lot_form_bottom_sheet.dart';
import '../../community/screens/lot_location_picker_sheet.dart';
import '../../community/services/community_report_module.dart';
import '../../identity/profile/widgets/drawer_module.dart';
import '../../presence/services/gps_service.dart';
import '../../safety/models/risk_zone.dart';
import '../../safety/screens/risk_form_bottom_sheet.dart';
import '../../safety/services/risk_zone_service.dart';
import '../../shared/notifications/notification_handler.dart';
import '../../shared/widgets/gps_required_empty_state.dart';
import '../group_stays/models/group_stay.dart';
import '../group_stays/services/group_stay_module.dart';
import '../models/ride.dart';
import '../models/stop_request.dart';
import '../services/ride_request_module.dart';
import '../services/stop_request_module.dart';

/// Main map screen for vendors — GPS visibility toggle + CU-01 responder.
class MapScreenVendor extends ConsumerStatefulWidget {
  const MapScreenVendor({super.key});

  @override
  ConsumerState<MapScreenVendor> createState() => _MapScreenVendorState();
}

class _MapScreenVendorState extends ConsumerState<MapScreenVendor>
    with WidgetsBindingObserver {
  bool _isVisible = false;
  bool _isNavigating = false;
  bool _communityReportsLoaded = false;
  bool _groupStaysLoaded = false;
  bool _speedDialOpen = false;
  String _mapsApiKey = '';
  String? _activeStopId;
  String? _pendingDialogStopId; // stopId del diálogo accept/reject actualmente abierto
  String? _pendingDialogRideId; // rideId del diálogo incoming ride actualmente abierto
  double? _buyerLat; // Coordenadas del comprador de la parada activa
  double? _buyerLng;
  String? _activeRideId;
  double? _ridePickupLat;
  double? _ridePickupLng;
  double? _rideDestLat;
  double? _rideDestLng;
  bool _selectingRiskPoint = false;
  // 1 = going to pickup, 2 = ride in progress (passenger aboard)
  int _ridePhase = 0;
  Position? _riskZoneAnchorPos;
  BitmapDescriptor? _zoneTapIcon;
  List<LatLng> _routePolyline = [];

  StreamSubscription<Ride?>? _rideSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initMapsKey();
    _buildZoneTapIcon().then((icon) {
      if (mounted) setState(() => _zoneTapIcon = icon);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isVisible) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final gps = ref.read(gpsServiceInstanceProvider);
    if (state == AppLifecycleState.paused) {
      // Abandon any active stop/ride before going to background.
      final stopId = _activeStopId;
      final rideId = _activeRideId;
      if (stopId != null) {
        if (mounted) {
          setState(() {
            _activeStopId = null;
            _isNavigating = false;
            _routePolyline = [];
            _buyerLat = null;
            _buyerLng = null;
          });
        }
        unawaited(
          ref
              .read(stopRequestModuleProvider)
              .abandonStopRequest(stopId)
              .timeout(const Duration(seconds: 3))
              .catchError((_) {}),
        );
      }
      if (rideId != null) {
        _rideSub?.cancel();
        _rideSub = null;
        if (mounted) {
          setState(() {
            _activeRideId = null;
            _ridePhase = 0;
            _routePolyline = [];
            _isNavigating = false;
            _ridePickupLat = null;
            _ridePickupLng = null;
            _rideDestLat = null;
            _rideDestLng = null;
          });
        }
        unawaited(
          ref
              .read(rideRequestModuleProvider)
              .abandonRide(rideId)
              .timeout(const Duration(seconds: 3))
              .catchError((_) {}),
        );
      }
      // Remove RTDB node so buyers see vendor as offline.
      gps.stopTransmission(uid);
      // Reset radar flag so CF fires correctly on next activation (B1-fix).
      unawaited(
        ref.read(apiClientProvider)
            .patch<dynamic>('/auth/radar-status', data: {'is_active_radar': false})
            .then<void>((_) {}, onError: (_) {}),
      );
    } else if (state == AppLifecycleState.resumed) {
      // App returned to foreground — re-start transmission.
      final profile = ref.read(userProfileProvider).valueOrNull;
      gps.startTransmission(
        uid,
        rideEnabled: profile?.rideEnabled ?? false,
        product: profile?.product,
      );
      // Restore radar flag so CF proximity trigger fires correctly on resume.
      unawaited(
        ref.read(apiClientProvider)
            .patch<dynamic>('/auth/radar-status', data: {'is_active_radar': true})
            .then<void>((_) {}, onError: (_) {}),
      );
    }
  }

  Future<void> _initMapsKey() async {
    try {
      const ch = MethodChannel('ubisafe/config');
      final key = await ch.invokeMethod<String>('getMapsApiKey') ?? '';
      if (mounted) setState(() => _mapsApiKey = key);
    } catch (_) {
      // Falla silenciosamente en tests o si el channel no está disponible
    }
  }

  @override
  Widget build(BuildContext context) {
    final positionAsync = ref.watch(gpsServiceProvider);
    ref.watch(locationSyncProvider);
    ref.watch(authStateProvider); // pre-subscribe so ref.read in _onToggle is synchronous

    // Re-subscribe the risk zones stream when the vendor moves >500 m from the
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

    // Timing fix: if startTransmission was called before userProfileProvider
    // completed, _product was null and the field wasn't written to RTDB.
    // This listener fires when the profile loads and patches the node immediately.
    ref.listen(userProfileProvider, (_, next) {
      final product = next.valueOrNull?.product;
      if (product == null) return;
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;
      final gps = ref.read(gpsServiceInstanceProvider);
      if (gps.activeUid == uid) gps.updateProduct(uid, product);
    });

    final communityReportsAsync = ref.watch(activeCommunityReportsProvider);
    final groupStaysAsync = ref.watch(activeGroupStaysProvider);

    // Show visible SnackBar when a new community report is created within 1 km.
    ref.listen<Map<String, dynamic>?>(communityReportAlertProvider, (_, alert) {
      if (alert == null || !context.mounted) return;
      final reportLat = double.tryParse(alert['lat'] as String? ?? '');
      final reportLng = double.tryParse(alert['lng'] as String? ?? '');
      final threatType = alert['threat_type'] as String? ?? '';
      final typeLabel =
          threatType == 'animal_muerto' ? 'Animal muerto' : 'Zona sucia';

      final position = ref.read(gpsServiceProvider).valueOrNull;
      String distanceLabel = '';
      if (position != null && reportLat != null && reportLng != null) {
        final distM = Geolocator.distanceBetween(
          position.latitude, position.longitude, reportLat, reportLng,
        );
        distanceLabel = ' a ${distM.round()} m';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reporte avistado$distanceLabel — $typeLabel'),
          backgroundColor: const Color(0xFF795548),
          duration: const Duration(seconds: 5),
        ),
      );
    });

    // Remove stay marker and notify vendor when one of their group stays is cancelled (CU-09-D).
    ref.listen<Map<String, dynamic>?>(groupStayCancelledProvider, (_, data) {
      if (data == null || !context.mounted) return;
      final reason = data['reason'] as String? ?? '';
      final msg = reason == 'risk_zone_high'
          ? 'Una estancia grupal fue cancelada por zona de riesgo alta.'
          : 'Una estancia grupal fue cancelada.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
      );
    });

    // Listen for incoming stop requests (vendor receives FCM)
    ref.listen<Map<String, dynamic>?>(incomingStopRequestProvider, (_, data) {
      if (data == null) return;
      if (!context.mounted) return;
      // If vendor already accepted a stop or ride, reject silently and inform.
      if (_activeStopId != null || _activeRideId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(incomingStopRequestProvider.notifier).state = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya tienes una solicitud activa. No puedes aceptar más.'),
          ),
        );
        return;
      }
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
      // If vendor already accepted a stop or ride, reject silently and inform.
      if (type != 'ride_destination_too_far' && (_activeStopId != null || _activeRideId != null)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(incomingRideProvider.notifier).state = null;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya tienes una solicitud activa. No puedes aceptar más.'),
            ),
          );
        }
        return;
      }
      if (type == 'ride_destination_too_far') {
        final rideId = data['ride_id'] as String? ?? '';
        final distKm = data['distance_km'] as String? ?? '?';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(incomingRideProvider.notifier).state = null;
        });
        if (!context.mounted) return;
        _showRideTooFarDialog(context, rideId: rideId, distanceKm: distKm);
      } else {
        if (!context.mounted) return;
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

    ref.listen<StopEvent?>(stopRequestEventProvider, (_, event) {
      if (event == null) return;
      final isCancelled = event.status == StopRequestStatus.cancelled;
      final isExpired = event.status == StopRequestStatus.expired;
      if (!isCancelled && !isExpired) return;

      ref.read(stopRequestEventProvider.notifier).state = null;

      // Cerrar diálogo accept/reject si está abierto para esta parada
      if (_pendingDialogStopId == event.stopId && context.mounted) {
        setState(() => _pendingDialogStopId = null);
        Navigator.of(context).pop();
      }

      // Limpiar estado de entrega en curso si corresponde a esta parada
      if (_activeStopId == event.stopId) {
        setState(() {
          _activeStopId = null;
          _isNavigating = false;
          _routePolyline = [];
          _buyerLat = null;
          _buyerLng = null;
        });
      }

      if (!context.mounted) return;
      final message = isCancelled
          ? 'El comprador canceló la parada.'
          : 'La solicitud de parada expiró sin respuesta.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });

    ref.listen<RideEvent?>(rideEventProvider, (_, event) {
      if (event == null) return;
      if (_activeRideId == null && event.rideId != _pendingDialogRideId) return;
      if (_activeRideId != null && event.rideId != _activeRideId) return;
      if (event.type == RideEventType.cancelledByBuyer) {
        // Dismiss incoming ride dialog if it's still open for this ride
        if (_pendingDialogRideId == event.rideId && context.mounted) {
          setState(() => _pendingDialogRideId = null);
          Navigator.of(context).pop();
        }
        _rideSub?.cancel();
        _rideSub = null;
        setState(() {
          _activeRideId = null;
          _ridePhase = 0;
          _routePolyline = [];
          _isNavigating = false;
          _ridePickupLat = null;
          _ridePickupLng = null;
          _rideDestLat = null;
          _rideDestLng = null;
        });
        ref.read(rideEventProvider.notifier).state = null;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El pasajero canceló el raite.')),
        );
      }
      if (event.type == RideEventType.expired) {
        if (_pendingDialogRideId == event.rideId && context.mounted) {
          setState(() => _pendingDialogRideId = null);
          Navigator.of(context).pop();
        }
        _rideSub?.cancel();
        _rideSub = null;
        setState(() {
          _activeRideId = null;
          _ridePhase = 0;
          _routePolyline = [];
          _isNavigating = false;
          _ridePickupLat = null;
          _ridePickupLng = null;
          _rideDestLat = null;
          _rideDestLng = null;
        });
        ref.read(rideEventProvider.notifier).state = null;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La solicitud de raite expiró.')),
        );
      }
    });

    return Scaffold(
      drawer: DrawerModule(onSignOut: _handleSignOut),
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
        onLotReport: () {
          setState(() => _speedDialOpen = false);
          _onLotFabPressed(positionAsync.valueOrNull);
        },
        onScheduleStay: () {
          setState(() => _speedDialOpen = false);
          context.push('/group-stays/schedule');
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

          // Load active group stays once
          if (!_groupStaysLoaded) {
            _groupStaysLoaded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(activeGroupStaysProvider.notifier).load(
                    position.latitude,
                    position.longitude,
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

          // Invisible markers superimposed on each zone circle for tap detection
          // (Circle has no onTap — Option A from design doc).
          final zoneMarkers = _zoneTapIcon == null
              ? <Marker>{}
              : zonesAsync.maybeWhen(
                  data: (zones) => zones
                      .map(
                        (z) => Marker(
                          markerId: MarkerId('zt_${z.id}'),
                          position: LatLng(z.latitude, z.longitude),
                          icon: _zoneTapIcon!,
                          anchor: const Offset(0.5, 0.5),
                          onTap: () => context.push(
                            '/safety/risk-zones/detail',
                            extra: z,
                          ),
                        ),
                      )
                      .toSet(),
                  orElse: () => <Marker>{},
                );

          final communityMarkers = (communityReportsAsync.valueOrNull ?? [])
              .where((r) =>
                  !r.isDuplicate &&
                  r.status != ReportStatus.expired &&
                  r.status != ReportStatus.dismissed &&
                  r.status != ReportStatus.resolved)
              .map((r) => _communityReportToMarker(r, context))
              .toSet();

          // Group stay markers
          final stayMarkers = (groupStaysAsync.valueOrNull ?? [])
              .map((s) => _groupStayToMarker(s, context))
              .toSet();

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: initialCamera,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                polylines: polylines,
                circles: circles,
                markers: communityMarkers.union(stayMarkers).union(zoneMarkers),
                onTap: _onMapTap,
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
    // Use the uid from authStateProvider directly — it is always available
    // while the user is authenticated, unlike userProfileProvider which may
    // be loading or null if a re-evaluation is in flight.
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    if (_isVisible) {
      await ref.read(gpsServiceInstanceProvider).stopTransmission(uid);
      if (mounted) setState(() => _isVisible = false);
      // Fire-and-forget: update is_active_radar in Firestore for CF trigger (CU-08-C)
      unawaited(
        ref.read(apiClientProvider)
            .patch<dynamic>('/auth/radar-status', data: {'is_active_radar': false})
            .then<void>((_) {}, onError: (_) {}),
      );
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
      final profile = ref.read(userProfileProvider).valueOrNull;
      final rideEnabled = profile?.rideEnabled ?? false;
      final product = profile?.product;
      ref.read(gpsServiceInstanceProvider).startTransmission(
        uid,
        rideEnabled: rideEnabled,
        product: product,
      );
      if (mounted) setState(() => _isVisible = true);
      // Fire-and-forget: update is_active_radar in Firestore for CF trigger (CU-08-C)
      unawaited(
        ref.read(apiClientProvider)
            .patch<dynamic>('/auth/radar-status', data: {'is_active_radar': true})
            .then<void>((_) {}, onError: (_) {}),
      );
    }
  }

  void _showIncomingDialog(
    BuildContext context, {
    required String stopId,
    required String buyerLat,
    required String buyerLng,
  }) {
    // Track the open dialog so we can dismiss it if the buyer cancels
    setState(() => _pendingDialogStopId = stopId);

    // Clear the provider so it doesn't re-trigger on rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(incomingStopRequestProvider.notifier).state = null;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IncomingStopDialog(
        onAccept: () async {
          // B11: verificar GPS ANTES de cerrar el diálogo para que el
          // vendedor pueda reintentar si el GPS no está disponible aún.
          final position = ref.read(gpsServiceProvider).valueOrNull;
          if (position == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('GPS no disponible. Activa el GPS para aceptar.'),
                ),
              );
            }
            return; // El diálogo permanece abierto para reintentar
          }
          setState(() => _pendingDialogStopId = null);
          Navigator.of(context).pop();
          await _acceptStop(context, stopId, buyerLat, buyerLng);
        },
        onReject: () async {
          setState(() => _pendingDialogStopId = null);
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
    final position = ref.read(gpsServiceProvider).valueOrNull;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('GPS no disponible. Activa el GPS para aceptar.')),
      );
      return;
    }

    final destLat = double.tryParse(buyerLatStr) ?? 0;
    final destLng = double.tryParse(buyerLngStr) ?? 0;

    // Fetch all zones once — used for MEDIUM/LOW check and HIGH avoidance
    final zones = await ref
        .read(activeRiskZonesProvider.future)
        .catchError((_) => <RiskZone>[]);

    final routeZones = _zonesOnRoute(
      originLat: position.latitude,
      originLng: position.longitude,
      destLat: destLat,
      destLng: destLng,
      zones: zones,
    );

    if (!context.mounted) return;

    // LOW: blue informational snackbar (non-blocking)
    if (routeZones.lowCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La ruta pasa por ${routeZones.lowCount} zona(s) de riesgo BAJO.',
          ),
          backgroundColor: const Color(0xFF0277BD),
          duration: const Duration(seconds: 6),
        ),
      );
    }

    // MEDIUM: mandatory dialog — vendor cancel → reject stop
    if (routeZones.mediumZones.isNotEmpty) {
      if (!context.mounted) return;
      final proceed = await _showMediumZoneDialog(
          context, routeZones.mediumZones.length);
      if (!proceed) {
        try {
          await ref.read(stopRequestModuleProvider).rejectStopRequest(stopId);
        } catch (_) {}
        return;
      }
    }

    if (!context.mounted) return;

    final routeWarnings = routeZones.mediumZones.map((z) => z.id).toList();

    try {
      await ref
          .read(stopRequestModuleProvider)
          .acceptStopRequest(stopId, routeWarnings: routeWarnings);
    } on DioException catch (e) {
      if (!context.mounted) return;
      final detail = (e.response?.data as Map?)?['detail'] as String?;
      final msg = detail == 'vendor_already_busy'
          ? 'Ya tienes una solicitud activa. No puedes aceptar más.'
          : 'Error al aceptar: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar: $e')),
      );
      return;
    }

    setState(() => _activeStopId = stopId);

    final highZones = zones.where((z) => z.riskLevel == 'HIGH').toList();
    final avoidWaypoints = _buildAvoidWaypoints(
      originLat: position.latitude,
      originLng: position.longitude,
      destLat: destLat,
      destLng: destLng,
      highZones: highZones,
    );

    await _fetchRoute(
      originLat: position.latitude,
      originLng: position.longitude,
      destLat: destLat,
      destLng: destLng,
      avoidWaypoints: avoidWaypoints,
    );

    setState(() {
      _isNavigating = true;
      _buyerLat = destLat;
      _buyerLng = destLng;
    });
  }

  Future<void> _fetchRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<String> avoidWaypoints = const [],
  }) async {
    // _initMapsKey() may still be in flight when the dialog is accepted quickly.
    if (_mapsApiKey.isEmpty) await _initMapsKey();
    if (_mapsApiKey.isEmpty) {
      debugPrint('[_fetchRoute] Maps API key unavailable — skipping route fetch');
      return;
    }

    // First attempt — with avoid waypoints (if any).
    var points = await _requestRoute(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      avoidWaypoints: avoidWaypoints,
    );

    // Fallback — waypoints off-road can cause ZERO_RESULTS; retry without them.
    if (points == null && avoidWaypoints.isNotEmpty) {
      debugPrint('[_fetchRoute] Retrying without avoid waypoints');
      points = await _requestRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      );
      if (points != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontró ruta alternativa. '
              'La ruta puede pasar por una zona de riesgo.',
            ),
            backgroundColor: AppColors.warning500,
            duration: Duration(seconds: 6),
          ),
        );
      }
    }

    if (points != null && mounted) {
      setState(() => _routePolyline = points!);
    }
  }

  /// Single Directions API attempt. Returns decoded points or null on failure.
  Future<List<LatLng>?> _requestRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<String> avoidWaypoints = const [],
  }) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final params = <String, dynamic>{
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'key': _mapsApiKey,
      };
      if (avoidWaypoints.isNotEmpty) {
        params['waypoints'] = avoidWaypoints.join('|');
      }
      final res = await dio.get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: params,
      );
      final status = res.data?['status'] as String?;
      final routes = res.data?['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        debugPrint('[_fetchRoute] Directions API status=$status — no routes');
        return null;
      }
      final encoded =
          (routes[0] as Map)['overview_polyline']?['points'] as String?;
      if (encoded == null) return null;
      return _decodePolyline(encoded);
    } catch (e) {
      debugPrint('[_fetchRoute] Request error: $e');
      return null;
    }
  }

  Future<void> _confirmDelivery(BuildContext context) async {
    final stopId = _activeStopId;
    if (stopId == null) return;

    // Verificar que el GPS esté disponible
    final position = ref.read(gpsServiceProvider).valueOrNull;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS no disponible. Activa el GPS para confirmar la entrega.'),
        ),
      );
      return;
    }

    // Verificar proximidad al comprador (máximo 15 m)
    // B10: coordenadas null es estado inválido — bloquear en lugar de saltarse el check
    if (_buyerLat == null || _buyerLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: coordenadas del comprador no disponibles.'),
        ),
      );
      return;
    }
    final dist = _distanceMeters(
      position.latitude,
      position.longitude,
      _buyerLat!,
      _buyerLng!,
    );
    if (dist > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debes estar a menos de 15 m del comprador para confirmar. '
            'Distancia actual: ${dist.toStringAsFixed(0)} m.',
          ),
        ),
      );
      return;
    }

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
      _buyerLat = null;
      _buyerLng = null;
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

  Future<bool> _showMediumZoneDialog(BuildContext context, int zoneCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Advertencia de zona de riesgo'),
        content: Text(
          'La ruta pasa por $zoneCount zona(s) de riesgo MEDIO. '
          '¿Deseas continuar con la solicitud?',
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger500),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning500,
              foregroundColor: AppColors.surface,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _showIncomingRideDialog(
    BuildContext context, {
    required String rideId,
    required String pickupLat,
    required String pickupLng,
    required String destinationLat,
    required String destinationLng,
  }) {
    setState(() => _pendingDialogRideId = rideId);
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
          // B23: verificar GPS ANTES de cerrar el diálogo para que el
          // vendedor pueda reintentar si el GPS no está disponible aún.
          final position = ref.read(gpsServiceProvider).valueOrNull;
          if (position == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('GPS no disponible. Activa el GPS para aceptar.'),
                ),
              );
            }
            return; // El diálogo permanece abierto para reintentar
          }
          setState(() => _pendingDialogRideId = null);
          Navigator.of(context).pop();
          await _acceptRide(context, rideId,
              pickupLat: pickupLat,
              pickupLng: pickupLng,
              destinationLat: destinationLat,
              destinationLng: destinationLng);
        },
        onReject: () async {
          setState(() => _pendingDialogRideId = null);
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
    required String destinationLat,
    required String destinationLng,
  }) async {
    final position = ref.read(gpsServiceProvider).valueOrNull;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('GPS no disponible. Activa el GPS para aceptar.')),
      );
      return;
    }

    final pLat = double.tryParse(pickupLat) ?? 0;
    final pLng = double.tryParse(pickupLng) ?? 0;
    final dLat = double.tryParse(destinationLat) ?? 0;
    final dLng = double.tryParse(destinationLng) ?? 0;

    // Fetch all zones once — used for MEDIUM/LOW check and HIGH avoidance
    final zones = await ref
        .read(activeRiskZonesProvider.future)
        .catchError((_) => <RiskZone>[]);

    final routeZones = _zonesOnRoute(
      originLat: position.latitude,
      originLng: position.longitude,
      destLat: pLat,
      destLng: pLng,
      zones: zones,
    );

    if (!context.mounted) return;

    if (routeZones.lowCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La ruta pasa por ${routeZones.lowCount} zona(s) de riesgo BAJO.',
          ),
          backgroundColor: const Color(0xFF0277BD),
          duration: const Duration(seconds: 6),
        ),
      );
    }

    if (routeZones.mediumZones.isNotEmpty) {
      if (!context.mounted) return;
      final proceed = await _showMediumZoneDialog(
          context, routeZones.mediumZones.length);
      if (!proceed) {
        try {
          await ref.read(rideRequestModuleProvider).updateStatus(
                rideId, 'rejected',
                rejectedReason: 'vendor_rejected');
        } catch (_) {}
        return;
      }
    }

    if (!context.mounted) return;

    final routeWarnings = routeZones.mediumZones.map((z) => z.id).toList();

    try {
      await ref.read(rideRequestModuleProvider).updateStatus(
            rideId, 'accepted',
            routeWarnings: routeWarnings);
    } on DioException catch (e) {
      if (!context.mounted) return;
      final detail = (e.response?.data as Map?)?['detail'] as String?;
      final msg = detail == 'vendor_already_busy'
          ? 'Ya tienes una solicitud activa. No puedes aceptar más.'
          : 'Error al aceptar raite: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
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
      _ridePickupLat = pLat;
      _ridePickupLng = pLng;
      _rideDestLat = dLat;
      _rideDestLng = dLng;
    });

    // Fase 1: ruta del vendedor al punto de recogida (con desvío de zonas HIGH)
    final highZones = zones.where((z) => z.riskLevel == 'HIGH').toList();
    final avoidWaypoints = _buildAvoidWaypoints(
      originLat: position.latitude,
      originLng: position.longitude,
      destLat: pLat,
      destLng: pLng,
      highZones: highZones,
    );
    await _fetchRoute(
      originLat: position.latitude,
      originLng: position.longitude,
      destLat: pLat,
      destLng: pLng,
      avoidWaypoints: avoidWaypoints,
    );

    // Watch the ride for status changes (in_progress triggered by vendor action)
    await _rideSub?.cancel();
    _rideSub =
        ref.read(rideRequestModuleProvider).watchRide(rideId).listen((ride) {
      if (ride == null) return;
      if (ride.status == RideStatus.inProgress && _ridePhase == 1) {
        setState(() => _ridePhase = 2);
      } else if (ride.status == RideStatus.completed ||
          ride.status == RideStatus.rejected ||
          ride.status == RideStatus.expired ||
          ride.status == RideStatus.cancelled) {
        _rideSub?.cancel();
        _rideSub = null;
        setState(() {
          _activeRideId = null;
          _ridePhase = 0;
          _routePolyline = [];
          _ridePickupLat = null;
          _ridePickupLng = null;
          _rideDestLat = null;
          _rideDestLng = null;
        });
      }
    });
  }

  Future<void> _signalVendorArrived(BuildContext context) async {
    final rideId = _activeRideId;
    if (rideId == null) return;

    // Fase 2: coordenadas para el tramo recogida → destino
    final dLat = _rideDestLat;
    final dLng = _rideDestLng;
    final pLat = _ridePickupLat;
    final pLng = _ridePickupLng;
    final currentPos = ref.read(gpsServiceProvider).valueOrNull;
    final originLat = currentPos?.latitude ?? pLat;
    final originLng = currentPos?.longitude ?? pLng;

    List<String> routeWarnings = const [];
    List<RiskZone> zones = const [];

    if (dLat != null && dLng != null && originLat != null && originLng != null) {
      zones = await ref
          .read(activeRiskZonesProvider.future)
          .catchError((_) => <RiskZone>[]);

      final routeZones = _zonesOnRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: dLat,
        destLng: dLng,
        zones: zones,
      );

      if (!context.mounted) return;

      if (routeZones.lowCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La ruta al destino pasa por ${routeZones.lowCount} zona(s) de riesgo BAJO.',
            ),
            backgroundColor: const Color(0xFF0277BD),
            duration: const Duration(seconds: 6),
          ),
        );
      }

      if (routeZones.mediumZones.isNotEmpty) {
        if (!context.mounted) return;
        final proceed = await _showMediumZoneDialog(
            context, routeZones.mediumZones.length);
        if (!proceed) {
          await _rideSub?.cancel();
          _rideSub = null;
          setState(() {
            _activeRideId = null;
            _ridePhase = 0;
            _routePolyline = [];
            _isNavigating = false;
            _ridePickupLat = null;
            _ridePickupLng = null;
            _rideDestLat = null;
            _rideDestLng = null;
          });
          unawaited(
            ref
                .read(rideRequestModuleProvider)
                .abandonRide(rideId)
                .timeout(const Duration(seconds: 3))
                .catchError((_) {}),
          );
          return;
        }
        routeWarnings = routeZones.mediumZones.map((z) => z.id).toList();
      }
    }

    // B24: FCM y PATCH separados — el vendedor puede reintentar sin duplicar la notificación.
    try {
      await ref.read(rideRequestModuleProvider).vendorArrived(rideId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al notificar llegada: $e')),
      );
      return;
    }
    try {
      await ref.read(rideRequestModuleProvider).updateStatus(
            rideId, 'in_progress',
            routeWarnings: routeWarnings);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar estado: $e')),
      );
      return;
    }
    if (mounted) setState(() => _ridePhase = 2);

    // Fetch route to destination with HIGH zone avoidance
    if (dLat != null && dLng != null && originLat != null && originLng != null) {
      final highZones = zones.where((z) => z.riskLevel == 'HIGH').toList();
      final avoidWaypoints = _buildAvoidWaypoints(
        originLat: originLat,
        originLng: originLng,
        destLat: dLat,
        destLng: dLng,
        highZones: highZones,
      );
      await _fetchRoute(
        originLat: originLat,
        originLng: originLng,
        destLat: dLat,
        destLng: dLng,
        avoidWaypoints: avoidWaypoints,
      );
    }
  }

  Future<void> _completeRide(BuildContext context) async {
    final rideId = _activeRideId;
    if (rideId == null) return;

    // Validar que el vendedor esté a ≤ 50 m del destino antes de completar.
    // Patrón idéntico a _confirmDelivery (C-57, umbral 15 m para paradas).
    final position = ref.read(gpsServiceProvider).valueOrNull;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS no disponible. Actívalo para confirmar la llegada.'),
        ),
      );
      return;
    }
    if (_rideDestLat == null || _rideDestLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: coordenadas del destino no disponibles.')),
      );
      return;
    }
    final distToDestM = _distanceMeters(
      position.latitude, position.longitude, _rideDestLat!, _rideDestLng!,
    );
    if (distToDestM > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debes estar a menos de 50 m del destino para completar. '
            'Distancia actual: ${distToDestM.toStringAsFixed(0)} m.',
          ),
        ),
      );
      return;
    }

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
      _ridePickupLat = null;
      _ridePickupLng = null;
      _rideDestLat = null;
      _rideDestLng = null;
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

  /// Maneja el cierre de sesión completo desde MapScreenVendor (siempre vivo).
  /// Si hay solicitud activa muestra diálogo; si cancela, no hace nada.
  /// Al confirmar: abandona solicitud, detiene GPS, desactiva visibilidad y cierra sesión.
  Future<void> _handleSignOut() async {
    final stopId = _activeStopId;
    final rideId = _activeRideId;

    if (stopId != null || rideId != null) {
      if (!mounted) {
        // Sin contexto para mostrar diálogo — proceder directamente.
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Solicitud activa'),
            content: Text(
              rideId != null
                  ? 'Tienes un raite en curso. Si cierras sesión, el pasajero será notificado que abandonaste la aplicación. ¿Deseas continuar?'
                  : 'Tienes una entrega en curso. Si cierras sesión, el comprador será notificado que abandonaste la aplicación. ¿Deseas continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger500),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      if (stopId != null) {
        if (mounted) {
          setState(() {
            _activeStopId = null;
            _isNavigating = false;
            _routePolyline = [];
            _buyerLat = null;
            _buyerLng = null;
          });
        }
        // Await before signOut so the JWT is still valid when the PATCH fires.
        await ref
            .read(stopRequestModuleProvider)
            .abandonStopRequest(stopId)
            .timeout(const Duration(seconds: 3))
            .catchError((_) {});
      }
      if (rideId != null) {
        await _rideSub?.cancel();
        _rideSub = null;
        if (mounted) {
          setState(() {
            _activeRideId = null;
            _ridePhase = 0;
            _routePolyline = [];
            _isNavigating = false;
            _ridePickupLat = null;
            _ridePickupLng = null;
            _rideDestLat = null;
            _rideDestLng = null;
          });
        }
        // Await before signOut so the JWT is still valid when the PATCH fires.
        await ref
            .read(rideRequestModuleProvider)
            .abandonRide(rideId)
            .timeout(const Duration(seconds: 3))
            .catchError((_) {});
      }
    }

    // Detener GPS, desactivar visibilidad y cerrar sesión.
    final gps = ref.read(gpsServiceInstanceProvider);
    final uid = gps.activeUid;
    if (uid != null) await gps.stopTransmission(uid);
    if (mounted) setState(() => _isVisible = false);
    // Reset radar flag before sign-out so CF fires correctly on next session (B1-fix).
    unawaited(
      ref.read(apiClientProvider)
          .patch<dynamic>('/auth/radar-status', data: {'is_active_radar': false})
          .then<void>((_) {}, onError: (_) {}),
    );
    await ref.read(authModuleProvider).signOut();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rideSub?.cancel();
    super.dispose();
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

  Future<void> _onLotFabPressed(dynamic position) async {
    if (position == null) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) => const GpsRequiredEmptyState(),
      );
      return;
    }
    final selectedLatLng = await LotLocationPickerSheet.show(
      context,
      LatLng(position.latitude, position.longitude),
    );
    if (selectedLatLng == null || !mounted) return;
    await LotFormBottomSheet.show(
      context,
      lat: selectedLatLng.latitude,
      lng: selectedLatLng.longitude,
    );
  }

  Marker _groupStayToMarker(GroupStay stay, BuildContext context) {
    final snippet = stay.status == 'active' ? 'Activa' : 'Programada';
    return Marker(
      markerId: MarkerId('gs_${stay.id}'),
      position: LatLng(stay.locationLat, stay.locationLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      infoWindow: InfoWindow(
        title: 'Estancia grupal',
        snippet: '$snippet · ${stay.attendeesCount} asistentes',
        onTap: () => context.push('/group-stays/detail', extra: stay),
      ),
    );
  }

  Marker _communityReportToMarker(
      CommunityReport report, BuildContext context) {
    final hue = switch (report.threatType) {
      ThreatType.animalMuerto => BitmapDescriptor.hueRose,
      ThreatType.zonaSucia => BitmapDescriptor.hueOrange,
      ThreatType.loteBaldio => BitmapDescriptor.hueYellow,
    };
    final label = switch (report.threatType) {
      ThreatType.animalMuerto => 'Animal muerto',
      ThreatType.zonaSucia => 'Zona sucia',
      ThreatType.loteBaldio => 'Lote baldío',
    };
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
      color: const Color(0xE6F57C00), // AppColors.warning700 with ~90% opacity
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

// ── SpeedDial FAB — CU-03 + CU-05 (vendor map) ───────────────────────────────
class _VendorSpeedDial extends StatelessWidget {
  const _VendorSpeedDial({
    required this.open,
    required this.onToggle,
    required this.onRiskZone,
    required this.onCommunityReport,
    required this.onLotReport,
    required this.onScheduleStay,
  });

  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onRiskZone;
  final VoidCallback onCommunityReport;
  final VoidCallback onLotReport;
  final VoidCallback onScheduleStay;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open) ...[
          _VendorMiniAction(
            icon: Icons.event_available_outlined,
            label: 'Programar estancia',
            color: AppColors.secondary700,
            onTap: onScheduleStay,
          ),
          const SizedBox(height: 8),
          _VendorMiniAction(
            icon: Icons.home_work_outlined,
            label: 'Lote baldío',
            color: const Color(0xFF6D4C41),
            onTap: onLotReport,
          ),
          const SizedBox(height: 8),
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

// ─── Risk zone helpers ────────────────────────────────────────────────────────

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

// 1×1 transparent PNG — hit area for zone circle taps (Option A).
Future<BitmapDescriptor> _buildZoneTapIcon() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder);
  final img = await recorder.endRecording().toImage(1, 1);
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  return BitmapDescriptor.bytes(bytes);
}

/// Returns perpendicular-offset waypoint strings to route around HIGH zones.
/// Only zones whose circle intersects the origin→destination segment are
/// considered; zones off the route are ignored to avoid unnecessary detours.
/// All geometry is computed in metric space (meters) using the midpoint latitude
/// to correct for the longitude-degree scale, then converted back to degrees.
List<String> _buildAvoidWaypoints({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  required List<RiskZone> highZones,
}) {
  if (highZones.isEmpty) return const [];

  // Scale factors: longitude degrees are shorter than latitude degrees
  // by a factor of cos(latitude). Use the midpoint for best accuracy.
  final midLat = (originLat + destLat) / 2;
  final cosLat = math.cos(midLat * math.pi / 180);
  const metersPerDegLat = 111000.0;
  final metersPerDegLng = metersPerDegLat * cosLat;

  // Route direction vector in meters (metric space)
  final dLatM = (destLat - originLat) * metersPerDegLat;
  final dLngM = (destLng - originLng) * metersPerDegLng;
  final length = math.sqrt(dLatM * dLatM + dLngM * dLngM);
  if (length == 0) return const [];

  // Perpendicular unit vector in metric space (90° CCW rotation)
  final perpLatM = -dLngM / length;
  final perpLngM = dLatM / length;

  final waypoints = <String>[];
  for (final z in highZones) {
    // Zone position relative to origin, in meters
    final zLatM = (z.latitude - originLat) * metersPerDegLat;
    final zLngM = (z.longitude - originLng) * metersPerDegLng;

    // Project zone center onto the route segment: t ∈ [0, 1]
    final t = ((zLatM * dLatM + zLngM * dLngM) / (length * length))
        .clamp(0.0, 1.0);
    // Closest point on segment to zone center (in meters from origin)
    final closestLatM = dLatM * t;
    final closestLngM = dLngM * t;
    // Perpendicular distance from zone center to the segment
    final distM = math.sqrt(
      math.pow(zLatM - closestLatM, 2) + math.pow(zLngM - closestLngM, 2),
    );

    // Zone does not intersect the route segment — skip, no detour needed
    if (distM > z.radiusMeters) continue;

    // Cross product determines which side of the route the zone lies on
    final cross = dLatM * zLngM - dLngM * zLatM;
    final side = cross >= 0 ? 1.0 : -1.0;
    final offsetMeters = (z.radiusMeters + 50).toDouble();
    // Waypoint = zone center displaced perpendicular to route, converted back to degrees
    final wpLat = z.latitude + perpLatM * offsetMeters * side / metersPerDegLat;
    final wpLng = z.longitude + perpLngM * offsetMeters * side / metersPerDegLng;
    waypoints.add('$wpLat,$wpLng');
  }
  return waypoints;
}

// ─── Zone-on-route detection ──────────────────────────────────────────────────

class _RouteZones {
  const _RouteZones({required this.mediumZones, required this.lowCount});
  final List<RiskZone> mediumZones;
  final int lowCount;
}

/// Returns MEDIUM/LOW zones whose circles intersect the origin→dest segment.
/// Uses the same metric-space projection as [_buildAvoidWaypoints].
_RouteZones _zonesOnRoute({
  required double originLat,
  required double originLng,
  required double destLat,
  required double destLng,
  required List<RiskZone> zones,
}) {
  final midLat = (originLat + destLat) / 2;
  final cosLat = math.cos(midLat * math.pi / 180);
  const metersPerDegLat = 111000.0;
  final metersPerDegLng = metersPerDegLat * cosLat;

  final dLatM = (destLat - originLat) * metersPerDegLat;
  final dLngM = (destLng - originLng) * metersPerDegLng;
  final length = math.sqrt(dLatM * dLatM + dLngM * dLngM);
  if (length == 0) return const _RouteZones(mediumZones: [], lowCount: 0);

  final mediumZones = <RiskZone>[];
  int lowCount = 0;

  for (final z in zones) {
    if (z.riskLevel == 'HIGH') continue;
    final zLatM = (z.latitude - originLat) * metersPerDegLat;
    final zLngM = (z.longitude - originLng) * metersPerDegLng;
    final t =
        ((zLatM * dLatM + zLngM * dLngM) / (length * length)).clamp(0.0, 1.0);
    final distM = math.sqrt(
      math.pow(zLatM - dLatM * t, 2) + math.pow(zLngM - dLngM * t, 2),
    );
    if (distM > z.radiusMeters) continue;
    if (z.riskLevel == 'MEDIUM') {
      mediumZones.add(z);
    } else {
      lowCount++;
    }
  }
  return _RouteZones(mediumZones: mediumZones, lowCount: lowCount);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Haversine distance in meters between two WGS-84 coordinates.
double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLam = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLam / 2) * math.sin(dLam / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

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
    required this.onAccept,
    required this.onReject,
  });

  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva solicitud de parada'),
      content: const Text('Un comprador cercano solicita que te detengas.'),
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
      content: const Text('Un pasajero cercano solicita un raite.'),
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
