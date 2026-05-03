import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/colors.dart';
import '../../../../core/design_system/spacing.dart';
import '../../../../core/design_system/typography.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../auth/auth_module.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Mi Perfil', style: AppTypography.heading2.copyWith(color: Colors.white)),
        backgroundColor: AppColors.primary700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Sin sesión'));
          }

          return profileAsync.when(
            data: (profile) {
              final role = profile?.role ?? 'Desconocido';
              final name = profile?.name ?? 'Usuario';
              final phone = profile?.phone ?? 'N/A';
              final isVendor = role.toUpperCase() == 'VENDOR';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primary700.withValues(alpha: 0.1),
                        child: Text(
                          name[0].toUpperCase(),
                          style: AppTypography.heading1.copyWith(
                            color: AppColors.primary700,
                            fontSize: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: AppTypography.heading2,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isVendor ? AppColors.secondary500 : AppColors.primary700,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      title: 'Correo electrónico',
                      value: user.email ?? 'Sin correo',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildInfoCard(
                      icon: Icons.phone_outlined,
                      title: 'Teléfono',
                      value: phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildInfoCard(
                      icon: Icons.badge_outlined,
                      title: 'ID de Usuario',
                      value: user.uid,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar Sesión'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                        ),
                      ),
                      onPressed: () => ref.read(authModuleProvider).signOut(),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error al cargar perfil: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary700, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: AppTypography.body1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
