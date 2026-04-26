import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ubisafe_app/main.dart';

void main() {
  testWidgets('UbiSafe app bootstraps', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: UbiSafeApp()));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
