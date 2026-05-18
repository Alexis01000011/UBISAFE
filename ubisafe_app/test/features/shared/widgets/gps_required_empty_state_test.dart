import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubisafe_app/features/presence/services/gps_service.dart';
import 'package:ubisafe_app/features/shared/widgets/gps_required_empty_state.dart';

Widget _wrap({
  required GpsStatus status,
  VoidCallback? onResolved,
}) {
  return ProviderScope(
    overrides: [
      gpsStatusProvider.overrideWith((ref) => Stream.value(status)),
    ],
    child: MaterialApp(
      home: GpsRequiredEmptyState(onResolved: onResolved),
    ),
  );
}

void main() {
  group('GpsRequiredEmptyState', () {
    testWidgets('shows correct title for permissionDenied', (tester) async {
      await tester.pumpWidget(_wrap(status: GpsStatus.permissionDenied));
      await tester.pump(); // allow StreamProvider to deliver first value
      expect(find.text('Necesitamos tu ubicación'), findsOneWidget);
    });

    testWidgets('shows CTA "Conceder permiso" for permissionDenied',
        (tester) async {
      await tester.pumpWidget(_wrap(status: GpsStatus.permissionDenied));
      await tester.pump();
      expect(find.text('Conceder permiso'), findsOneWidget);
    });

    testWidgets('shows correct title for serviceOff', (tester) async {
      await tester.pumpWidget(_wrap(status: GpsStatus.serviceOff));
      await tester.pump();
      expect(find.text('Activa el GPS'), findsOneWidget);
    });

    testWidgets('shows CTA "Abrir ajustes de ubicación" for serviceOff',
        (tester) async {
      await tester.pumpWidget(_wrap(status: GpsStatus.serviceOff));
      await tester.pump();
      expect(find.text('Abrir ajustes de ubicación'), findsOneWidget);
    });

    testWidgets('calls onResolved when status changes to ready',
        (tester) async {
      var resolved = false;
      final ctrl = StreamController<GpsStatus>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gpsStatusProvider.overrideWith((ref) {
              ref.onDispose(ctrl.close);
              return ctrl.stream;
            }),
          ],
          child: MaterialApp(
            home: GpsRequiredEmptyState(
              onResolved: () => resolved = true,
            ),
          ),
        ),
      );

      ctrl.add(GpsStatus.serviceOff);
      await tester.pump();

      ctrl.add(GpsStatus.ready);
      await tester.pump();

      expect(resolved, isTrue);
    });

    testWidgets('returns SizedBox.shrink when status is ready', (tester) async {
      await tester.pumpWidget(_wrap(status: GpsStatus.ready));
      await tester.pump();
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('Necesitamos tu ubicación'), findsNothing);
      expect(find.text('Activa el GPS'), findsNothing);
    });
  });
}
