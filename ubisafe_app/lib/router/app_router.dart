import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/identity/auth/auth_module.dart';
import '../features/community/models/community_report.dart';
import '../features/community/screens/active_reports_screen.dart';
import '../features/community/screens/report_detail_screen.dart';
import '../features/dispatching/screens/map_screen_buyer.dart';
import '../features/dispatching/screens/map_screen_vendor.dart';
import '../features/dispatching/screens/tracking_screen.dart';
import '../features/identity/auth/screens/login_screen.dart';
import '../features/identity/auth/screens/signup_data_screen.dart';
import '../features/identity/auth/screens/signup_role_screen.dart';
import '../features/identity/auth/screens/splash_screen.dart';
import '../features/identity/auth/screens/welcome_screen.dart';
import '../features/identity/profile/screens/history_screen.dart';
import '../features/identity/profile/screens/profile_screen.dart';

/// Auth-guard paths — allowed without a session.
const _authPaths = {
  '/splash',
  '/welcome',
  '/login',
  '/signup-data',
  '/signup-role'
};

final appRouterProvider = Provider<GoRouter>((ref) {
  // Only watch authStateProvider — NOT userProfileProvider.
  //
  // Watching userProfileProvider caused GoRouter to recreate a new instance
  // every time the profile loaded, which reset the navigation stack to
  // initialLocation ('/splash') mid-session. This produced a race between
  // the redirect and SplashScreen._checkSession, always losing the role.
  //
  // Role-based routing is the responsibility of the screens:
  //   • SplashScreen._checkSession — session restore on app start / after login
  //   • SignupRoleScreen — navigates directly after registration
  // The router redirect only enforces authentication guards.
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final path = state.matchedLocation;
      final isAuthPath = _authPaths.contains(path);

      // Unauthenticated user on a protected route → welcome.
      if (!isLoggedIn && !isAuthPath) return '/welcome';

      // Logged-in user still on an auth screen (other than splash which
      // routes itself): send to splash so _checkSession can route to the
      // role-appropriate home without racing against a half-loaded profile.
      // Do NOT redirect /welcome to /splash. Welcome is the intended fallback
      // for users with no Firestore profile; redirecting it would cause an
      // infinite loop (splash → null profile → signOut → welcome → splash…).
      if (isLoggedIn && isAuthPath && path != '/splash' && path != '/welcome') return '/splash';

      return null;
    },
    routes: [
      // ── Auth ───────────────────────────────────────────────────────────
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/signup-data', builder: (_, __) => const SignupDataScreen()),
      GoRoute(
        path: '/signup-role',
        builder: (_, state) {
          final extra = (state.extra as Map<String, dynamic>?) ?? {};
          return SignupRoleScreen(
            name: extra['name'] as String? ?? '',
            phone: extra['phone'] as String? ?? '',
            email: extra['email'] as String? ?? '',
            password: extra['password'] as String? ?? '',
          );
        },
      ),

      // ── Drawer ─────────────────────────────────────────────────────────
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),

      // ── Dispatching ────────────────────────────────────────────────────
      GoRoute(path: '/home/buyer', builder: (_, __) => const MapScreenBuyer()),
      GoRoute(
          path: '/home/vendor', builder: (_, __) => const MapScreenVendor()),
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
        builder: (_, __) => const ActiveReportsScreen(),
      ),
      GoRoute(
        path: '/community/reports/detail',
        builder: (_, state) {
          final report = state.extra as CommunityReport;
          return ReportDetailScreen(report: report);
        },
      ),
    ],
  );
});
