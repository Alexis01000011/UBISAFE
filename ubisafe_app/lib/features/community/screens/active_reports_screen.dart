import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/colors.dart';
import '../../../core/design_system/typography.dart';
import '../../../features/presence/services/gps_service.dart';
import '../models/community_report.dart';
import '../services/community_report_module.dart';

/// W-CU06-01 — List of active community reports in the user's zone.
class ActiveReportsScreen extends ConsumerWidget {
  const ActiveReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-subscribe the stream when GPS transitions from unavailable to available.
    ref.listen(gpsServiceProvider, (prev, next) {
      if (prev?.valueOrNull == null && next.valueOrNull != null) {
        ref.invalidate(activeCommunityReportsProvider);
      }
    });

    final positionAsync = ref.watch(gpsServiceProvider);
    final reportsAsync = ref.watch(activeCommunityReportsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Reportes activos',
          style: AppTypography.heading2.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primary700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar los reportes. Intenta de nuevo.',
              textAlign: TextAlign.center,
              style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            // Distinguish between "GPS off" and "no nearby reports".
            final gpsAvailable = positionAsync.valueOrNull != null;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  gpsAvailable
                      ? 'No hay reportes activos en tu zona'
                      : 'Activa el GPS para ver reportes cercanos.',
                  textAlign: TextAlign.center,
                  style:
                      AppTypography.body1.copyWith(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = reports[index];
              final label = switch (r.threatType) {
                ThreatType.animalMuerto => 'Animal muerto',
                ThreatType.zonaSucia => 'Zona sucia',
                ThreatType.loteBaldio => 'Lote baldío',
              };
              final statusLabel = switch (r.status) {
                ReportStatus.pendingValidation => 'Pendiente',
                ReportStatus.confirmed => 'Validado',
                ReportStatus.dismissed => 'Descartado',
                ReportStatus.expired => 'Expirado',
                ReportStatus.resolved => 'Resuelto',
              };
              return ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Icon(
                  Icons.report_problem,
                  color: r.threatType == ThreatType.animalMuerto
                      ? AppColors.neutral900
                      : const Color(0xFF795548),
                ),
                title: Text(
                  label,
                  style:
                      AppTypography.body1.copyWith(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  '${r.confirmCount} confirmaciones · $statusLabel',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                trailing: r.isDuplicate
                    ? const Chip(label: Text('Agrupado'))
                    : const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                onTap: () =>
                    context.push('/community/reports/detail', extra: r),
              );
            },
          );
        },
      ),
    );
  }
}
