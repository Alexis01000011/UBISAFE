// risk_zone_service_test.dart
// Tests unitarios para el modelo RiskZone (CU-03).
// Los tests del StreamProvider requieren Firestore real o fake_cloud_firestore;
// aquí se cubren los factories fromJson y fromFirestore sin conexión de red.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ubisafe_app/features/safety/models/risk_zone.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

Map<String, dynamic> _jsonFixture({
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

Map<String, dynamic> _firestoreFixture({
  String riskLevel = 'HIGH',
  bool active = true,
  bool nativeTimestamps = false,
}) {
  final createdAt = DateTime.utc(2025, 5, 1, 10);
  final expiresAt = DateTime.utc(2025, 5, 2, 10);
  return {
    'reporter_uid': 'user-reporter',
    'threat_type': 'robo',
    'risk_level': riskLevel,
    'location': {'lat': 19.43, 'lng': -99.13},
    'radius_meters': 100,
    'active': active,
    // created_at llega como Timestamp (SERVER_TIMESTAMP en Firestore),
    // expires_at llega como String ISO (isoformat() del backend Python).
    'created_at': nativeTimestamps
        ? Timestamp.fromDate(createdAt)
        : createdAt.toIso8601String(),
    'expires_at': nativeTimestamps
        ? Timestamp.fromDate(expiresAt)
        : expiresAt.toIso8601String(),
    'expired_at': null,
  };
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('RiskZone.fromJson — mapeo desde REST API (SDD §7.2.3)', () {
    test('campos obligatorios se parsean correctamente', () {
      final zone = RiskZone.fromJson(_jsonFixture());
      expect(zone.id, 'zone-1');
      expect(zone.riskLevel, 'HIGH');
      expect(zone.active, isTrue);
      expect(zone.createdAt, isA<DateTime>());
      expect(zone.expiresAt, isA<DateTime>());
      expect(zone.expiresAt.isAfter(zone.createdAt), isTrue);
      expect(zone.expiredAt, isNull);
    });

    test('expired_at null cuando la zona no ha expirado', () {
      final json = _jsonFixture();
      json['expired_at'] = null;
      expect(RiskZone.fromJson(json).expiredAt, isNull);
    });

    test('mapea los tres niveles de riesgo', () {
      for (final level in ['HIGH', 'MEDIUM', 'LOW']) {
        expect(
          RiskZone.fromJson(_jsonFixture(riskLevel: level)).riskLevel,
          level,
        );
      }
    });
  });

  group('RiskZone.fromFirestore — mapeo desde snapshot en tiempo real', () {
    test('parsea fechas como String ISO (ruta habitual del backend Python)', () {
      final zone = RiskZone.fromFirestore('zone-fs-1', _firestoreFixture());
      expect(zone.id, 'zone-fs-1');
      expect(zone.riskLevel, 'HIGH');
      expect(zone.active, isTrue);
      expect(zone.createdAt, isA<DateTime>());
      expect(zone.expiresAt, isA<DateTime>());
      expect(zone.expiresAt.isAfter(zone.createdAt), isTrue);
      expect(zone.expiredAt, isNull);
    });

    test('parsea created_at como Timestamp nativo de Firestore', () {
      final zone =
          RiskZone.fromFirestore('zone-fs-2', _firestoreFixture(nativeTimestamps: true));
      expect(zone.createdAt, isA<DateTime>());
      expect(zone.expiresAt, isA<DateTime>());
    });

    test('zona inactiva (active=false) se mapea correctamente', () {
      final zone =
          RiskZone.fromFirestore('zone-fs-3', _firestoreFixture(active: false));
      expect(zone.active, isFalse);
    });

    test('expired_at como Timestamp nativo se convierte a DateTime', () {
      final data = _firestoreFixture();
      data['expired_at'] = Timestamp.fromDate(DateTime.utc(2025, 5, 2, 10, 30));
      final zone = RiskZone.fromFirestore('zone-fs-4', data);
      expect(zone.expiredAt, isA<DateTime>());
      expect(zone.expiredAt!.minute, 30);
    });

    test('expired_at como String ISO se convierte a DateTime', () {
      final data = _firestoreFixture();
      data['expired_at'] = '2025-05-02T10:30:00.000Z';
      final zone = RiskZone.fromFirestore('zone-fs-5', data);
      expect(zone.expiredAt, isA<DateTime>());
    });
  });

  // ── Campos de desmentido CU-03 ────────────────────────────────────────────

  group('RiskZone.fromJson — campos dismiss (CU-03)', () {
    test('dismiss_count y dismissers se parsean cuando están presentes', () {
      final json = _jsonFixture()
        ..['dismiss_count'] = 2
        ..['dismissers'] = ['uid-a', 'uid-b']
        ..['dismissed_at'] = null;
      final zone = RiskZone.fromJson(json);
      expect(zone.dismissCount, 2);
      expect(zone.dismissers, ['uid-a', 'uid-b']);
      expect(zone.dismissedAt, isNull);
    });

    test('dismissed_at presente se parsea como DateTime', () {
      final json = _jsonFixture()
        ..['dismiss_count'] = 3
        ..['dismissers'] = ['u1', 'u2', 'u3']
        ..['dismissed_at'] = '2025-05-02T12:00:00.000Z'
        ..['active'] = false;
      final zone = RiskZone.fromJson(json);
      expect(zone.dismissedAt, isA<DateTime>());
      expect(zone.active, isFalse);
    });

    test('zona legacy sin campos dismiss toma valores por defecto', () {
      // Los campos dismiss_count, dismissers y dismissed_at no existen en
      // documentos creados antes de la Sesión A — el modelo debe usar defaults.
      final json = _jsonFixture(); // no contiene dismiss_count ni dismissers
      final zone = RiskZone.fromJson(json);
      expect(zone.dismissCount, 0);
      expect(zone.dismissers, isEmpty);
      expect(zone.dismissedAt, isNull);
    });
  });

  group('RiskZone.fromFirestore — campos dismiss (CU-03)', () {
    test('zona legacy sin campos dismiss toma valores por defecto', () {
      // _firestoreFixture() no incluye los campos de desmentido.
      final zone = RiskZone.fromFirestore('zone-legacy', _firestoreFixture());
      expect(zone.dismissCount, 0);
      expect(zone.dismissers, isEmpty);
      expect(zone.dismissedAt, isNull);
    });

    test('dismissers como lista de strings se parsea correctamente', () {
      final data = _firestoreFixture()
        ..['dismiss_count'] = 1
        ..['dismissers'] = ['uid-voter']
        ..['dismissed_at'] = null;
      final zone = RiskZone.fromFirestore('zone-dismiss-1', data);
      expect(zone.dismissCount, 1);
      expect(zone.dismissers, contains('uid-voter'));
    });

    test('dismissed_at como Timestamp nativo se convierte a DateTime', () {
      final data = _firestoreFixture()
        ..['dismiss_count'] = 3
        ..['dismissers'] = ['u1', 'u2', 'u3']
        ..['dismissed_at'] =
            Timestamp.fromDate(DateTime.utc(2025, 5, 2, 14, 30))
        ..['active'] = false;
      final zone = RiskZone.fromFirestore('zone-dismissed', data);
      expect(zone.dismissedAt, isA<DateTime>());
      // Verificar minutos (timezone-independent) en lugar de horas
      expect(zone.dismissedAt!.minute, 30);
      expect(zone.active, isFalse);
    });
  });
}
