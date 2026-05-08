import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';
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

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      _go('/welcome');
      return;
    }

    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.get<Map<String, dynamic>>(
        '/auth/me',
        // Skip to the last retry so the interceptor only makes one extra
        // attempt — avoids blocking the splash for 40+ seconds on cold start.
        options: Options(extra: {'_retryCount': 2}),
      );
      final profile = UserProfile.fromJson(response.data!);
      _go(profile.role == 'VENDOR' ? '/home/vendor' : '/home/buyer');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Confirmed: no profile in Firestore (partial registration).
        // Sign out so the router doesn't redirect authenticated user to /splash.
        try { await ref.read(authModuleProvider).signOut(); } catch (_) {}
      }
      // Any other error (Render cold start, network outage, 5xx) → do NOT sign
      // out. The Firebase Auth session is still valid. The user stays
      // authenticated and will be redirected to /splash again on the next
      // login tap, which retries GET /auth/me once Render is warm.
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
