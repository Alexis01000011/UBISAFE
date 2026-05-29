import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/design_system/colors.dart';
import '../../../presence/services/gps_service.dart';
import '../services/group_stay_module.dart';
import 'group_stay_location_picker_sheet.dart';

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
  LatLng? _selectedLocation;

  static const _durations = [
    15, 30, 45, 60, 90, 120, 180, 240, 300, 360, 420, 480
  ];

  Future<void> _pickLocation() async {
    final position = ref.read(gpsServiceProvider).valueOrNull;
    if (position == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('GPS no disponible. Espera un momento e intenta de nuevo.')),
      );
      return;
    }

    final picked = await GroupStayLocationPickerSheet.show(
      context,
      LatLng(position.latitude, position.longitude),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedLocation = picked);
  }

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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
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
    final location = _selectedLocation;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el punto de tu estancia')),
      );
      return;
    }

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

    setState(() => _loading = true);
    try {
      final module = ref.read(groupStayModuleProvider);
      final gpsPosition = ref.read(gpsServiceProvider).valueOrNull;

      var response = await module.createStay(
        lat: location.latitude,
        lng: location.longitude,
        startAt: start,
        durationMinutes: _durationMinutes,
        vendorLat: gpsPosition?.latitude,
        vendorLng: gpsPosition?.longitude,
      );

      if (!mounted) return;

      // HTTP 200: zona MEDIUM/LOW detectada — la estancia NO fue creada todavía.
      // Mostrar diálogo antes de comprometerse; si el vendedor cancela, no hay
      // nada que deshacer ni se han enviado notificaciones.
      if (response.stay == null && response.warning != null) {
        final riskLevel = response.warning!['risk_level'] as String? ?? '';
        final levelLabel = riskLevel == 'MEDIUM' ? 'medio' : 'bajo';
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Zona con riesgo'),
            content: Text(
              'El punto seleccionado está en una zona de riesgo $levelLabel. '
              '¿Deseas programar la estancia de todas formas?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Programar de todas formas'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirmed != true) return; // vendedor declinó; nada creado, nada que limpiar

        // Vendedor confirmó → crear la estancia aceptando el riesgo
        response = await module.createStay(
          lat: location.latitude,
          lng: location.longitude,
          startAt: start,
          durationMinutes: _durationMinutes,
          vendorLat: gpsPosition?.latitude,
          vendorLng: gpsPosition?.longitude,
          acknowledgedRiskWarning: true,
        );
        if (!mounted) return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estancia programada exitosamente')),
      );
      context.pop();
      // Reload after pop: the notifier lives in the map tree, not in this screen.
      // Doing it after pop gives Firestore time to propagate the new document.
      // The FCM group_stay_created that arrives seconds later is a second trigger.
      unawaited(ref.read(activeGroupStaysProvider.notifier).reload());
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
        if (errorKey == 'location_out_of_range') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'El punto seleccionado está a más de 2 km de tu posición actual.'),
            ),
          );
          return;
        }
        if (errorKey == 'vendor_location_unavailable') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No se pudo determinar tu posición. Activa el GPS e intenta de nuevo.'),
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
    final locationSelected = _selectedLocation != null;

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
            // Location picker card
            InkWell(
              onTap: _loading ? null : _pickLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: locationSelected
                      ? AppColors.secondary700.withValues(alpha: 0.08)
                      : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: locationSelected
                        ? AppColors.secondary700
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      locationSelected
                          ? Icons.storefront
                          : Icons.storefront_outlined,
                      color: locationSelected
                          ? AppColors.secondary700
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Punto de la estancia',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: locationSelected
                                  ? AppColors.secondary700
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locationSelected
                                ? 'Ubicación seleccionada — toca para cambiar'
                                : 'Toca para elegir en el mapa',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (locationSelected)
                      const Icon(Icons.check_circle,
                          color: AppColors.secondary700),
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
              onPressed: (_loading || !locationSelected) ? null : _submit,
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
