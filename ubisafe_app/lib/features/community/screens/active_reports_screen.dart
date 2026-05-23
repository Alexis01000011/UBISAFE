import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/colors.dart';
import '../../../core/design_system/typography.dart';
import '../../../features/presence/services/gps_service.dart';
import '../models/community_report.dart';
import '../services/community_report_module.dart';

/// W-CU06-01 — List of active community reports in the user's zone.
class ActiveReportsScreen extends ConsumerStatefulWidget {
  const ActiveReportsScreen({super.key});

  @override
  ConsumerState<ActiveReportsScreen> createState() =>
      _ActiveReportsScreenState();
}

class _ActiveReportsScreenState extends ConsumerState<ActiveReportsScreen> {
  @override
  void initState() {
    super.initState();
    // If the user arrives here directly (e.g., from the drawer) without having
    // visited a map screen first, the notifier has no coordinates and stays
    // in AsyncValue.loading() forever. Trigger the initial load from GPS.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNeeded());
  }

  void _loadIfNeeded() {
    if (!mounted) return;
    final notifier = ref.read(activeCommunityReportsProvider.notifier);
    if (notifier.hasCoordinates) return; // already loaded by a map screen
    final position = ref.read(gpsServiceProvider).valueOrNull;
    if (position == null) {
      // GPS unavailable: replace the eternal spinner with an error state so
      // the user sees a meaningful message instead of an infinite loader.
      notifier.setGpsUnavailable();
      return;
    }
    notifier.load(lat: position.latitude, lng: position.longitude);
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar',
            // B29 — if GPS was unavailable when the screen loaded, _lat/_lng
            // are null and refresh() is a no-op. Replicate _loadIfNeeded so
            // that tapping Refresh after enabling GPS actually works.
            onPressed: () {
              final notifier =
                  ref.read(activeCommunityReportsProvider.notifier);
              if (notifier.hasCoordinates) {
                notifier.refresh();
              } else {
                final position = ref.read(gpsServiceProvider).valueOrNull;
                if (position != null) {
                  notifier.load(
                      lat: position.latitude, lng: position.longitude);
                } else {
                  notifier.setGpsUnavailable();
                }
              }
            },
          ),
        ],
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString().contains('gps_unavailable')
                  ? 'Activa el GPS para ver reportes cercanos.'
                  : 'No se pudieron cargar los reportes. Intenta de nuevo.',
              textAlign: TextAlign.center,
              style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(
              child: Text('No hay reportes activos en tu zona'),
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
