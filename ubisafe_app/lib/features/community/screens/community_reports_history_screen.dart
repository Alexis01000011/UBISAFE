import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/colors.dart';
import '../models/community_report.dart';
import '../services/community_report_module.dart';

class CommunityReportsHistoryScreen extends ConsumerWidget {
  const CommunityReportsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(activeCommunityReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes comunitarios')),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(
              child: Text('No hay reportes activos en tu zona'),
            );
          }
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final r = reports[index];
              final label = r.threatType == ThreatType.animalMuerto
                  ? 'Animal muerto'
                  : 'Zona sucia';
              final statusLabel = switch (r.status) {
                ReportStatus.pendingValidation => 'Pendiente',
                ReportStatus.confirmed => 'Validado',
                ReportStatus.dismissed => 'Descartado',
                ReportStatus.expired => 'Expirado',
              };
              return ListTile(
                leading: Icon(
                  Icons.report_problem,
                  color: r.threatType == ThreatType.animalMuerto
                      ? AppColors.neutral900
                      : const Color(0xFF795548),
                ),
                title: Text(label),
                subtitle: Text('${r.confirmCount} confirmaciones · $statusLabel'),
                trailing: r.isDuplicate
                    ? const Chip(label: Text('Agrupado'))
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
