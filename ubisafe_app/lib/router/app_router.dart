import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/community/screens/community_reports_history_screen.dart';
import '../features/dispatching/screens/map_screen_buyer.dart';
import '../features/dispatching/screens/map_screen_vendor.dart';
import '../features/dispatching/screens/tracking_screen.dart';
import '../features/identity/auth/auth_module.dart';
import '../features/identity/auth/screens/login_screen.dart';
import '../features/identity/auth/screens/signup_data_screen.dart';
import '../features/identity/auth/screens/signup_role_screen.dart';
import '../features/identity/auth/screens/splash_screen.dart';
import '../features/identity/auth/screens/welcome_screen.dart';
import '../features/identity/profile/screens/history_screen.dart';
import '../features/identity/profile/screens/profile_screen.dart';

/// Auth-guard paths — allowed without a session.
const _authPaths = {'/splash', '/welcome', '/login', '/signup-data', '/signup-role'};

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final path = state.matchedLocation;
      final isAuthPath = _authPaths.contains(path);

      if (!isLoggedIn && !isAuthPath) return '/welcome';
      // When logged in and still on an auth screen, send to buyer home.
      // In F2 this will read the role from Firestore to choose buyer vs vendor.
      if (isLoggedIn && isAuthPath && path != '/splash') return '/home/buyer';
      return null;
    },
    routes: [
      // ── Auth ───────────────────────────────────────────────────────────
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup-data', builder: (_, __) => const SignupDataScreen()),
      GoRoute(
        path: '/signup-role',
        builder: (_, state) {
          final extra = (state.extra as Map<String, dynamic>?) ?? {};
          return SignupRoleScreen(
            name: extra['name'] as String? ?? '',
            phone: extra['phone'] as String? ?? '',
          );
        },
      ),

      // ── Drawer ─────────────────────────────────────────────────────────
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),

      // ── Dispatching ────────────────────────────────────────────────────
      GoRoute(path: '/home/buyer', builder: (_, __) => const MapScreenBuyer()),
      GoRoute(path: '/home/vendor', builder: (_, __) => const MapScreenVendor()),
      GoRoute(
        path: '/tracking',
        builder: (_, state) {
          final rideId = state.uri.queryParameters['ride_id'];
          final stopId = state.uri.queryParameters['stop_id'];
          return TrackingScreen(rideId: rideId, stopRequestId: stopId);
        },
      ),

      // ── Community [iter.2] ─────────────────────────────────────────────
      GoRoute(
        path: '/community/reports',
        builder: (_, __) => const CommunityReportsHistoryScreen(),
      ),
    ],
  );
});
