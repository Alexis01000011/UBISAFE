import 'package:flutter/material.dart';

import '../../../../core/design_system/colors.dart';
import '../../../../core/design_system/typography.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary700,
      body: Center(
        child: Text(
          'UbiSafe',
          style: AppTypography.display.copyWith(color: AppColors.neutral0),
        ),
      ),
    );
  }
}
