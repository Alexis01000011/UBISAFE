// risk_form_bottom_sheet_test.dart
// Tests unitarios para RiskFormBottomSheet (CU-03 — pantalla W-13/W-14).
// Ref: SDD_FASE4_UBISAFE.md §8.3 (flujos HIGH/MEDIUM/LOW y error 409 duplicado)
//      SDD_FASE5_UBISAFE.md §9 (W-13 RiskReportForm, W-14 Risk Confirm)

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ubisafe_app/core/api/api_client.dart';
import 'package:ubisafe_app/features/safety/screens/risk_form_bottom_sheet.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

// ─── Helper ──────────────────────────────────────────────────────────────────

/// Mounts RiskFormBottomSheet inside a ProviderScope + MaterialApp + Scaffold
/// so showModalBottomSheet routing and ScaffoldMessenger work correctly.
Future<void> _pumpBottomSheet(
  WidgetTester tester, {
  required Dio dio,
  LatLng location = const LatLng(19.43, -99.13),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(dio),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => RiskFormBottomSheet.show(context, location),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('RiskFormBottomSheet — renderizado inicial', () {
    testWidgets('muestra título "Reportar zona de riesgo"', (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      expect(find.text('Reportar zona de riesgo'), findsOneWidget);
    });

    testWidgets('muestra los tres chips de nivel de riesgo', (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      expect(find.text('ALTO'), findsOneWidget);
      expect(find.text('MEDIO'), findsOneWidget);
      expect(find.text('BAJO'), findsOneWidget);
    });

    testWidgets('muestra coordenadas de ubicación en el subtítulo',
        (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(
        tester,
        dio: mockDio,
        location: const LatLng(19.43000, -99.13000),
      );
      // Should display lat/lng formatted to 5 decimals
      expect(find.textContaining('19.43000'), findsOneWidget);
    });

    testWidgets('muestra campo de texto "Tipo de amenaza"', (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Tipo de amenaza'), findsOneWidget);
    });
  });

  group('RiskFormBottomSheet — validación de formulario', () {
    testWidgets('no envía si el tipo de amenaza está vacío', (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      // Tap submit without filling anything
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      // Form validation error should appear
      expect(find.text('Requerido'), findsOneWidget);

      // API should NOT have been called
      verifyNever(() => mockDio.post<dynamic>(any(), data: any(named: 'data')));
    });

    testWidgets('muestra SnackBar si no se selecciona nivel de riesgo',
        (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      // Fill the threat type but skip risk level selection
      await tester.enterText(find.byType(TextFormField), 'robo');
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona un nivel de riesgo'), findsOneWidget);
    });

    testWidgets('seleccionar chip HIGH lo marca como selected', (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      await tester.tap(find.text('ALTO'));
      await tester.pumpAndSettle();

      // FilterChip should now be selected — verified by checking chip state
      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      final altoChip =
          chips.firstWhere((c) => (c.label as Text).data == 'ALTO');
      expect(altoChip.selected, isTrue);
    });
  });

  group('RiskFormBottomSheet — envío exitoso', () {
    testWidgets('POST exitoso cierra el sheet y muestra SnackBar de éxito',
        (tester) async {
      final mockDio = MockDio();
      when(() => mockDio.post<dynamic>(
            '/risk-zones',
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => Response(
          data: {'id': 'new-zone'},
          statusCode: 201,
          requestOptions: RequestOptions(path: '/risk-zones'),
        ),
      );

      await _pumpBottomSheet(tester, dio: mockDio);

      await tester.enterText(find.byType(TextFormField), 'accidente vial');
      await tester.tap(find.text('ALTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('Reportar zona de riesgo'), findsNothing);
      // Success snackbar
      expect(find.text('Zona de riesgo reportada'), findsOneWidget);
    });
  });

  group('RiskFormBottomSheet — error 409 duplicado (SDD §8.3.C)', () {
    testWidgets(
        'POST 409 muestra mensaje de duplicado inline sin cerrar el sheet',
        (tester) async {
      final mockDio = MockDio();
      when(() => mockDio.post<dynamic>(
            '/risk-zones',
            data: any(named: 'data'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/risk-zones'),
          type: DioExceptionType.badResponse,
          response: Response(
            data: {'detail': 'Duplicate risk zone'},
            statusCode: 409,
            requestOptions: RequestOptions(path: '/risk-zones'),
          ),
        ),
      );

      await _pumpBottomSheet(tester, dio: mockDio);

      await tester.enterText(find.byType(TextFormField), 'zona duplicada');
      await tester.tap(find.text('MEDIO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      // Inline error message (not a SnackBar — it's _duplicateError)
      expect(
        find.text('Ya existe un reporte activo en esta zona'),
        findsOneWidget,
      );

      // Sheet should still be open
      expect(find.text('Reportar zona de riesgo'), findsOneWidget);
    });

    testWidgets(
        'seleccionar otro nivel de riesgo limpia el error de duplicado',
        (tester) async {
      final mockDio = MockDio();
      when(() => mockDio.post<dynamic>(
            '/risk-zones',
            data: any(named: 'data'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/risk-zones'),
          type: DioExceptionType.badResponse,
          response: Response(
            data: {'detail': 'Duplicate'},
            statusCode: 409,
            requestOptions: RequestOptions(path: '/risk-zones'),
          ),
        ),
      );

      await _pumpBottomSheet(tester, dio: mockDio);
      await tester.enterText(find.byType(TextFormField), 'zona');
      await tester.tap(find.text('ALTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      // Error is shown
      expect(find.text('Ya existe un reporte activo en esta zona'), findsOneWidget);

      // Tapping another chip should clear the error
      await tester.tap(find.text('BAJO'));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe un reporte activo en esta zona'), findsNothing);
    });
  });

  group('RiskFormBottomSheet — error genérico', () {
    testWidgets('error 500 muestra SnackBar de error genérico', (tester) async {
      final mockDio = MockDio();
      when(() => mockDio.post<dynamic>(
            '/risk-zones',
            data: any(named: 'data'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/risk-zones'),
          type: DioExceptionType.badResponse,
          response: Response(
            data: {'detail': 'Internal Server Error'},
            statusCode: 500,
            requestOptions: RequestOptions(path: '/risk-zones'),
          ),
        ),
      );

      await _pumpBottomSheet(tester, dio: mockDio);
      await tester.enterText(find.byType(TextFormField), 'amenaza');
      await tester.tap(find.text('BAJO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Error al reportar la zona. Intenta de nuevo.'),
        findsOneWidget,
      );
    });
  });

  group('RiskFormBottomSheet — botón Cancelar', () {
    testWidgets('al pulsar Cancelar cierra el sheet sin llamar a la API',
        (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Sheet closed
      expect(find.text('Reportar zona de riesgo'), findsNothing);
      verifyNever(() => mockDio.post<dynamic>(any(), data: any(named: 'data')));
    });
  });
}
