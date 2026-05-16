import 'package:flutter/foundation.dart';
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
  // Use a ChangeNotifier as refreshListenable instead of ref.watch so that
  // authStateProvider changes trigger only a redirect re-evaluation, NOT a
  // full GoRouter recreation. Recreating GoRouter resets the navigation stack
  // to initialLocation ('/splash'), which disposed all route widget states
  // mid-session (e.g., DrawerModule._rideEnabled reset to null on token refresh).
  final authNotifier = _AuthChangeNotifier();
  ref.listen(authStateProvider, (_, __) => authNotifier.notify());
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateProvider).valueOrNull != null;
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

class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
