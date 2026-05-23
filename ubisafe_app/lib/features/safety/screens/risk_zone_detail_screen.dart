import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/colors.dart';
import '../../identity/auth/auth_module.dart';
import '../models/risk_zone.dart';
import '../services/risk_zone_dismiss_module.dart';
import '../services/risk_zone_service.dart';

const int _kDismissThreshold = 3;

class RiskZoneDetailScreen extends ConsumerStatefulWidget {
  const RiskZoneDetailScreen({super.key, required this.zone});

  final RiskZone zone;

  @override
  ConsumerState<RiskZoneDetailScreen> createState() =>
      _RiskZoneDetailScreenState();
}

class _RiskZoneDetailScreenState extends ConsumerState<RiskZoneDetailScreen> {
  bool _dismissing = false;
  late RiskZone _current;

  @override
  void initState() {
    super.initState();
    _current = widget.zone;
  }

  Future<void> _dismiss() async {
    final snapshot = _current;
    final currentUid =
        ref.read(authStateProvider).valueOrNull?.uid ?? '';

    // Optimistic update
    setState(() {
      _dismissing = true;
      _current = RiskZone(
        id: snapshot.id,
        reporterUid: snapshot.reporterUid,
        threatType: snapshot.threatType,
        riskLevel: snapshot.riskLevel,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        radiusMeters: snapshot.radiusMeters,
        active: snapshot.active,
        createdAt: snapshot.createdAt,
        expiresAt: snapshot.expiresAt,
        expiredAt: snapshot.expiredAt,
        dismissedAt: snapshot.dismissedAt,
        dismissCount: snapshot.dismissCount + 1,
        dismissers: [...snapshot.dismissers, currentUid],
      );
    });

    try {
      final updated = await ref
          .read(riskZoneDismissModuleProvider)
          .dismiss(snapshot.id);
      if (!mounted) return;
      setState(() => _current = updated);
      // Invalidar el provider para que el mapa refleje el cambio
      ref.invalidate(activeRiskZonesProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _current = snapshot); // rollback
      final rawDetail = e.response?.data?['detail'];
      final errorKey = rawDetail is Map
          ? rawDetail['error'] as String?
          : rawDetail as String?;
      final msg = switch (errorKey) {
        'reporter_cannot_dismiss' => 'No puedes desmentir tu propia zona.',
        'already_voted' => 'Ya desmentisite esta zona.',
        'zone_already_inactive' => 'Esta zona ya no está activa.',
        _ => 'Error al desmentir. Intenta de nuevo.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _current = snapshot); // rollback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error de conexión. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _dismissing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zone = _current;
    final currentUid =
        ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    final isReporter = zone.reporterUid == currentUid;
    final alreadyDismissed = zone.dismissers.contains(currentUid);
    final canDismiss = zone.active &&
        !isReporter &&
        !alreadyDismissed &&
        zone.dismissCount < _kDismissThreshold;

    final (levelColor, levelLabel, levelIcon) = switch (zone.riskLevel) {
      'HIGH' => (AppColors.danger500, 'Alto', Icons.warning_rounded),
      'MEDIUM' => (Colors.orange, 'Medio', Icons.warning_amber_rounded),
      _ => (Colors.amber.shade600, 'Bajo', Icons.info_outline_rounded),
    };

    final statusLabel = !zone.active
        ? (zone.dismissedAt != null
            ? 'Desmentida por la comunidad'
            : 'Expirada')
        : 'Activa';

    return Scaffold(
      appBar: AppBar(title: const Text('Zona de riesgo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ──────────────────────────────────────────────────
            Row(
              children: [
                Icon(levelIcon, color: levelColor, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.threatType,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: levelColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Riesgo $levelLabel',
                          style: TextStyle(
                              color: levelColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Info rows ─────────────────────────────────────────────────
            _InfoRow(label: 'Estado', value: statusLabel),
            _InfoRow(
              label: 'Radio',
              value: '${zone.radiusMeters} m',
            ),
            _InfoRow(
              label: 'Expira',
              value: _formatDate(zone.expiresAt),
            ),

            const Divider(height: 32),

            // ── Progreso de votos ─────────────────────────────────────────
            Text(
              'Votos de desmentido',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: zone.dismissCount / _kDismissThreshold,
                    backgroundColor: AppColors.neutral900.withValues(alpha: 0.12),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.danger500),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${zone.dismissCount}/$_kDismissThreshold',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Botón / estado ────────────────────────────────────────────
            if (!zone.active)
              Text(
                zone.dismissedAt != null
                    ? 'Esta zona fue desmentida por la comunidad y ya no aparece en el mapa.'
                    : 'Esta zona expiró y ya no está activa.',
                style:
                    const TextStyle(color: AppColors.textSecondary),
              )
            else if (isReporter)
              const Text(
                'No puedes desmentir tu propia zona de riesgo.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else if (alreadyDismissed)
              const Text(
                'Ya desmentisite esta zona. Se necesitan 3 votos en total.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else if (canDismiss)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _dismissing ? null : _dismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger500,
                    side: const BorderSide(color: AppColors.danger500),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _dismissing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.danger500),
                        )
                      : const Icon(Icons.thumb_down_outlined),
                  label: const Text('Desmentir zona'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
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
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }
}
