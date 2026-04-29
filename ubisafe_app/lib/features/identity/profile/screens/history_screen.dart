import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/colors.dart';
import '../../../../core/design_system/spacing.dart';
import '../../../../core/design_system/typography.dart';
import '../../auth/auth_module.dart';

final historyProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];

  // Get user role from claims
  final claims = (await user.getIdTokenResult(false)).claims ?? {};
  final role = claims['role'] as String? ?? 'buyer';

  final fieldToFilter = role == 'vendor' ? 'vendor_uid' : 'buyer_uid';

  final snapshot = await FirebaseFirestore.instance
      .collection('rides')
      .where(fieldToFilter, isEqualTo: user.uid)
      .where('status', whereIn: ['completed', 'rejected', 'expired'])
      .orderBy('updated_at', descending: true)
      .get();

  return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
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
                  Icon(Icons.history_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
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
              final price = ride['offered_price'] as double? ?? 0.0;
              final timestamp = ride['updated_at'] as Timestamp?;
              final dateStr = timestamp != null 
                  ? DateFormat('dd MMM yyyy, HH:mm').format(timestamp.toDate()) 
                  : 'Fecha desconocida';

              Color statusColor;
              IconData statusIcon;
              switch (status) {
                case 'completed':
                  statusColor = AppColors.success500;
                  statusIcon = Icons.check_circle_outline;
                  break;
                case 'rejected':
                  statusColor = AppColors.danger500;
                  statusIcon = Icons.cancel_outlined;
                  break;
                case 'expired':
                  statusColor = AppColors.textSecondary;
                  statusIcon = Icons.timer_off_outlined;
                  break;
                default:
                  statusColor = AppColors.textSecondary;
                  statusIcon = Icons.help_outline;
              }

              return Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                        color: statusColor.withOpacity(0.1),
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
                            status == 'completed' ? 'Viaje Completado' : status == 'rejected' ? 'Viaje Rechazado' : 'Viaje Expirado',
                            style: AppTypography.body1.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(dateStr, style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: AppTypography.heading2.copyWith(color: AppColors.primary700),
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
