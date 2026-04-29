import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../../presence/services/gps_service.dart';
import '../../auth/auth_module.dart';

/// App-wide navigation drawer.
class DrawerModule extends ConsumerStatefulWidget {
  const DrawerModule({super.key});

  @override
  ConsumerState<DrawerModule> createState() => _DrawerModuleState();
}

class _DrawerModuleState extends ConsumerState<DrawerModule> {
  bool? _rideEnabled;
  bool _rideToggling = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Drawer(
      child: profileAsync.maybeWhen(
        data: (profile) {
          final isVendor = profile?.role == 'VENDOR';
          // Init from profile on first build
          _rideEnabled ??= profile?.rideEnabled ?? false;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(profile?.name ?? 'UbiSafe'),
                accountEmail: Text(profile?.role ?? ''),
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
              ListTile(
                leading: const Icon(Icons.coronavirus_outlined),
                title: const Text('Reportes activos'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/community/reports');
                },
              ),
              if (isVendor) ...[
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.electric_rickshaw_outlined),
                  title: const Text('Ofrecer raites'),
                  subtitle: const Text('Acepta solicitudes de raite de compradores'),
                  value: _rideEnabled ?? false,
                  onChanged: _rideToggling
                      ? null
                      : (val) => _toggleRideEnabled(profile!.uid, val),
                ),
              ],
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
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _toggleRideEnabled(String uid, bool value) async {
    setState(() {
      _rideToggling = true;
      _rideEnabled = value;
    });
    try {
      await ref.read(apiClientProvider).patch<dynamic>(
        '/auth/ride-enabled',
        data: {'ride_enabled': value},
      );
      // Also update RTDB so buyer map reflects the change immediately
      if (ref.read(gpsServiceProvider).valueOrNull != null) {
        // Only write if transmission is active (visible in RTDB)
        ref.read(gpsServiceInstanceProvider).updateRideEnabled(uid, value);
      }
    } catch (_) {
      // Revert on failure
      setState(() => _rideEnabled = !value);
    } finally {
      setState(() => _rideToggling = false);
    }
  }
}
