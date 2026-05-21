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
      expect(find.textContaining('19.43000'), findsOneWidget);
    });

    testWidgets('muestra tipo de amenaza fijo: Jauría', (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      expect(find.text('Tipo de amenaza: Jauría'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });
  });

  group('RiskFormBottomSheet — validación de formulario', () {
    testWidgets('muestra SnackBar si no se selecciona nivel de riesgo',
        (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona un nivel de riesgo'), findsOneWidget);
      verifyNever(() => mockDio.post<dynamic>(any(), data: any(named: 'data')));
    });

    testWidgets('seleccionar chip HIGH lo marca como selected', (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      await tester.tap(find.text('ALTO'));
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('ALTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      expect(find.text('Reportar zona de riesgo'), findsNothing);
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

      await tester.tap(find.text('MEDIO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ya existe un reporte activo en esta zona'),
        findsOneWidget,
      );
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
      await tester.tap(find.text('ALTO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      expect(find.text('Ya existe un reporte activo en esta zona'), findsOneWidget);

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
      await tester.tap(find.text('BAJO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error 500:'), findsOneWidget);
    });
  });

  group('RiskFormBottomSheet — botón Cancelar', () {
    testWidgets('al pulsar Cancelar cierra el sheet sin llamar a la API',
        (tester) async {
      final mockDio = MockDio();
      await _pumpBottomSheet(tester, dio: mockDio);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Reportar zona de riesgo'), findsNothing);
      verifyNever(() => mockDio.post<dynamic>(any(), data: any(named: 'data')));
    });
  });
}
