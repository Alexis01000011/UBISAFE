import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../community/services/community_report_module.dart';
import '../../dispatching/models/stop_request.dart';
import '../../safety/services/risk_zone_service.dart';

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
    required void Function() onCommunityReportNearby,
    required void Function(Map<String, dynamic>?) setIncomingRide,
    required void Function(RideEvent?) setRideEvent,
  })  : _setIncomingStop = setIncomingStop,
        _setStopEvent = setStopEvent,
        _invalidateRiskZones = invalidateRiskZones,
        _onCommunityReportNearby = onCommunityReportNearby,
        _setIncomingRide = setIncomingRide,
        _setRideEvent = setRideEvent;

  final FirebaseMessaging _messaging;
  final Dio _dio;
  final void Function(Map<String, dynamic>?) _setIncomingStop;
  final void Function(StopEvent?) _setStopEvent;
  final void Function() _invalidateRiskZones;
  final void Function() _onCommunityReportNearby;
  final void Function(Map<String, dynamic>?) _setIncomingRide;
  final void Function(RideEvent?) _setRideEvent;
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

      case 'risk_zone_expired':
        _invalidateRiskZones();

      case 'community_report_nearby':
        _onCommunityReportNearby();

      // B30 — fired by the backend when a report reaches confirmed/dismissed.
      // Reuses the same callback to refresh the active reports list.
      case 'report_status_changed':
        _onCommunityReportNearby();

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
    onCommunityReportNearby: () =>
        ref.read(activeCommunityReportsProvider.notifier).refresh(),
    setIncomingRide: (data) =>
        ref.read(incomingRideProvider.notifier).state = data,
    setRideEvent: (event) => ref.read(rideEventProvider.notifier).state = event,
  );
});
