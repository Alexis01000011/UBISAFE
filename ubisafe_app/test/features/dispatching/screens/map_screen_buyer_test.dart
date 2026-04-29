import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ubisafe_app/features/dispatching/screens/map_screen_buyer.dart';
import 'package:ubisafe_app/features/dispatching/services/stop_request_module.dart';
import 'package:ubisafe_app/features/presence/services/gps_service.dart';
import 'package:ubisafe_app/features/presence/services/vendor_tracker.dart';
import 'package:ubisafe_app/features/community/services/community_report_module.dart';
import 'package:ubisafe_app/features/safety/services/risk_report_module.dart';
import 'package:ubisafe_app/features/shared/widgets/gps_required_empty_state.dart';

class _MockDio extends Mock implements Dio {}

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

Widget _buildApp({
  required Widget home,
  required List<Override> overrides,
}) {
  final originalOnError = FlutterError.onError;
  addTearDown(() => FlutterError.onError = originalOnError);
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('GoogleFonts') ||
        details.exceptionAsString().contains('font') ||
        details.exceptionAsString().contains('HTTP') ||
        details.exceptionAsString().contains('PlatformException')) {
      return;
    }
    FlutterError.presentError(details);
  };
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: home),
  );
}

void main() {
  late _MockDio mockDio;
  late _MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockDio = _MockDio();
    mockFirestore = _MockFirebaseFirestore();
    registerFallbackValue(RequestOptions(path: ''));
  });

  List<Override> overrides({Position? position}) => [
        gpsServiceProvider.overrideWith(
          (ref) => Stream.value(position),
        ),
        vendorMarkersProvider.overrideWith(
          (ref) => Stream.value([]),
        ),
        stopRequestModuleProvider.overrideWith(
          (ref) => StopRequestModule(mockDio, mockFirestore),
        ),
        riskReportModuleProvider.overrideWith(
          (ref) => RiskReportModule(mockDio),
        ),
        communityReportModuleProvider.overrideWith(
          (ref) => CommunityReportModule(mockDio),
        ),
      ];

  group('MapScreenBuyer — GPS guard', () {
    testWidgets('shows GpsRequiredEmptyState when GPS position is null',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          home: const MapScreenBuyer(),
          overrides: overrides(position: null),
        ),
      );
      await tester.pump();

      expect(find.byType(GpsRequiredEmptyState), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator while GPS is loading',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gpsServiceProvider.overrideWith(
              (ref) => const Stream<Position?>.empty(),
            ),
            vendorMarkersProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            stopRequestModuleProvider.overrideWith(
              (ref) => StopRequestModule(mockDio, mockFirestore),
            ),
            riskReportModuleProvider.overrideWith(
              (ref) => RiskReportModule(mockDio),
            ),
            communityReportModuleProvider.overrideWith(
              (ref) => CommunityReportModule(mockDio),
            ),
          ],
          child: const MaterialApp(home: MapScreenBuyer()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('MapScreenBuyer — UI structure', () {
    testWidgets('renders AppBar with correct title', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          home: const MapScreenBuyer(),
          overrides: overrides(position: null),
        ),
      );
      await tester.pump();

      expect(find.text('UbiSafe — Mapa'), findsOneWidget);
    });
  });
}
