import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

/// Handles all FCM push-notification events for UbiSafe.
///
/// [iter.2 ext] Supported FCM event types:
///   1. `ride_request`       — buyer requests a ride from vendor (CU-04).
///   2. `ride_accepted`      — vendor accepts buyer's ride.
///   3. `ride_completed`     — ride marked completed.
///   4. `community_report`   — new community report near user's location.
///   5. `report_confirmed`   — user's report received enough confirmations.
class NotificationHandler {
  NotificationHandler(this._messaging);

  final FirebaseMessaging _messaging;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    await _messaging.requestPermission();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;
    debugPrint('FCM foreground [$type]: ${message.notification?.title}');
    // TODO: show in-app notification banner based on type.
  }

  void _handleMessageTap(RemoteMessage message) {
    final type = message.data['type'] as String?;
    debugPrint('FCM tapped [$type]');
    // TODO: navigate to relevant screen based on type.
  }

  Future<String?> get fcmToken => _messaging.getToken();
}

final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  return NotificationHandler(FirebaseMessaging.instance);
});
