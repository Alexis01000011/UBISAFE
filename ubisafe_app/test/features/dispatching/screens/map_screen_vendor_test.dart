// map_screen_vendor_test.dart
// Tests unitarios para MapScreenVendor (CU-01 — pantalla W-10/HomeV del Vendedor).
// Ref: SDD_FASE4_UBISAFE.md §8.1 (flujo aceptación/rechazo desde notificación FCM)
//      SDD_FASE5_UBISAFE.md §9 (W-10, W-11, W-12)
//
// Estrategia: Se usan provider overrides para inyectar eventos FCM simulados
// (incomingStopRequestProvider) y verificar que el dialog de CU-01 aparece.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ubisafe_app/core/providers/auth_providers.dart';
import 'package:ubisafe_app/features/community/models/community_report.dart';
import 'package:ubisafe_app/features/community/services/community_report_module.dart';
import 'package:ubisafe_app/features/dispatching/group_stays/services/group_stay_module.dart';
import 'package:ubisafe_app/features/dispatching/screens/map_screen_vendor.dart';
import 'package:ubisafe_app/features/identity/auth/auth_module.dart';
import 'package:ubisafe_app/features/presence/services/gps_service.dart';
import 'package:ubisafe_app/features/presence/services/vendor_tracker.dart';
import 'package:ubisafe_app/features/safety/models/risk_zone.dart';
import 'package:ubisafe_app/features/safety/services/risk_zone_service.dart';
import 'package:ubisafe_app/features/shared/notifications/notification_handler.dart';

class _MockCommunityReportModule extends Mock implements CommunityReportModule {}

class _MockFirebaseUser extends Mock implements User {
  @override
  String get uid => 'vendor-test';
}

class _MockGroupStayModule extends Mock implements GroupStayModule {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Crea una Position dummy de geolocator para inyectar en gpsServiceProvider.
Position _fakePosition({double lat = 19.43, double lng = -99.13}) =>
    Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2025),
      altitude: 0,
      altitudeAccuracy: 0,
      accuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// Construye MapScreenVendor con providers mínimos para unit testing.
Widget _buildVendorScreen({
  Position? gpsPosition,
  UserProfile? userProfile = const UserProfile(uid: 'vendor-test'),
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(_MockFirebaseUser()),
      ),
      communityReportModuleProvider.overrideWith((_) {
        final m = _MockCommunityReportModule();
        when(() => m.fetchReports(lat: any(named: 'lat'), lng: any(named: 'lng')))
            .thenAnswer((_) async => <CommunityReport>[]);
        return m;
      }),
      gpsServiceProvider.overrideWith(
        (ref) => Stream.value(gpsPosition),
      ),
      vendorMarkersProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
      locationSyncProvider.overrideWith((ref) => null),
      userProfileProvider.overrideWith((ref) => userProfile),
      // En tests de diálogo entrante se actualiza este provider después del primer pump.
      incomingStopRequestProvider.overrideWith((ref) => null),
      activeRiskZonesProvider.overrideWith((ref) => Stream.value(<RiskZone>[])),
      groupStayModuleProvider.overrideWith((ref) => _MockGroupStayModule()),
    ],
    child: const MaterialApp(
      home: MapScreenVendor(),
    ),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('MapScreenVendor — estado inicial', () {
    testWidgets('muestra CircularProgressIndicator mientras GPS carga',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
        (ref) => Stream.value(_MockFirebaseUser()),
      ),
            communityReportModuleProvider.overrideWith((_) {
              final m = _MockCommunityReportModule();
              when(() => m.fetchReports(lat: any(named: 'lat'), lng: any(named: 'lng')))
                  .thenAnswer((_) async => <CommunityReport>[]);
              return m;
            }),
            gpsServiceProvider.overrideWith((ref) => const Stream.empty()),
            vendorMarkersProvider.overrideWith((ref) => Stream.value([])),
            locationSyncProvider.overrideWith((ref) => null),
            incomingStopRequestProvider.overrideWith((ref) => null),
            activeRiskZonesProvider.overrideWith(
                (ref) => Stream.value(<RiskZone>[])),
            groupStayModuleProvider.overrideWith((ref) => _MockGroupStayModule()),
          ],
          child: const MaterialApp(home: MapScreenVendor()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tiene título "UbiSafe — Vendedor" en AppBar', (tester) async {
      await tester.pumpWidget(
        _buildVendorScreen(gpsPosition: _fakePosition()),
      );
      await tester.pump();
      expect(find.text('UbiSafe — Vendedor'), findsOneWidget);
    });

    testWidgets(
        'muestra botón "Activar Visibilidad" cuando vendedor no es visible',
        (tester) async {
      await tester.pumpWidget(
        _buildVendorScreen(gpsPosition: _fakePosition()),
      );
      await tester.pump();
      expect(find.text('Activar Visibilidad'), findsOneWidget);
    });
  });

  group('MapScreenVendor — diálogo de visibilidad (CU-02)', () {
    testWidgets(
        'al pulsar "Activar Visibilidad" aparece diálogo de confirmación',
        (tester) async {
      await tester.pumpWidget(
        _buildVendorScreen(gpsPosition: _fakePosition()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Activar Visibilidad'));
      await tester.pumpAndSettle();

      expect(find.text('Activar visibilidad'), findsOneWidget);
      expect(
        find.textContaining('Los compradores cercanos podrán verte'),
        findsOneWidget,
      );
    });

    testWidgets(
        'al cancelar el diálogo de visibilidad el toggle NO cambia de estado',
        (tester) async {
      await tester.pumpWidget(
        _buildVendorScreen(gpsPosition: _fakePosition()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activar Visibilidad'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // El texto del botón sigue siendo "Activar Visibilidad" (no cambió)
      expect(find.text('Activar Visibilidad'), findsOneWidget);
    });
  });

  group('MapScreenVendor — dialog de solicitud entrante (CU-01 §8.1)', () {
    testWidgets(
        'recibir evento FCM incomingStopRequest muestra _IncomingStopDialog',
        (tester) async {
      const incomingData = {
        'stop_id': 'stop-abc',
        'buyer_lat': '19.4300',
        'buyer_lng': '-99.1300',
      };
      await tester.pumpWidget(
        _buildVendorScreen(
          gpsPosition: _fakePosition(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapScreenVendor)),
      );
      container.read(incomingStopRequestProvider.notifier).state = incomingData;

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Nueva solicitud de parada'), findsOneWidget);
    });

    testWidgets(
        'dialog de solicitud entrante tiene botones Aceptar y Rechazar',
        (tester) async {
      const incomingData = {
        'stop_id': 'stop-abc',
        'buyer_lat': '19.4300',
        'buyer_lng': '-99.1300',
      };
      await tester.pumpWidget(
        _buildVendorScreen(
          gpsPosition: _fakePosition(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapScreenVendor)),
      );
      container.read(incomingStopRequestProvider.notifier).state = incomingData;
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
    });

    testWidgets('al pulsar Rechazar el dialog se cierra', (tester) async {
      const incomingData = {
        'stop_id': 'stop-abc',
        'buyer_lat': '19.4300',
        'buyer_lng': '-99.1300',
      };
      await tester.pumpWidget(
        _buildVendorScreen(
          gpsPosition: _fakePosition(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapScreenVendor)),
      );
      container.read(incomingStopRequestProvider.notifier).state = incomingData;
      await tester.pump();
      await tester.pumpAndSettle();

      // rejectStopRequest lanzará DioException (sin API real) — se captura en _showIncomingDialog
      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();

      // El dialog debe haberse cerrado
      expect(find.text('Nueva solicitud de parada'), findsNothing);
    });
  });
}
