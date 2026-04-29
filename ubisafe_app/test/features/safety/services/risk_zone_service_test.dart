// risk_zone_service_test.dart
// Tests unitarios para el servicio de zonas de riesgo (CU-03).
// Ref: SDD_FASE4_UBISAFE.md §8.3 (flujos HIGH, MEDIUM, LOW y duplicado)
//      SDD_FASE3_UBISAFE.md §7.2.3 (esquema risk_zones)

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ubisafe_app/core/api/api_client.dart';
import 'package:ubisafe_app/features/safety/models/risk_zone.dart';
import 'package:ubisafe_app/features/safety/services/risk_zone_service.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

// ─── Fixtures ────────────────────────────────────────────────────────────────

Map<String, dynamic> _riskZoneJson({
  String id = 'zone-1',
  String riskLevel = 'HIGH',
  bool active = true,
}) =>
    {
      'id': id,
      'reporter_uid': 'user-reporter',
      'threat_type': 'robo',
      'risk_level': riskLevel,
      'location': {'lat': 19.43, 'lng': -99.13},
      'radius_meters': 100,
      'active': active,
      'created_at': '2025-05-01T10:00:00.000Z',
      'expires_at': '2025-05-02T10:00:00.000Z',
      'expired_at': null,
    };

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('activeRiskZonesProvider — llamada a GET /risk-zones', () {
    test('devuelve lista de RiskZone mapeada correctamente', () async {
      final mockDio = MockDio();
      final responseData = [
        _riskZoneJson(id: 'zone-1', riskLevel: 'HIGH'),
        _riskZoneJson(id: 'zone-2', riskLevel: 'MEDIUM'),
        _riskZoneJson(id: 'zone-3', riskLevel: 'LOW'),
      ];

      when(() => mockDio.get<dynamic>(
            '/risk-zones',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => Response(
          data: responseData,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/risk-zones'),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockDio),
        ],
      );
      addTearDown(container.dispose);

      const center = LatLng(19.43, -99.13);
      final zones = await container.read(activeRiskZonesProvider(center).future);

      expect(zones, hasLength(3));
      expect(zones[0].riskLevel, 'HIGH');
      expect(zones[1].riskLevel, 'MEDIUM');
      expect(zones[2].riskLevel, 'LOW');
    });

    test('solo incluye zonas activas (active=true) cuando el backend filtra', () async {
      // The API should only return active zones; this test validates client mapping
      final mockDio = MockDio();
      final responseData = [
        _riskZoneJson(id: 'zone-active', active: true),
        // Backend filters inactive zones; client receives only active ones
      ];

      when(() => mockDio.get<dynamic>(
            '/risk-zones',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => Response(
          data: responseData,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/risk-zones'),
        ),
      );

      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(mockDio)],
      );
      addTearDown(container.dispose);

      const center = LatLng(19.43, -99.13);
      final zones = await container.read(activeRiskZonesProvider(center).future);

      expect(zones, hasLength(1));
      expect(zones.first.active, isTrue);
    });

    test('lanza DioException cuando la API devuelve 500', () async {
      final mockDio = MockDio();

      when(() => mockDio.get<dynamic>(
            '/risk-zones',
            queryParameters: any(named: 'queryParameters'),
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

      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(mockDio)],
      );
      addTearDown(container.dispose);

      const center = LatLng(19.43, -99.13);
      await expectLater(
        container.read(activeRiskZonesProvider(center).future),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('RiskZone.fromJson — mapeo de esquema (SDD §7.2.3)', () {
    test('campos obligatorios created_at y expires_at se parsean correctamente',
        () {
      final json = _riskZoneJson();
      final zone = RiskZone.fromJson(json);

      expect(zone.id, 'zone-1');
      expect(zone.riskLevel, 'HIGH');
      expect(zone.active, isTrue);
      // createdAt and expiresAt are required DateTime fields (non-nullable)
      // Both are parsed from the JSON strings provided in the fixture
      expect(zone.createdAt, isA<DateTime>());
      expect(zone.expiresAt, isA<DateTime>());
      expect(zone.expiresAt.isAfter(zone.createdAt), isTrue);
      expect(zone.expiredAt, isNull);
    });

    test('expired_at es null cuando la zona no ha expirado', () {
      final json = _riskZoneJson()..remove('expired_at');
      json['expired_at'] = null;
      final zone = RiskZone.fromJson(json);
      expect(zone.expiredAt, isNull);
    });
  });

  group('riskZoneRefreshProvider — actualización por FCM', () {
    test('incrementar riskZoneRefreshProvider vuelve a ejecutar el provider',
        () async {
      int callCount = 0;
      final mockDio = MockDio();

      when(() => mockDio.get<dynamic>(
            '/risk-zones',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async {
        callCount++;
        return Response(
          data: <dynamic>[],
          statusCode: 200,
          requestOptions: RequestOptions(path: '/risk-zones'),
        );
      });

      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(mockDio)],
      );
      addTearDown(container.dispose);

      const center = LatLng(19.43, -99.13);

      // First call
      await container.read(activeRiskZonesProvider(center).future);
      expect(callCount, 1);

      // Simulate FCM trigger (increment refresh counter)
      container.read(riskZoneRefreshProvider.notifier).state++;

      // Second call after invalidation
      await container.read(activeRiskZonesProvider(center).future);
      expect(callCount, 2);
    });
  });
}
