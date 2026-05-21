import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ubisafe_app/features/presence/services/gps_service.dart';

class _MockDatabaseReference extends Mock implements DatabaseReference {}

class _MockOnDisconnect extends Mock implements OnDisconnect {}

class _MockPosition extends Mock implements Position {}

void main() {
  late _MockDatabaseReference mockRef;
  late _MockOnDisconnect mockDisconnect;

  setUp(() {
    mockRef = _MockDatabaseReference();
    mockDisconnect = _MockOnDisconnect();
    when(() => mockRef.onDisconnect()).thenReturn(mockDisconnect);
    when(() => mockDisconnect.remove()).thenAnswer((_) async {});
    when(() => mockRef.set(any())).thenAnswer((_) async {});
    when(() => mockRef.remove()).thenAnswer((_) async {});
  });

  GPSService makeService(Stream<Position> posStream) => GPSService(
        positionStreamFactory: (_) => posStream,
        rtdbRefFactory: (_) => mockRef,
      );

  _MockPosition pos(double lat, double lng) {
    final p = _MockPosition();
    when(() => p.latitude).thenReturn(lat);
    when(() => p.longitude).thenReturn(lng);
    return p;
  }

  group('GPSService', () {
    test('set is called with the correct RTDB shape on position arrival',
        () async {
      final ctrl = StreamController<Position>();
      final service = makeService(ctrl.stream);

      service.startTransmission('vendor-1');
      ctrl.add(pos(19.432608, -99.133209));
      await pumpEventQueue();

      final captured =
          verify(() => mockRef.set(captureAny())).captured.last as Map;
      expect(captured['lat'], closeTo(19.432608, 1e-6));
      expect(captured['lng'], closeTo(-99.133209, 1e-6));
      expect(captured['activo'], isTrue);
      expect(captured['timestamp'], isA<int>());

      service.dispose();
      await ctrl.close();
    });

    test('stateStream emits error_no_signal when position stream errors',
        () async {
      final ctrl = StreamController<Position>();
      final service = makeService(ctrl.stream);

      final states = <GPSServiceState>[];
      service.stateStream.listen(states.add);

      service.startTransmission('vendor-1');
      ctrl.addError(Exception('GPS timeout'));
      await pumpEventQueue();

      expect(states, contains(GPSServiceState.error_no_signal));

      service.dispose();
      await ctrl.close();
    });

    test('stopTransmission calls remove on the RTDB node', () async {
      final ctrl = StreamController<Position>();
      final service = makeService(ctrl.stream);

      service.startTransmission('vendor-1');
      await service.stopTransmission('vendor-1');

      verify(() => mockRef.remove()).called(1);

      service.dispose();
      await ctrl.close();
    });

    test('onDisconnect is registered before the first set write', () async {
      final callOrder = <String>[];
      when(() => mockDisconnect.remove()).thenAnswer((_) async {
        callOrder.add('onDisconnect');
      });
      when(() => mockRef.set(any())).thenAnswer((_) async {
        callOrder.add('set');
      });

      final ctrl = StreamController<Position>();
      final service = makeService(ctrl.stream);

      service.startTransmission('vendor-1');
      ctrl.add(pos(0.0, 0.0));
      await pumpEventQueue();

      expect(callOrder.indexOf('set'),
          lessThan(callOrder.indexOf('onDisconnect')));

      service.dispose();
      await ctrl.close();
    });
  });
}
