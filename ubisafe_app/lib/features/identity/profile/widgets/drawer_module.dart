import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_module.dart';

/// App-wide navigation drawer.
///
/// [iter.2] Will include:
///   • Toggle `ride_enabled` for vendor mode.
///   • Active community reports badge.
class DrawerModule extends ConsumerWidget {
  const DrawerModule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return Drawer(
      child: userAsync.maybeWhen(
        data: (user) => ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('UbiSafe'),
              accountEmail: Text(user?.email ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Perfil'),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial'),
              onTap: () {
                Navigator.pop(context);
                context.go('/history');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authModuleProvider).signOut();
              },
            ),
          ],
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}
