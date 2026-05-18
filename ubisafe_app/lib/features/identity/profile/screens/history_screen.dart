import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/colors.dart';
import '../../../../core/design_system/spacing.dart';
import '../../../../core/design_system/typography.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../auth/auth_module.dart';

final historyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];

  // Role is stored in Firestore (via /auth/sync-profile), not in Firebase
  // custom claims. Read from userProfileProvider to get the correct role.
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return [];

  final role = profile.role?.toLowerCase() ?? 'buyer';
  final fieldToFilter = role == 'vendor' ? 'vendor_uid' : 'buyer_uid';

  // Avoid composite-index requirement by sorting client-side.
  final snapshot = await FirebaseFirestore.instance
      .collection('rides')
      .where(fieldToFilter, isEqualTo: user.uid)
      .where('status', whereIn: ['completed', 'rejected', 'expired'])
      .get();

  final docs = snapshot.docs
      .map((doc) => {'id': doc.id, ...doc.data()})
      .toList();

  docs.sort((a, b) {
    final aTs = a['updated_at'] as Timestamp?;
    final bTs = b['updated_at'] as Timestamp?;
    if (aTs == null && bTs == null) return 0;
    if (aTs == null) return 1;
    if (bTs == null) return -1;
    return bTs.compareTo(aTs);
  });

  return docs;
});

/// Displays the history of completed/rejected/expired trips for the current user.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Historial de Viajes', style: AppTypography.heading2.copyWith(color: Colors.white)),
        backgroundColor: AppColors.primary700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: historyAsync.when(
        data: (rides) {
          if (rides.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Aún no tienes viajes registrados', style: AppTypography.body1),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final ride = rides[index];
              final status = ride['status'] as String? ?? 'unknown';
              final timestamp = ride['updated_at'] as Timestamp?;
              final dateStr = timestamp != null
                  ? DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate())
                  : 'Fecha desconocida';

              final Color statusColor;
              final IconData statusIcon;
              final String statusLabel;
              switch (status) {
                case 'completed':
                  statusColor = AppColors.success500;
                  statusIcon = Icons.check_circle_outline;
                  statusLabel = 'Viaje Completado';
                case 'rejected':
                  statusColor = AppColors.danger500;
                  statusIcon = Icons.cancel_outlined;
                  statusLabel = 'Viaje Rechazado';
                case 'expired':
                  statusColor = AppColors.textSecondary;
                  statusIcon = Icons.timer_off_outlined;
                  statusLabel = 'Viaje Expirado';
                default:
                  statusColor = AppColors.textSecondary;
                  statusIcon = Icons.help_outline;
                  statusLabel = 'Estado desconocido';
              }

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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusLabel,
                            style: AppTypography.body1.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(dateStr, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error al cargar historial: $e')),
      ),
    );
  }
}
