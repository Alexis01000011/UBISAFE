import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/identity/auth/auth_module.dart';
import '../features/identity/auth/screens/welcome_screen.dart';
import '../features/identity/auth/screens/login_screen.dart';
import '../features/identity/auth/screens/signup_screen.dart';
import '../features/identity/profile/screens/profile_screen.dart';
import '../features/identity/profile/screens/history_screen.dart';
import '../features/dispatching/screens/map_screen_buyer.dart';
import '../features/dispatching/screens/map_screen_vendor.dart';
import '../features/dispatching/screens/tracking_screen.dart';
import '../features/community/screens/community_reports_history_screen.dart'; // [iter.2]

/// Riverpod provider that exposes the app's [GoRouter] instance.
///
/// Redirect logic: unauthenticated users are always sent to `/welcome`.
///
/// [iter.2] Added routes:
///   • `/community/reports` — user's community-report history.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (!isLoggedIn && !isAuthRoute) return '/welcome';
      if (isLoggedIn && isAuthRoute) return '/map/buyer';
      return null;
    },
    routes: [
      // ── Identity ───────────────────────────────────────────────────────
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),

      // ── Dispatching ────────────────────────────────────────────────────
      GoRoute(path: '/map/buyer', builder: (_, __) => const MapScreenBuyer()),
      GoRoute(
          path: '/map/vendor', builder: (_, __) => const MapScreenVendor()),
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
