import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ubisafe_app/core/design_system/colors.dart';
import 'package:ubisafe_app/core/design_system/theme.dart';

void main() {
  // AppTheme.light uses GoogleFonts.inter() for typography, which triggers
  // async font loading. In tests there are no bundled font assets and no
  // network, so font loading always fails. We suppress those errors inside
  // testWidgets (where FlutterError.onError is managed by the binding) and
  // verify only the color-token contract, which is independent of typography.
  testWidgets('AppTheme.light — color tokens and Material 3', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    final origHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exception.toString();
      if (msg.contains('allowRuntimeFetching') || msg.contains('Inter-')) return;
      origHandler?.call(details);
    };

    final theme = AppTheme.light;

    // Drain microtasks so font-load failures propagate through our handler
    // before it is restored.
    await tester.pump();

    FlutterError.onError = origHandler;
    GoogleFonts.config.allowRuntimeFetching = true;

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.appBarTheme.backgroundColor, AppColors.primary700);
    expect(theme.colorScheme.primary, AppColors.primary700);
    expect(theme.colorScheme.secondary, AppColors.secondary700);
    expect(theme.colorScheme.error, AppColors.danger500);
    expect(
      theme.floatingActionButtonTheme.backgroundColor,
      AppColors.warning700,
    );
  });
}
