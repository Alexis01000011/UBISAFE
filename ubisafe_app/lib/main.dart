import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design_system/theme.dart';
import 'features/presence/services/gps_service.dart';
import 'features/shared/notifications/notification_handler.dart';
import 'router/app_router.dart';

const bool _useEmulators = bool.fromEnvironment(
  'USE_EMULATORS',
  defaultValue: kDebugMode,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  NotificationHandler.registerBackgroundHandler();

  if (_useEmulators) {
    await _connectToEmulators();
  }

  runApp(
    const ProviderScope(child: UbiSafeApp()),
  );
}

/// Wires Firebase SDKs to local emulators when running in debug mode.
Future<void> _connectToEmulators() async {
  const host = 'localhost';
  await FirebaseAuth.instance
      .useAuthEmulator(host, 9099, automaticHostMapping: false);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);
}

class UbiSafeApp extends ConsumerStatefulWidget {
  const UbiSafeApp({super.key});

  @override
  ConsumerState<UbiSafeApp> createState() => _UbiSafeAppState();
}

class _UbiSafeAppState extends ConsumerState<UbiSafeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Init FCM once — not inside build() to avoid repeated calls on rebuild.
    ref.read(notificationHandlerProvider).init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sign out (and clean up RTDB) whenever the app leaves the foreground.
    // `paused` fires reliably on Android when the user presses Home or switches
    // apps; `detached` is included as a belt-and-suspenders fallback for iOS.
    // Both are best-effort: not awaited because the engine may tear down first.
    // onDisconnect().remove() (re-registered after each GPS write) covers the
    // case where the process is killed before these futures resolve.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final gps = ref.read(gpsServiceInstanceProvider);
      final uid = gps.activeUid;
      if (uid != null) unawaited(gps.stopTransmission(uid));
      FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'UbiSafe',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
