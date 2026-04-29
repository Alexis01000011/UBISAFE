import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/design_system/colors.dart';
import '../../../../core/design_system/spacing.dart';
import '../../../../core/design_system/typography.dart';
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
      backgroundColor: AppColors.background,
      child: profileAsync.maybeWhen(
        data: (profile) {
          final isVendor = profile?.role == 'vendor' || profile?.role == 'VENDOR';
          _rideEnabled ??= profile?.rideEnabled ?? false;

          final userName = profile?.name ?? 'UbiSafe User';
          final userRole = profile?.role?.toUpperCase() ?? '';

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  top: AppSpacing.xxl + 20, // To account for status bar
                  bottom: AppSpacing.lg,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primary700,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child: Text(
                        userName[0].toUpperCase(),
                        style: AppTypography.heading1.copyWith(
                          color: AppColors.primary700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      userName,
                      style: AppTypography.heading2.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (userRole.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isVendor ? AppColors.secondary500 : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          userRole,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.person_outline,
                      title: 'Mi Perfil',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/profile');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.history_outlined,
                      title: 'Historial',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/history');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.map_outlined,
                      title: 'Reportes Activos',
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/community/reports');
                      },
                    ),
                    if (isVendor) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        child: Divider(color: AppColors.border),
                      ),
                      SwitchListTile(
                        activeThumbColor: AppColors.primary700,
                        secondary: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.secondary50,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.electric_rickshaw_outlined, color: AppColors.secondary700),
                          ),
                        ),
                        title: Text(
                          'Ofrecer Raites',
                          style: AppTypography.body1.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Acepta solicitudes de raite',
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        value: _rideEnabled ?? false,
                        onChanged: _rideToggling
                            ? null
                            : (val) => _toggleRideEnabled(profile!.uid, val),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger500.withOpacity(0.1),
                    foregroundColor: AppColors.danger500,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(authModuleProvider).signOut();
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          );
        },
        orElse: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildFallbackDrawer(),
      ),
    );
  }

  /// Drawer mínimo cuando el perfil no carga (sin red, emulador apagado, etc.)
  Widget _buildFallbackDrawer() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(
            top: AppSpacing.xxl + 20,
            bottom: AppSpacing.lg,
            left: AppSpacing.md,
            right: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.primary700,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: AppColors.primary700, size: 36),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'UbiSafe User',
                style: AppTypography.heading2.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              _buildDrawerItem(
                icon: Icons.person_outline,
                title: 'Mi Perfil',
                onTap: () { Navigator.pop(context); context.push('/profile'); },
              ),
              _buildDrawerItem(
                icon: Icons.history_outlined,
                title: 'Historial',
                onTap: () { Navigator.pop(context); context.push('/history'); },
              ),
              _buildDrawerItem(
                icon: Icons.map_outlined,
                title: 'Reportes Activos',
                onTap: () { Navigator.pop(context); context.push('/community/reports'); },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger500.withOpacity(0.1),
              foregroundColor: AppColors.danger500,
              elevation: 0,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authModuleProvider).signOut();
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary700),
      title: Text(
        title,
        style: AppTypography.body1.copyWith(color: AppColors.textPrimary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
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
      if (ref.read(gpsServiceProvider).valueOrNull != null) {
        ref.read(gpsServiceInstanceProvider).updateRideEnabled(uid, value);
      }
    } catch (_) {
      setState(() => _rideEnabled = !value);
    } finally {
      setState(() => _rideToggling = false);
    }
  }
}
