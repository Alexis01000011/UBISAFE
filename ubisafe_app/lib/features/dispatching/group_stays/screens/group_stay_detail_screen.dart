import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/colors.dart';
import '../../../identity/auth/auth_module.dart';
import '../../../shared/notifications/notification_handler.dart';
import '../models/group_stay.dart';
import '../services/group_stay_module.dart';

/// CU-09-B — Detail view for a group stay.
/// - Vendor: cancel button (own scheduled/active stay).
/// - Buyer: confirm attendance button (scheduled/active stay).
/// - Listens to [groupStayCancelledProvider] and pops if this stay is cancelled (R-F4).
class GroupStayDetailScreen extends ConsumerStatefulWidget {
  const GroupStayDetailScreen({super.key, required this.stay});

  final GroupStay stay;

  @override
  ConsumerState<GroupStayDetailScreen> createState() =>
      _GroupStayDetailScreenState();
}

class _GroupStayDetailScreenState extends ConsumerState<GroupStayDetailScreen> {
  late GroupStay _stay;
  bool _loading = false;
  bool _attended = false;

  @override
  void initState() {
    super.initState();
    _stay = widget.stay;
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar estancia'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar esta estancia? '
          'Los asistentes confirmados serán notificados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Atrás'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar estancia'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    // Optimistic update (R-F9)
    final snapshot = _stay;
    setState(() {
      _loading = true;
      _stay = GroupStay(
        id: _stay.id,
        vendorUid: _stay.vendorUid,
        locationLat: _stay.locationLat,
        locationLng: _stay.locationLng,
        startAt: _stay.startAt,
        endAt: _stay.endAt,
        durationMinutes: _stay.durationMinutes,
        status: 'cancelled',
        cancellationReason: 'vendor_cancelled',
        attendeesCount: _stay.attendeesCount,
        riskLevelAtCreation: _stay.riskLevelAtCreation,
        createdAt: _stay.createdAt,
        updatedAt: _stay.updatedAt,
      );
    });

    try {
      final cancelled = await ref
          .read(groupStayModuleProvider)
          .cancelStay(_stay.id);
      if (!mounted) return;
      setState(() => _stay = cancelled);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estancia cancelada')),
      );
      context.pop();
    } on DioException {
      if (!mounted) return;
      // Rollback (R-F9)
      setState(() {
        _stay = snapshot;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cancelar. Intenta de nuevo.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stay = snapshot;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cancelar la estancia.')),
      );
    }
  }

  Future<void> _confirmAttendance() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(groupStayModuleProvider)
          .confirmAttendance(_stay.id);
      if (!mounted) return;
      setState(() {
        _attended = true;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asistencia confirmada')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final code = e.response?.statusCode;
      if (code == 422) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La estancia ya no está activa.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al confirmar asistencia.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al confirmar asistencia.')),
      );
    }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  Color _statusColor(String status) => switch (status) {
        'scheduled' => AppColors.secondary700,
        'active' => Colors.green,
        'cancelled' => Colors.red,
        'ended' => Colors.grey,
        _ => Colors.grey,
      };

  String _statusLabel(String status) => switch (status) {
        'scheduled' => 'Programada',
        'active' => 'Activa',
        'cancelled' => 'Cancelada',
        'ended' => 'Finalizada',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    // R-F4 — pop when this stay is cancelled via FCM
    ref.listen<Map<String, dynamic>?>(groupStayCancelledProvider, (_, payload) {
      if (payload == null) return;
      if (payload['group_stay_id'] != _stay.id) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La estancia fue cancelada por el vendedor.')),
      );
      context.pop();
    });

    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final isVendor = _stay.vendorUid == currentUid;
    final canCancel =
        isVendor && (_stay.status == 'scheduled' || _stay.status == 'active');
    final canAttend = !isVendor &&
        !_attended &&
        (_stay.status == 'scheduled' || _stay.status == 'active');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de estancia'),
        backgroundColor: AppColors.secondary700,
        foregroundColor: AppColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status chip
            Row(
              children: [
                Chip(
                  label: Text(
                    _statusLabel(_stay.status),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _statusColor(_stay.status),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Ubicación',
                      value:
                          'Lat: ${_stay.locationLat.toStringAsFixed(5)}\n'
                          'Lng: ${_stay.locationLng.toStringAsFixed(5)}',
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.play_arrow,
                      label: 'Inicio',
                      value: _formatDateTime(_stay.startAt),
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.stop,
                      label: 'Fin',
                      value: _formatDateTime(_stay.endAt),
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.timer,
                      label: 'Duración',
                      value: _formatDuration(_stay.durationMinutes),
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.people,
                      label: 'Asistentes',
                      value: '${_stay.attendeesCount}',
                    ),
                    if (_stay.riskLevelAtCreation != null) ...[
                      const Divider(),
                      _InfoRow(
                        icon: Icons.warning_amber,
                        label: 'Riesgo al crear',
                        value: _stay.riskLevelAtCreation!,
                      ),
                    ],
                    if (_stay.cancellationReason != null) ...[
                      const Divider(),
                      _InfoRow(
                        icon: Icons.cancel_outlined,
                        label: 'Motivo cancelación',
                        value: _stay.cancellationReason!,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Spacer(),

            if (canCancel)
              FilledButton.icon(
                onPressed: _loading ? null : _cancel,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar estancia',
                    style: TextStyle(fontSize: 16)),
              ),

            if (canAttend) ...[
              FilledButton.icon(
                onPressed: _loading ? null : _confirmAttendance,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Confirmar asistencia',
                    style: TextStyle(fontSize: 16)),
              ),
            ],

            if (_attended)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'Asistencia confirmada',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.secondary700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
