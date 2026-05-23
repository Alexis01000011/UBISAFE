import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

const _kChannelId = 'group_stays';
const _kRsvpActionId = 'rsvp_confirm';

/// Top-level function required by flutter_local_notifications for the
/// background/killed-app notification response. Annotated vm:entry-point so
/// the Dart tree-shaker keeps it in release builds.
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  _LocalNotificationHandler.handleResponse(response);
}

/// Internal helper that dispatches notification action responses.
class _LocalNotificationHandler {
  static void handleResponse(NotificationResponse response) {
    if (response.actionId != _kRsvpActionId) return;
    final stayId = response.payload;
    if (stayId == null || stayId.isEmpty) return;
    _confirmAttendance(stayId);
  }

  /// Calls POST /group-stays/{id}/attendances using a standalone Dio instance
  /// (no Riverpod) so it works from a background isolate.
  static void _confirmAttendance(String stayId) {
    FirebaseAuth.instance.currentUser?.getIdToken().then((token) async {
      if (token == null) return;
      try {
        final dio = Dio(
          BaseOptions(
            baseUrl: _kBaseUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        await dio.post<void>('/group-stays/$stayId/attendances');
        await LocalNotificationService._showSuccessNotification(stayId);
      } catch (e) {
        debugPrint('RSVP attendance confirmation failed: $e');
      }
    }).catchError((Object e) {
      debugPrint('RSVP getIdToken failed: $e');
    });
  }
}

/// Wrapper over flutter_local_notifications for group-stay RSVP push notifications.
///
/// Call [init] once before [runApp]. Call [showRsvpGroupStayNotification] from
/// [NotificationHandler] when a `rsvp_group_stay` FCM arrives in foreground.
class LocalNotificationService {
  LocalNotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Initialises the plugin and creates the Android notification channel.
  /// Must be called before [runApp].
  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse:
          _LocalNotificationHandler.handleResponse,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationResponse,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kChannelId,
            'Estancias grupales',
            description: 'Alertas de estancias grupales cercanas',
            importance: Importance.high,
          ),
        );
  }

  /// Shows a local push notification with a "Confirmar asistencia" action button.
  static Future<void> showRsvpGroupStayNotification(
      Map<String, dynamic> payload) async {
    final stayId = payload['group_stay_id'] as String? ?? '';
    final vendorName =
        payload['vendor_name'] as String? ?? 'Un vendedor';
    final startAtIso = payload['start_at'] as String? ?? '';
    final durationStr = payload['duration_minutes'] as String? ?? '60';

    String timeLabel = '';
    try {
      final dt = DateTime.parse(startAtIso).toLocal();
      timeLabel =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    final body = timeLabel.isEmpty
        ? '$vendorName · $durationStr min'
        : '$vendorName · $durationStr min · Inicio: $timeLabel';

    const androidDetails = AndroidNotificationDetails(
      _kChannelId,
      'Estancias grupales',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          _kRsvpActionId,
          'Confirmar asistencia',
          cancelNotification: true,
        ),
      ],
    );

    await _plugin.show(
      _notifId(stayId),
      'Estancia grupal cerca',
      body,
      const NotificationDetails(android: androidDetails),
      payload: stayId,
    );
  }

  static Future<void> _showSuccessNotification(String stayId) async {
    await _plugin.show(
      _notifId(stayId, offset: 50000),
      'Asistencia confirmada',
      'Tu asistencia a la estancia grupal fue registrada.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          'Estancias grupales',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  static int _notifId(String id, {int offset = 0}) =>
      (id.hashCode.abs() + offset) % 2000000000;
}
