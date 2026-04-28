import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/colors.dart';
import '../../../../core/design_system/typography.dart';
import '../../../../core/providers/auth_providers.dart';
import '../auth_module.dart';

/// Shows the brand splash and resolves the initial route based on session state.
///
/// SessionCheck logic (SDD §5.3.1 / §10):
///  1. Wait for Firebase Auth to emit the first value.
///  2. If authenticated → fetch profile → navigate to role-specific home.
///  3. If not authenticated → navigate to Welcome.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Give Firebase Auth time to restore the persisted session.
    _timer = Timer(const Duration(milliseconds: 500), _checkSession);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkSession() async {
    if (!mounted || _navigated) return;

    final authAsync = ref.read(authStateProvider);
    final user = authAsync.valueOrNull;

    if (user == null) {
      _go('/welcome');
      return;
    }

    try {
      final profile = await ref
          .read(userProfileProvider.future)
          .timeout(const Duration(seconds: 5));
      if (profile == null) {
        // await ref.read(authModuleProvider).signOut();
        _go('/welcome');
        return;
      }
      final home = profile.role == 'VENDOR' ? '/home/vendor' : '/home/buyer';
      _go(home);
    } on TimeoutException {
      debugPrint('SplashScreen: Firestore timeout — redirecting to welcome');
      _go('/welcome');
    } catch (_) {
      _go('/welcome');
    }
  }

  void _go(String path) {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(path);
  }

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
