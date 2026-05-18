import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/colors.dart';
import '../../identity/auth/auth_module.dart';
import '../models/community_report.dart';
import '../services/report_validation_module.dart';

/// W-CU06-02 — Detail view for a community report with confirm/dismiss voting (CU-06).
class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({super.key, required this.report});

  final CommunityReport report;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  bool _voting = false;
  CommunityReport? _current;

  @override
  void initState() {
    super.initState();
    _current = widget.report;
  }

  Future<void> _vote(String vote) async {
    setState(() => _voting = true);
    try {
      final updated = await ref
          .read(reportValidationModuleProvider)
          .vote(reportId: _current!.id, vote: vote);
      if (mounted) setState(() => _current = updated);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al votar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _current!;
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final currentUid = currentUser?.uid ?? '';

    final typeLabel = report.threatType == ThreatType.animalMuerto
        ? 'Animal muerto'
        : 'Zona sucia';
    final iconColor = report.threatType == ThreatType.animalMuerto
        ? AppColors.neutral900
        : const Color(0xFF795548);
    final statusLabel = switch (report.status) {
      ReportStatus.pendingValidation => 'Pendiente de validación',
      ReportStatus.confirmed => 'Validado',
      ReportStatus.dismissed => 'Descartado',
      ReportStatus.expired => 'Expirado',
    };

    final isReporter = report.reporterUid == currentUid;
    final alreadyVoted =
        report.validations.any((v) => v['user_uid'] == currentUid);
    final canVote = !isReporter &&
        !alreadyVoted &&
        report.status == ReportStatus.pendingValidation;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del reporte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.coronavirus_outlined, color: iconColor, size: 32),
                const SizedBox(width: 12),
                Text(typeLabel,
                    style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Estado', value: statusLabel),
            _InfoRow(
              label: 'Confirmaciones',
              value: report.confirmCount.toString(),
            ),
            _InfoRow(label: 'Rechazos', value: report.dismissCount.toString()),
            if (report.isDuplicate) ...[
              const SizedBox(height: 8),
              const Chip(label: Text('Reporte agrupado')),
            ],
            const Divider(height: 32),
            if (!canVote) ...[
              Text(
                isReporter
                    ? 'No puedes votar en tu propio reporte.'
                    : alreadyVoted
                        ? 'Ya votaste en este reporte.'
                        : 'Este reporte ya no está disponible para votar.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ] else ...[
              Text(
                '¿Este reporte es válido?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _voting ? null : () => _vote('confirm'),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _voting ? null : () => _vote('dismiss'),
                      icon: const Icon(Icons.close),
                      label: const Text('Descartar'),
                    ),
                  ),
                ],
              ),
              if (_voting)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }
}
