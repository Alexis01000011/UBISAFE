import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/colors.dart';
import '../../identity/auth/auth_module.dart';
import '../models/community_report.dart';
import '../services/community_report_module.dart';
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
  bool _supporting = false;
  bool _resolving = false;
  CommunityReport? _current;

  @override
  void initState() {
    super.initState();
    _current = widget.report;
  }

  Future<void> _support() async {
    final snapshot = _current!;
    setState(() {
      _supporting = true;
      // optimistic update
      _current = CommunityReport(
        id: snapshot.id,
        reporterUid: snapshot.reporterUid,
        threatType: snapshot.threatType,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        radiusMeters: snapshot.radiusMeters,
        status: snapshot.status,
        validations: snapshot.validations,
        confirmCount: snapshot.confirmCount,
        dismissCount: snapshot.dismissCount,
        isDuplicate: snapshot.isDuplicate,
        canonicalReportId: snapshot.canonicalReportId,
        createdAt: snapshot.createdAt,
        updatedAt: snapshot.updatedAt,
        expiresAt: snapshot.expiresAt,
        description: snapshot.description,
        supportCount: snapshot.supportCount + 1,
        supporters: [...snapshot.supporters, ref.read(authStateProvider).valueOrNull?.uid ?? ''],
        pendingResolverUid: snapshot.pendingResolverUid,
        resolvedAt: snapshot.resolvedAt,
        resolvedByUid: snapshot.resolvedByUid,
      );
    });
    try {
      final updated = await ref
          .read(communityReportModuleProvider)
          .supportReport(snapshot.id);
      if (!mounted) return;
      setState(() => _current = updated);
      unawaited(ref.read(activeCommunityReportsProvider.notifier).refresh());
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _current = snapshot);
      final detail = (e.response?.data as Map?)?['detail'] as String?;
      final msg = switch (detail) {
        'already_supported' => 'Ya apoyaste este reporte.',
        final String s when s.startsWith('report_status_is_') =>
          'Este lote ya no está disponible para apoyar.',
        _ => 'Error al apoyar. Intenta de nuevo.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _current = snapshot);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _supporting = false);
    }
  }

  Future<void> _resolve() async {
    setState(() => _resolving = true);
    try {
      final updated = await ref
          .read(communityReportModuleProvider)
          .resolveLot(_current!.id);
      if (!mounted) return;
      setState(() => _current = updated);
      unawaited(ref.read(activeCommunityReportsProvider.notifier).refresh());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lote marcado como resuelto.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = (e.response?.data as Map?)?['detail'] as String?;
      final msg = switch (detail) {
        'not_pending_resolver' => 'Solo el tercer apoyo puede marcar como resuelto.',
        final String s when s.startsWith('report_status_is_') =>
          'Este lote ya fue resuelto.',
        _ => 'Error al resolver. Intenta de nuevo.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on Exception catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _vote(String vote) async {
    setState(() => _voting = true);
    try {
      final updated = await ref
          .read(reportValidationModuleProvider)
          .vote(reportId: _current!.id, vote: vote);
      if (!mounted) return;
      setState(() => _current = updated);
      // B33 — refresh the shared provider so the list shows the updated object
      // when the user navigates back, avoiding stale vote buttons on re-entry.
      unawaited(ref.read(activeCommunityReportsProvider.notifier).refresh());
    } on DioException catch (e) {
      // B32 — parse the backend detail to show a human-readable message instead
      // of the raw DioException (e.g. on 409 race conditions).
      if (!mounted) return;
      final detail = (e.response?.data as Map?)?['detail'] as String?;
      final msg = switch (detail) {
        'already_voted' => 'Ya votaste en este reporte.',
        'reporter_cannot_vote' => 'No puedes votar en tu propio reporte.',
        final String s when s.startsWith('report_status_is_') =>
          'Este reporte ya no está disponible para votar.',
        _ => 'Error al votar. Intenta de nuevo.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on Exception catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _current!;
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final currentUid = currentUser?.uid ?? '';

    final isLote = report.threatType == ThreatType.loteBaldio;
    final typeLabel = switch (report.threatType) {
      ThreatType.animalMuerto => 'Animal muerto',
      ThreatType.zonaSucia => 'Zona sucia',
      ThreatType.loteBaldio => 'Lote baldío',
    };
    final iconColor = switch (report.threatType) {
      ThreatType.animalMuerto => AppColors.neutral900,
      ThreatType.zonaSucia => const Color(0xFF795548),
      ThreatType.loteBaldio => const Color(0xFF6D4C41),
    };
    final statusLabel = switch (report.status) {
      ReportStatus.pendingValidation => 'Pendiente de validación',
      ReportStatus.confirmed => 'Validado',
      ReportStatus.dismissed => 'Descartado',
      ReportStatus.expired => 'Expirado',
      ReportStatus.resolved => 'Resuelto',
    };

    final isReporter = report.reporterUid == currentUid;
    final alreadyVoted =
        report.validations.any((v) => v['user_uid'] == currentUid);
    final canVote = !isLote &&
        !isReporter &&
        !alreadyVoted &&
        report.status == ReportStatus.pendingValidation;

    final alreadySupported = report.supporters.contains(currentUid);
    final canSupport = isLote &&
        !alreadySupported &&
        report.status == ReportStatus.pendingValidation;
    final canResolve = isLote &&
        report.pendingResolverUid == currentUid &&
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
            if (isLote) ...[
              _InfoRow(
                label: 'Apoyos',
                value: report.supportCount.toString(),
              ),
              if (report.description != null && report.description!.isNotEmpty)
                _InfoRow(label: 'Descripción', value: report.description!),
            ],
            const Divider(height: 32),
            if (isLote) ...[
              if (canSupport)
                FilledButton.icon(
                  onPressed: _supporting ? null : _support,
                  icon: _supporting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.thumb_up_outlined),
                  label: const Text('Apoyar'),
                )
              else if (alreadySupported)
                const Text(
                  'Ya apoyaste este lote.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else if (report.status != ReportStatus.pendingValidation)
                Text(
                  statusLabel,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              if (canResolve) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _resolving ? null : _resolve,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C)),
                  icon: _resolving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar como resuelto'),
                ),
              ],
            ] else if (!canVote) ...[
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
