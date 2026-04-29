import 'package:flutter/material.dart';

import '../../../core/design_system/colors.dart';
import '../models/community_report.dart';

/// [iter.2] Detail panel shown when the user taps a community report marker (CU-05).
/// CU-06 (voting) will be wired here in F8.
class ReportMarkerPanel extends StatelessWidget {
  const ReportMarkerPanel({
    super.key,
    required this.report,
    required this.onClose,
  });

  final CommunityReport report;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final typeLabel = report.threatType == ThreatType.animalMuerto
        ? 'Animal muerto'
        : 'Zona sucia';
    final statusLabel = switch (report.status) {
      ReportStatus.pendingValidation => 'Pendiente',
      ReportStatus.confirmed => 'Validado',
      ReportStatus.dismissed => 'Descartado',
      ReportStatus.expired => 'Expirado',
    };
    final iconColor = report.threatType == ThreatType.animalMuerto
        ? AppColors.neutral900
        : const Color(0xFF795548);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.coronavirus_outlined, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    typeLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Estado: $statusLabel',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${report.confirmCount} confirmaciones · ${report.dismissCount} rechazos',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (report.isDuplicate) ...[
              const SizedBox(height: 4),
              const Chip(label: Text('Reporte agrupado')),
            ],
          ],
        ),
      ),
    );
  }
}
