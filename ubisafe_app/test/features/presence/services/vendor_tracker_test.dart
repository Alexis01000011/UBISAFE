import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ubisafe_app/features/presence/services/vendor_tracker.dart';

// Approximate degrees per km at equator (latitude axis).
// 1 degree ≈ 111.19 km → 1 km ≈ 0.008993°
const _kDegPerKm = 0.008993;

Map<dynamic, dynamic> _vendorNode(double latDeg, double lngDeg) => {
      'lat': latDeg,
      'lng': lngDeg,
    };

void main() {
  group('VendorTracker.haversineKm', () {
    test('returns 0 for identical points', () {
      expect(
        VendorTracker.haversineKm(19.0, -99.0, 19.0, -99.0),
        closeTo(0.0, 0.001),
      );
    });

    test('returns ~111 km for 1 degree of latitude at equator', () {
      expect(
        VendorTracker.haversineKm(0.0, 0.0, 1.0, 0.0),
        closeTo(111.19, 0.5),
      );
    });

    test('is symmetric', () {
      final d1 = VendorTracker.haversineKm(19.0, -99.0, 20.0, -99.0);
      final d2 = VendorTracker.haversineKm(20.0, -99.0, 19.0, -99.0);
      expect(d1, closeTo(d2, 0.001));
    });
  });

  group('VendorTracker filtering', () {
    test('only emits vendors within 4 km of the buyer', () async {
      final ctrl = StreamController<Map<dynamic, dynamic>>();
      final tracker = VendorTracker.fromStream(ctrl.stream);

      // Set buyer position first so _emit has the filter origin ready.
      // Buyer at (0.0, 0.0); no listeners yet so the empty-list emission
      // from _emit is discarded by the broadcast stream.
      tracker.updateBuyerPosition(0.0, 0.0);

      final future = tracker.vendorStream.first;

      ctrl.add({
        'uid-1km': _vendorNode(1 * _kDegPerKm, 0.0), // ~1 km — inside
        'uid-5km': _vendorNode(5 * _kDegPerKm, 0.0), // ~5 km — outside
        'uid-3km': _vendorNode(3 * _kDegPerKm, 0.0), // ~3 km — inside
      });

      final result = await future;

      expect(result, hasLength(2));
      final uids = result.map((v) => v.uid).toSet();
      expect(uids, containsAll(['uid-1km', 'uid-3km']));
      expect(uids, isNot(contains('uid-5km')));

      tracker.dispose();
      await ctrl.close();
    });

    test('emits empty list when buyer position is unknown', () async {
      final ctrl = StreamController<Map<dynamic, dynamic>>();
      final tracker = VendorTracker.fromStream(ctrl.stream);
      // No updateBuyerPosition call — GPS not yet available.

      final future = tracker.vendorStream.first;

      ctrl.add({
        'uid-a': _vendorNode(10.0, 10.0),
        'uid-b': _vendorNode(20.0, 20.0),
      });

      final result = await future;
      expect(result, isEmpty);

      tracker.dispose();
      await ctrl.close();
    });

    test('emits empty list when all vendors are removed from RTDB', () async {
      final ctrl = StreamController<Map<dynamic, dynamic>>();
      final tracker = VendorTracker.fromStream(ctrl.stream);
      tracker.updateBuyerPosition(0.0, 0.0);

      final emissions = <int>[];
      tracker.vendorStream.listen((list) => emissions.add(list.length));

      ctrl.add({'uid-1': _vendorNode(1 * _kDegPerKm, 0.0)});
      await Future.microtask(() {});

      ctrl.add({});
      await Future.microtask(() {});

      tracker.dispose();
      await ctrl.close();

      expect(emissions, containsAllInOrder([1, 0]));
    });
  });
}
