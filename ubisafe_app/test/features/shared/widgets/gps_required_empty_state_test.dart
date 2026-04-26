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
      gpsStatusProvider.overrideWith((ref) => status),
    ],
    child: MaterialApp(
      home: GpsRequiredEmptyState(onResolved: onResolved),
    ),
  );
}

void main() {
  group('GpsRequiredEmptyState', () {
    testWidgets('shows correct title for permissionDenied', (tester) async {
      await tester.pumpWidget(
        _wrap(status: GpsStatus.permissionDenied),
      );
      expect(find.text('Necesitamos tu ubicación'), findsOneWidget);
    });

    testWidgets('shows CTA "Conceder permiso" for permissionDenied',
        (tester) async {
      await tester.pumpWidget(
        _wrap(status: GpsStatus.permissionDenied),
      );
      expect(find.text('Conceder permiso'), findsOneWidget);
    });

    testWidgets('shows correct title for serviceOff', (tester) async {
      await tester.pumpWidget(
        _wrap(status: GpsStatus.serviceOff),
      );
      expect(find.text('Activa el GPS'), findsOneWidget);
    });

    testWidgets('shows CTA "Abrir ajustes de ubicación" for serviceOff',
        (tester) async {
      await tester.pumpWidget(
        _wrap(status: GpsStatus.serviceOff),
      );
      expect(find.text('Abrir ajustes de ubicación'), findsOneWidget);
    });

    testWidgets('calls onResolved when status changes to ready', (tester) async {
      var resolved = false;
      final container = ProviderContainer(
        overrides: [
          gpsStatusProvider.overrideWith((ref) => GpsStatus.serviceOff),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GpsRequiredEmptyState(
              onResolved: () => resolved = true,
            ),
          ),
        ),
      );

      container.read(gpsStatusProvider.notifier).state = GpsStatus.ready;
      await tester.pump();

      expect(resolved, isTrue);
    });

    testWidgets('returns SizedBox.shrink when status is ready', (tester) async {
      await tester.pumpWidget(
        _wrap(status: GpsStatus.ready),
      );
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('Necesitamos tu ubicación'), findsNothing);
      expect(find.text('Activa el GPS'), findsNothing);
    });
  });
}
