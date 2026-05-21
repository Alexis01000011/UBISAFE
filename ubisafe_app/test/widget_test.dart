import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ubisafe_app/features/shared/notifications/notification_handler.dart';
import 'package:ubisafe_app/main.dart';
import 'package:ubisafe_app/router/app_router.dart';

class _FakeNotificationHandler extends Fake implements NotificationHandler {
  @override
  Future<void> init() async {}
}

void main() {
  testWidgets('UbiSafe app bootstraps', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationHandlerProvider
              .overrideWithValue(_FakeNotificationHandler()),
          appRouterProvider.overrideWith(
            (ref) => GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, __) => const SizedBox()),
              ],
            ),
          ),
        ],
        child: const UbiSafeApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
