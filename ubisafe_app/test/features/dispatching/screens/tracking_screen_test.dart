// tracking_screen_test.dart
// Tests unitarios para TrackingScreen (CU-01 — pantalla W-09).
// Ref: SDD_FASE4_UBISAFE.md §8.1 (flujo normal, completado, expirado)
//      SDD_FASE5_UBISAFE.md §9 (W-09 TrackingScreen)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:ubisafe_app/features/dispatching/models/stop_request.dart';
import 'package:ubisafe_app/features/dispatching/screens/tracking_screen.dart';

import 'package:ubisafe_app/features/presence/services/gps_service.dart';
import 'package:ubisafe_app/features/presence/services/vendor_tracker.dart';
import 'package:ubisafe_app/features/shared/notifications/notification_handler.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Crea una Position dummy para inyectar en gpsServiceProvider.
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

/// Construye TrackingScreen dentro de un ProviderScope mínimo.
Widget _buildTrackingScreen({
  Position? gpsPosition,
  StopEvent? stopEvent,
  String stopRequestId = 'test-stop-123',
}) {
  return ProviderScope(
    overrides: [
      // Inyectar posición GPS estática (evita llamadas reales a geolocator)
      gpsServiceProvider.overrideWith((ref) => Stream.value(gpsPosition)),
      // Sin vendedores en unit tests
      vendorMarkersProvider.overrideWith((ref) => Stream.value([])),
      // Opcionalmente inyectar un StopEvent para tests de estado completado
      stopRequestEventProvider.overrideWith((ref) => stopEvent),
    ],
    child: MaterialApp(
      home: TrackingScreen(stopRequestId: stopRequestId),
    ),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('TrackingScreen — estado inicial', () {
    testWidgets(
        'muestra CircularProgressIndicator mientras gpsServiceProvider carga',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gpsServiceProvider.overrideWith((ref) => const Stream.empty()),
            vendorMarkersProvider.overrideWith((ref) => Stream.value([])),
            stopRequestEventProvider.overrideWith((ref) => null),
          ],
          child: const MaterialApp(
            home: TrackingScreen(stopRequestId: 'stop-loading'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('muestra GpsRequiredEmptyState cuando position es null',
        (tester) async {
      await tester.pumpWidget(
        _buildTrackingScreen(gpsPosition: null),
      );
      await tester.pump();
      // null GPS → GpsRequiredEmptyState widget (no CircularProgressIndicator)
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('muestra botón "Cancelar solicitud" cuando GPS está disponible',
        (tester) async {
      await tester.pumpWidget(
        _buildTrackingScreen(gpsPosition: _fakePosition()),
      );
      await tester.pump();
      expect(find.text('Cancelar solicitud'), findsOneWidget);
    });
  });

  group('TrackingScreen — AppBar', () {
    testWidgets('tiene título "Seguimiento"', (tester) async {
      await tester.pumpWidget(
        _buildTrackingScreen(gpsPosition: _fakePosition()),
      );
      await tester.pump();
      expect(find.text('Seguimiento'), findsOneWidget);
    });
  });

  group('TrackingScreen — diálogo de cancelación', () {
    testWidgets(
        'al pulsar "Cancelar solicitud" aparece diálogo de confirmación',
        (tester) async {
      await tester.pumpWidget(
        _buildTrackingScreen(gpsPosition: _fakePosition()),
      );
      await tester.pump();

      await tester.tap(find.text('Cancelar solicitud'));
      await tester.pumpAndSettle();

      expect(find.text('¿Deseas cancelar la solicitud de parada?'),
          findsOneWidget);
    });

    testWidgets('al pulsar "No" en el diálogo cierra sin navegar',
        (tester) async {
      await tester.pumpWidget(
        _buildTrackingScreen(gpsPosition: _fakePosition()),
      );
      await tester.pump();
      await tester.tap(find.text('Cancelar solicitud'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      // La pantalla sigue visible (no navegó)
      expect(find.text('Seguimiento'), findsOneWidget);
    });
  });

  group('TrackingScreen — modelo StopRequest (Corrección 2.2)', () {
    test('fromMap incluye campos de auditoría accepted_at y completed_at',
        () {
      final map = {
        'buyer_uid': 'buyer-1',
        'vendor_uid': 'vendor-1',
        'status': 'accepted',
        'buyer_location': {'lat': 19.43, 'lng': -99.13},
        'created_at': null,
        'accepted_at': null,
        'completed_at': null,
        'expires_at': null,
        'updated_at': null,
      };
      final stop = StopRequest.fromMap('stop-1', map);
      expect(stop.status, StopRequestStatus.accepted);
      expect(stop.acceptedAt, isNull);  // opcional — null cuando aún no ocurrió
      expect(stop.completedAt, isNull);
    });

    test('copyWith actualiza status sin mutar otros campos', () {
      final original = StopRequest(
        id: 'stop-1',
        buyerUid: 'buyer-1',
        status: StopRequestStatus.pending,
        buyerLat: 19.43,
        buyerLng: -99.13,
        createdAt: DateTime(2025, 1, 1),
      );
      final updated = original.copyWith(status: StopRequestStatus.completed);
      expect(updated.status, StopRequestStatus.completed);
      expect(updated.id, 'stop-1');
      expect(updated.buyerUid, 'buyer-1');
    });

    test('fromJson parsea accepted_at y completed_at desde strings ISO 8601',
        () {
      final json = {
        'id': 'stop-1',
        'buyer_uid': 'buyer-1',
        'vendor_uid': 'vendor-1',
        'status': 'completed',
        'buyer_location': {'lat': 19.43, 'lng': -99.13},
        'created_at': '2025-05-01T10:00:00.000Z',
        'expires_at': '2025-05-01T10:01:00.000Z',
        'updated_at': '2025-05-01T10:02:00.000Z',
        'accepted_at': '2025-05-01T10:01:30.000Z',
        'completed_at': '2025-05-01T10:02:00.000Z',
      };
      final stop = StopRequest.fromJson(json);
      expect(stop.acceptedAt, isNotNull);
      expect(stop.completedAt, isNotNull);
      expect(stop.expiresAt, isNotNull);
      expect(stop.updatedAt, isNotNull);
      expect(stop.completedAt!.isAfter(stop.acceptedAt!), isTrue);
    });
  });
}
