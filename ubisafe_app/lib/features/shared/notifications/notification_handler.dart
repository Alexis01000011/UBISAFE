import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../community/services/community_report_module.dart';
import '../../dispatching/group_stays/services/group_stay_module.dart';
import '../../dispatching/models/stop_request.dart';
import '../../safety/services/risk_zone_service.dart';
import 'local_notification_service.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

/// Incoming stop request data for a vendor (stop_request_incoming FCM event).
final incomingStopRequestProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Status change event dispatched to buyer/vendor screens.
final stopRequestEventProvider = StateProvider<StopEvent?>((ref) => null);

/// Carries a stop_id and the new status from an FCM notification.
class StopEvent {
  const StopEvent(this.stopId, this.status);
  final String stopId;
  final StopRequestStatus status;
}

/// Incoming ride request data for a vendor (ride_request_incoming FCM event).
final incomingRideProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Ride lifecycle event for buyer/vendor screens.
final rideEventProvider = StateProvider<RideEvent?>((ref) => null);

/// Route zone warning dispatched to the buyer when the vendor accepts a
/// request whose route passes through MEDIUM risk zones.
final routeZoneWarningProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Carries the FCM payload of a community_report_nearby event so map screens
/// can show a visible alert with distance and threat type.
final communityReportAlertProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Carries the FCM payload of a risk_zone_alert event so map screens can show
/// a visible SnackBar with distance and risk level when a new zone is created.
final riskZoneAlertProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Carries the FCM payload of a vendor_proximity_alert event so map screens
/// can show a SnackBar when a subscribed vendor activates their radar.
final vendorProximityAlertProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Carries the FCM payload of a lot_resolved event so map screens can remove
/// the resolved lote_baldio marker without waiting for the next poll.
final lotResolvedProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Carries the FCM payload of a group_stay_cancelled event so the detail
/// screen can pop itself when the stay the buyer is viewing gets cancelled.
final groupStayCancelledProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Carries the FCM payload of a rsvp_group_stay event so the buyer map screen
/// can show a SnackBar with a "Ver" action that navigates to the stay detail.
final rsvpGroupStayAlertProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

class RideEvent {
  const RideEvent(this.rideId, this.type);
  final String rideId;
  final RideEventType type;
}

enum RideEventType {
  accepted,
  rejected,
  expired,
  vendorArrived,
  cancelledByBuyer,
  completed,
  abandoned,
}

/// Handles all FCM push-notification events for UbiSafe.
class NotificationHandler {
  NotificationHandler(
    this._messaging,
    this._dio, {
    required void Function(Map<String, dynamic>?) setIncomingStop,
    required void Function(StopEvent?) setStopEvent,
    required void Function() invalidateRiskZones,
    required void Function(Map<String, dynamic>) onRiskZoneAlert,
    required void Function(Map<String, dynamic>) onCommunityReportNearby,
    required void Function() onReportStatusChanged,
    required void Function(Map<String, dynamic>?) setIncomingRide,
    required void Function(RideEvent?) setRideEvent,
    required void Function(Map<String, dynamic>?) onRouteZoneWarning,
    required void Function(Map<String, dynamic>) onVendorProximityAlert,
    required void Function(Map<String, dynamic>) onLotResolved,
    required void Function(Map<String, dynamic>) onGroupStayCancelled,
    required void Function(Map<String, dynamic>) onRsvpGroupStay,
  })  : _setIncomingStop = setIncomingStop,
        _setStopEvent = setStopEvent,
        _invalidateRiskZones = invalidateRiskZones,
        _onRiskZoneAlert = onRiskZoneAlert,
        _onCommunityReportNearby = onCommunityReportNearby,
        _onReportStatusChanged = onReportStatusChanged,
        _setIncomingRide = setIncomingRide,
        _setRideEvent = setRideEvent,
        _onRouteZoneWarning = onRouteZoneWarning,
        _onVendorProximityAlert = onVendorProximityAlert,
        _onLotResolved = onLotResolved,
        _onGroupStayCancelled = onGroupStayCancelled,
        _onRsvpGroupStay = onRsvpGroupStay;

  final FirebaseMessaging _messaging;
  final Dio _dio;
  final void Function(Map<String, dynamic>?) _setIncomingStop;
  final void Function(StopEvent?) _setStopEvent;
  final void Function() _invalidateRiskZones;
  final void Function(Map<String, dynamic>) _onRiskZoneAlert;
  final void Function(Map<String, dynamic>) _onCommunityReportNearby;
  final void Function() _onReportStatusChanged;
  final void Function(Map<String, dynamic>?) _setIncomingRide;
  final void Function(RideEvent?) _setRideEvent;
  final void Function(Map<String, dynamic>?) _onRouteZoneWarning;
  final void Function(Map<String, dynamic>) _onVendorProximityAlert;
  final void Function(Map<String, dynamic>) _onLotResolved;
  final void Function(Map<String, dynamic>) _onGroupStayCancelled;
  final void Function(Map<String, dynamic>) _onRsvpGroupStay;
  bool _initialized = false;

  /// Must be called once before runApp() — cannot be in init() because
  /// FirebaseMessaging.onBackgroundMessage requires Flutter bindings.
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _messaging.requestPermission();

    try {
      final token =
          await _messaging.getToken().timeout(const Duration(seconds: 5));
      if (token != null) {
        await _syncToken(token);
      }
    } catch (e) {
      debugPrint('FCM getToken failed (emulator/unavailable): $e');
    }

    _messaging.onTokenRefresh.listen(_syncToken);
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  /// Re-syncs the FCM token with the backend.
  /// Call this after confirming the user is authenticated and the backend is
  /// reachable (e.g. from SplashScreen after a successful GET /auth/me), so
  /// that the token is always registered even when init() ran before Firebase
  /// Auth restored the persisted session.
  Future<void> syncTokenIfNeeded() async {
    try {
      final token =
          await _messaging.getToken().timeout(const Duration(seconds: 5));
      if (token != null) {
        await _syncToken(token);
      }
    } catch (e) {
      debugPrint('FCM syncTokenIfNeeded failed: $e');
    }
  }

  Future<void> _syncToken(String token) async {
    try {
      await _dio.patch<dynamic>(
        '/auth/device-token',
        data: {'token': token},
      );
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
    }
  }

  void _handleMessage(RemoteMessage message) => _dispatchData(message.data);

  void _dispatchData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final stopId = data['stop_id'] as String?;
    final rideId = data['ride_id'] as String?;

    switch (type) {
      case 'stop_request_incoming':
        _setIncomingStop(Map<String, dynamic>.from(data));

      case 'stop_request_accepted':
        if (stopId != null) {
          _setStopEvent(StopEvent(stopId, StopRequestStatus.accepted));
        }

      case 'stop_request_rejected':
        if (stopId != null) {
          _setStopEvent(StopEvent(stopId, StopRequestStatus.rejected));
        }

      case 'stop_request_completed':
        if (stopId != null) {
          _setStopEvent(StopEvent(stopId, StopRequestStatus.completed));
        }

      case 'stop_request_expired':
        if (stopId != null) {
          _setStopEvent(StopEvent(stopId, StopRequestStatus.expired));
        }

      case 'stop_request_cancelled':
        if (stopId != null) {
          _setStopEvent(StopEvent(stopId, StopRequestStatus.cancelled));
        }

      case 'stop_abandoned':
        if (stopId != null) {
          _setStopEvent(StopEvent(stopId, StopRequestStatus.abandoned));
        }

      case 'risk_zone_alert':
        _invalidateRiskZones();
        _onRiskZoneAlert(Map<String, dynamic>.from(data));

      case 'risk_zone_expired':
        _invalidateRiskZones();

      case 'risk_zone_dismissed':
        _invalidateRiskZones();

      case 'community_report_nearby':
        _onCommunityReportNearby(Map<String, dynamic>.from(data));

      // B30 — fired by the backend when a report reaches confirmed/dismissed.
      // Uses a separate callback to refresh the list without triggering the
      // proximity alert SnackBar (no location data in this payload).
      case 'report_status_changed':
        _onReportStatusChanged();

      case 'ride_request_incoming':
        _setIncomingRide(Map<String, dynamic>.from(data));

      case 'ride_destination_too_far':
        if (rideId != null) {
          _setIncomingRide(Map<String, dynamic>.from(data));
        }

      case 'ride_request_accepted':
        if (rideId != null) {
          _setRideEvent(RideEvent(rideId, RideEventType.accepted));
        }

      case 'ride_request_rejected':
        if (rideId != null) {
          _setRideEvent(RideEvent(rideId, RideEventType.rejected));
        }

      case 'ride_request_expired':
        if (rideId != null) {
          _setRideEvent(RideEvent(rideId, RideEventType.expired));
        }

      case 'ride_vendor_arrived':
        if (rideId != null) {
          _setRideEvent(RideEvent(rideId, RideEventType.vendorArrived));
        }

      case 'ride_cancelled_by_buyer':
        if (rideId != null) {
          _setRideEvent(RideEvent(rideId, RideEventType.cancelledByBuyer));
        }

      case 'ride_completed':
        if (rideId != null) {
          _setRideEvent(RideEvent(rideId, RideEventType.completed));
        }

      case 'ride_abandoned':
        if (rideId != null) {
          _setRideEvent(RideEvent(rideId, RideEventType.abandoned));
        }

      case 'route_zone_warning':
        _onRouteZoneWarning(Map<String, dynamic>.from(data));

      case 'vendor_proximity_alert':
        _onVendorProximityAlert(Map<String, dynamic>.from(data));

      case 'lot_resolved':
        _onLotResolved(Map<String, dynamic>.from(data));

      case 'group_stay_cancelled':
        _onGroupStayCancelled(Map<String, dynamic>.from(data));

      case 'rsvp_group_stay':
        _onRsvpGroupStay(Map<String, dynamic>.from(data));

      default:
        debugPrint('FCM unhandled type [$type]');
    }
  }

  Future<String?> get fcmToken => _messaging.getToken();

  /// Dispatches a raw data map as if it were an FCM message. Use in tests only.
  void handleMessageForTest(Map<String, dynamic> data) => _dispatchData(data);
}

final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  return NotificationHandler(
    FirebaseMessaging.instance,
    ref.read(apiClientProvider),
    setIncomingStop: (data) =>
        ref.read(incomingStopRequestProvider.notifier).state = data,
    setStopEvent: (event) =>
        ref.read(stopRequestEventProvider.notifier).state = event,
    invalidateRiskZones: () => ref.invalidate(activeRiskZonesProvider),
    onRiskZoneAlert: (data) =>
        ref.read(riskZoneAlertProvider.notifier).state = data,
    onCommunityReportNearby: (data) {
      ref.read(activeCommunityReportsProvider.notifier).refresh();
      ref.read(communityReportAlertProvider.notifier).state = data;
    },
    onReportStatusChanged: () =>
        ref.read(activeCommunityReportsProvider.notifier).refresh(),
    setIncomingRide: (data) =>
        ref.read(incomingRideProvider.notifier).state = data,
    setRideEvent: (event) => ref.read(rideEventProvider.notifier).state = event,
    onRouteZoneWarning: (data) =>
        ref.read(routeZoneWarningProvider.notifier).state = data,
    onVendorProximityAlert: (data) =>
        ref.read(vendorProximityAlertProvider.notifier).state = data,
    onLotResolved: (data) {
      ref.read(activeCommunityReportsProvider.notifier).refresh();
      ref.read(lotResolvedProvider.notifier).state = data;
    },
    onGroupStayCancelled: (data) {
      ref.read(groupStayCancelledProvider.notifier).state = data;
      ref.read(activeGroupStaysProvider.notifier).reload();
    },
    onRsvpGroupStay: (data) {
      ref.read(rsvpGroupStayAlertProvider.notifier).state = data;
      LocalNotificationService.showRsvpGroupStayNotification(data);
    },
  );
});
