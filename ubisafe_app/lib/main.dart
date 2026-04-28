import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design_system/theme.dart';
import 'features/shared/notifications/notification_handler.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  if (kDebugMode) {
    await _connectToEmulators();
  }

  runApp(
    const ProviderScope(child: UbiSafeApp()),
  );
}

/// Wires Firebase SDKs to local emulators when running in debug mode.
Future<void> _connectToEmulators() async {
  const host = 'localhost';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099,
      automaticHostMapping: false);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);
}

class UbiSafeApp extends ConsumerWidget {
  const UbiSafeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Initialize FCM after the widget tree is ready.
    ref.read(notificationHandlerProvider).init();

    return MaterialApp.router(
      title: 'UbiSafe',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
