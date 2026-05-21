import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/colors.dart';
import '../../../presence/services/gps_service.dart';
import '../services/group_stay_module.dart';

/// CU-09-A — Vendor schedules a new group stay.
/// Launched from MapScreenVendor SpeedDial → /group-stays/schedule.
class ScheduleGroupStayScreen extends ConsumerStatefulWidget {
  const ScheduleGroupStayScreen({super.key});

  @override
  ConsumerState<ScheduleGroupStayScreen> createState() =>
      _ScheduleGroupStayScreenState();
}

class _ScheduleGroupStayScreenState
    extends ConsumerState<ScheduleGroupStayScreen> {
  DateTime? _selectedStart;
  int _durationMinutes = 60;
  bool _loading = false;

  static const _durations = [15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 420, 480];

  Future<void> _pickStartDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    if (!mounted) return;
    setState(() {
      _selectedStart = DateTime(
        date.year, date.month, date.day,
        time.hour, time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final start = _selectedStart;
    if (start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha y hora de inicio')),
      );
      return;
    }

    final minStart = DateTime.now().add(const Duration(minutes: 5));
    if (start.isBefore(minStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El inicio debe ser al menos 5 minutos en el futuro'),
        ),
      );
      return;
    }

    final position = ref.read(gpsServiceProvider).valueOrNull;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS no disponible. Intenta de nuevo.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final module = ref.read(groupStayModuleProvider);
      final response = await module.createStay(
        lat: position.latitude,
        lng: position.longitude,
        startAt: start,
        durationMinutes: _durationMinutes,
      );

      if (!mounted) return;

      if (response.warning != null) {
        final riskLevel = response.warning!['risk_level'] as String? ?? '';
        final levelLabel = riskLevel == 'HIGH'
            ? 'alto'
            : riskLevel == 'MEDIUM'
                ? 'medio'
                : 'bajo';
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Zona con riesgo'),
            content: Text(
              'Hay riesgo $levelLabel en la zona seleccionada. '
              'La estancia ya fue programada. ¿Deseas mantenerla?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar estancia'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Mantener'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirm == false) {
          // User chose to cancel — call cancel endpoint best-effort
          try {
            await module.cancelStay(response.stay.id);
          } catch (_) {}
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estancia cancelada')),
          );
          context.pop();
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estancia programada exitosamente')),
      );
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      final detail = e.response?.data;
      if (code == 422) {
        final errorKey = detail is Map ? detail['detail'] : null;
        final isZoneHigh = errorKey is Map && errorKey['error'] == 'zone_high';
        if (isZoneHigh) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Zona de alto riesgo'),
              content: const Text(
                'El punto seleccionado está dentro de una zona de alto riesgo. '
                'Elige otro lugar para programar tu estancia.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de validación: $detail')),
        );
      } else if (code == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tienes otra estancia activa que se solapa con este horario',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al programar la estancia')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al programar la estancia')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(gpsServiceProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Programar estancia'),
        backgroundColor: AppColors.secondary700,
        foregroundColor: AppColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Location info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.secondary700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: position == null
                          ? const Text(
                              'Obteniendo ubicación…',
                              style: TextStyle(color: AppColors.textSecondary),
                            )
                          : Text(
                              'Lat: ${position.latitude.toStringAsFixed(5)}\n'
                              'Lng: ${position.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date/time picker
            ListTile(
              tileColor: AppColors.neutral100,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.calendar_today,
                  color: AppColors.secondary700),
              title: Text(
                _selectedStart == null
                    ? 'Seleccionar fecha y hora'
                    : '${_selectedStart!.day.toString().padLeft(2, '0')}/'
                        '${_selectedStart!.month.toString().padLeft(2, '0')}/'
                        '${_selectedStart!.year}  '
                        '${_selectedStart!.hour.toString().padLeft(2, '0')}:'
                        '${_selectedStart!.minute.toString().padLeft(2, '0')}',
              ),
              onTap: _loading ? null : _pickStartDateTime,
            ),
            const SizedBox(height: 16),

            // Duration picker
            const Text('Duración', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              child: DropdownButton<int>(
                value: _durationMinutes,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: _durations
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(_formatDuration(m)),
                        ))
                    .toList(),
                onChanged: _loading
                    ? null
                    : (v) => setState(() => _durationMinutes = v ?? 60),
              ),
            ),
            const Spacer(),

            FilledButton(
              onPressed: _loading || position == null ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.surface),
                    )
                  : const Text('Programar estancia',
                      style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
