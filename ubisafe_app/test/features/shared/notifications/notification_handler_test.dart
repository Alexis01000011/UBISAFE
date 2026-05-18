import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ubisafe_app/features/dispatching/models/stop_request.dart';
import 'package:ubisafe_app/features/shared/notifications/notification_handler.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockDio extends Mock implements Dio {}

// ── Helpers ───────────────────────────────────────────────────────────────

NotificationSettings _settings(AuthorizationStatus s) => NotificationSettings(
      authorizationStatus: s,
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.notSupported,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      sound: AppleNotificationSetting.enabled,
      timeSensitive: AppleNotificationSetting.notSupported,
    );

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  late _MockFirebaseMessaging mockMessaging;
  late _MockDio mockDio;

  setUp(() {
    mockMessaging = _MockFirebaseMessaging();
    mockDio = _MockDio();
    registerFallbackValue(RequestOptions(path: ''));
  });

  NotificationHandler makeHandler({
    void Function(Map<String, dynamic>?)? onIncoming,
    void Function(StopEvent?)? onEvent,
    void Function()? onInvalidateRiskZones,
    void Function()? onCommunityReportNearby,
    void Function(Map<String, dynamic>?)? onIncomingRide,
    void Function(RideEvent?)? onRideEvent,
  }) =>
      NotificationHandler(
        mockMessaging,
        mockDio,
        setIncomingStop: onIncoming ?? (_) {},
        setStopEvent: onEvent ?? (_) {},
        invalidateRiskZones: onInvalidateRiskZones ?? () {},
        onCommunityReportNearby: onCommunityReportNearby ?? () {},
        setIncomingRide: onIncomingRide ?? (_) {},
        setRideEvent: onRideEvent ?? (_) {},
      );

  group('NotificationHandler.init', () {
    test('requests FCM permission on init', () async {
      when(() => mockMessaging.requestPermission())
          .thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
      when(() => mockMessaging.getToken()).thenAnswer((_) async => null);
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());

      await makeHandler().init();

      verify(() => mockMessaging.requestPermission()).called(1);
    });

    test('syncs FCM token to API when token is available', () async {
      when(() => mockMessaging.requestPermission())
          .thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'my-fcm-token');
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockDio.patch<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: null,
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      await makeHandler().init();

      verify(() => mockDio.patch<dynamic>(
            '/auth/device-token',
            data: {'token': 'my-fcm-token'},
          )).called(1);
    });

    test('does NOT sync when getToken returns null', () async {
      when(() => mockMessaging.requestPermission())
          .thenAnswer((_) async => _settings(AuthorizationStatus.denied));
      when(() => mockMessaging.getToken()).thenAnswer((_) async => null);
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());

      await makeHandler().init();

      verifyNever(
          () => mockDio.patch<dynamic>(any(), data: any(named: 'data')));
    });
  });

  group('notification dispatch via handleMessageForTest', () {
    test('stop_request_incoming calls setIncomingStop with data', () {
      Map<String, dynamic>? received;
      final handler = makeHandler(onIncoming: (d) => received = d);

      handler.handleMessageForTest({
        'type': 'stop_request_incoming',
        'stop_id': 'stop-xyz',
        'buyer_lat': '20.67',
        'buyer_lng': '-103.34',
      });

      expect(received, isNotNull);
      expect(received!['stop_id'], equals('stop-xyz'));
      expect(received!['type'], equals('stop_request_incoming'));
    });

    test('stop_request_accepted dispatches accepted event', () {
      StopEvent? received;
      final handler = makeHandler(onEvent: (e) => received = e);

      handler.handleMessageForTest({
        'type': 'stop_request_accepted',
        'stop_id': 'stop-abc',
      });

      expect(received, isNotNull);
      expect(received!.stopId, equals('stop-abc'));
      expect(received!.status, equals(StopRequestStatus.accepted));
    });

    test('stop_request_rejected dispatches rejected event', () {
      StopEvent? received;
      final handler = makeHandler(onEvent: (e) => received = e);

      handler.handleMessageForTest({
        'type': 'stop_request_rejected',
        'stop_id': 'stop-abc',
      });

      expect(received!.status, equals(StopRequestStatus.rejected));
    });

    test('stop_request_completed dispatches completed event', () {
      StopEvent? received;
      final handler = makeHandler(onEvent: (e) => received = e);

      handler.handleMessageForTest({
        'type': 'stop_request_completed',
        'stop_id': 'stop-abc',
      });

      expect(received!.status, equals(StopRequestStatus.completed));
    });

    test('missing stop_id in accepted event does not dispatch', () {
      StopEvent? received;
      final handler = makeHandler(onEvent: (e) => received = e);

      handler.handleMessageForTest({'type': 'stop_request_accepted'});

      expect(received, isNull);
    });

    test('risk_zone_alert calls invalidateRiskZones', () {
      var invalidated = false;
      final handler = makeHandler(onInvalidateRiskZones: () => invalidated = true);

      handler.handleMessageForTest({
        'type': 'risk_zone_alert',
        'risk_zone_id': 'rz-001',
        'risk_level': 'HIGH',
      });

      expect(invalidated, isTrue);
    });

    test('unknown type does not dispatch anything', () {
      Map<String, dynamic>? incoming;
      StopEvent? event;
      final handler = makeHandler(
        onIncoming: (d) => incoming = d,
        onEvent: (e) => event = e,
      );

      handler.handleMessageForTest({'type': 'community_report'});

      expect(incoming, isNull);
      expect(event, isNull);
    });
  });
}
