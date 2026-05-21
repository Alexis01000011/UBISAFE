import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/community/models/community_report.dart';
import '../features/community/screens/active_reports_screen.dart';
import '../features/community/screens/report_detail_screen.dart';
import '../features/dispatching/group_stays/screens/schedule_group_stay_screen.dart';
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
import '../features/shared/subscriptions/screens/subscriptions_screen.dart';

/// Auth-guard paths — allowed without a session.
const _authPaths = {
  '/splash',
  '/welcome',
  '/login',
  '/signup-data',
  '/signup-role'
};

final appRouterProvider = Provider<GoRouter>((ref) {
  // _AuthChangeNotifier subscribes DIRECTLY to Firebase Auth's stream so that
  // GoRouter's redirect fires in the same microtask as the auth state change,
  // with no Riverpod scheduling in between. Using ref.listen caused a race
  // where the redirect was evaluated before authStateProvider had processed
  // the new user, leaving the login screen stuck on the loading spinner.
  final authNotifier = _AuthChangeNotifier();
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      // FirebaseAuth.instance.currentUser is synchronous and always reflects
      // the current user immediately after signIn/signOut, so it is safe to
      // read here even before authStateProvider has processed the stream event.
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
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
      GoRoute(
        path: '/subscriptions',
        builder: (_, __) => const SubscriptionsScreen(),
      ),

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

      // ── Group Stays [iter.3 CU-09] ────────────────────────────────────────
      GoRoute(
        path: '/group-stays/schedule',
        builder: (_, __) => const ScheduleGroupStayScreen(),
      ),

      // ── Community [iter.2] ─────────────────────────────────────────────
      GoRoute(
        path: '/community/reports',
        builder: (_, __) => const ActiveReportsScreen(),
      ),
      GoRoute(
        path: '/community/reports/detail',
        builder: (_, state) {
          // B31 — state.extra is lost on Android process death or direct deep
          // links. Fall back to the list screen instead of crashing.
          final extra = state.extra;
          if (extra is! CommunityReport) return const ActiveReportsScreen();
          return ReportDetailScreen(report: extra);
        },
      ),
    ],
  );
});

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
