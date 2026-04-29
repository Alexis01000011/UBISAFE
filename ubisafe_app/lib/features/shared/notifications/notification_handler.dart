import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../community/services/community_report_module.dart';
import '../../dispatching/models/stop_request.dart';
import '../../safety/services/risk_zone_module.dart';

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

/// Handles all FCM push-notification events for UbiSafe.
class NotificationHandler {
  NotificationHandler(
    this._messaging,
    this._dio, {
    required void Function(Map<String, dynamic>?) setIncomingStop,
    required void Function(StopEvent?) setStopEvent,
    required void Function() onRiskZoneAlert,
    required void Function() onCommunityReportNearby,
  })  : _setIncomingStop = setIncomingStop,
        _setStopEvent = setStopEvent,
        _onRiskZoneAlert = onRiskZoneAlert,
        _onCommunityReportNearby = onCommunityReportNearby;

  final FirebaseMessaging _messaging;
  final Dio _dio;
  final void Function(Map<String, dynamic>?) _setIncomingStop;
  final void Function(StopEvent?) _setStopEvent;
  final void Function() _onRiskZoneAlert;
  final void Function() _onCommunityReportNearby;
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
      final token = await _messaging
          .getToken()
          .timeout(const Duration(seconds: 5));
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

      case 'risk_zone_alert':
        _onRiskZoneAlert();

      case 'community_report_nearby':
        _onCommunityReportNearby();

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
    onRiskZoneAlert: () =>
        ref.read(activeRiskZonesProvider.notifier).refresh(),
    onCommunityReportNearby: () =>
        ref.read(activeCommunityReportsProvider.notifier).refresh(),
  );
});
