import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/colors.dart';
import '../../../core/design_system/typography.dart';
import '../services/community_report_module.dart';

/// CU-05 — Community report form (SDD2_FASE4B §9.6.A + §9.6.B).
/// Precondition: GPS must be active before calling [show].
class CommunityFormBottomSheet extends ConsumerStatefulWidget {
  const CommunityFormBottomSheet({
    super.key,
    required this.currentLat,
    required this.currentLng,
  });

  final double currentLat;
  final double currentLng;

  static Future<void> show(
    BuildContext context, {
    required double lat,
    required double lng,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        // B28 — prevent the user from swiping away the sheet while a retry is
        // in flight, which would leave a report created with no feedback.
        isDismissible: false,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) =>
            CommunityFormBottomSheet(currentLat: lat, currentLng: lng),
      );

  @override
  ConsumerState<CommunityFormBottomSheet> createState() =>
      _CommunityFormBottomSheetState();
}

class _CommunityFormBottomSheetState
    extends ConsumerState<CommunityFormBottomSheet> {
  String? _threatType;
  bool _loading = false;

  static const _threatOptions = [
    ('animal_muerto', 'Animal muerto'),
    ('zona_sucia', 'Zona sucia / Basura'),
  ];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _submit() async {
    if (_threatType == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(communityReportModuleProvider).createReport(
            threatType: _threatType!,
            lat: widget.currentLat,
            lng: widget.currentLng,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte registrado correctamente.')),
        );
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final detail =
          e.response?.data is Map ? (e.response!.data as Map)['detail'] : null;
      final errorCode = detail is Map ? detail['error'] as String? : null;

      final msg = switch (errorCode) {
        'location_out_of_range' =>
          'Debes estar en la zona para reportar este foco.',
        'nearby_report_exists' =>
          'Ya existe un reporte activo en esta zona.',
        _ => code != null
            ? 'No se pudo enviar (error $code). Intenta de nuevo.'
            : 'Sin conexión. Reintentando…',
      };

      if (mounted) {
        // Capture the messenger before pop so the SnackBar renders on the map
        // screen (not under the SpeedDial which may still be expanded).
        final messenger = ScaffoldMessenger.of(context);
        if (errorCode == 'nearby_report_exists') Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.danger500,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        32 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reportar foco de infección',
            style: AppTypography.heading1.copyWith(color: Colors.white),
          ),
          const Divider(height: 24),
          Text(
            'Tipo de foco *',
            style: AppTypography.label.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _threatType,
            hint: const Text('Selecciona...'),
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _threatOptions
                .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                .toList(),
            onChanged: (v) => setState(() => _threatType = v),
          ),
          const SizedBox(height: 16),
          // Location chip (readonly — GPS auto-captured)
          Row(
            children: [
              const Icon(Icons.location_on, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ubicación actual',
                  style: AppTypography.body2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'GPS activo',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.secondary700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_threatType == null || _loading) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF795548),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirmar envío'),
          ),
        ],
      ),
    );
  }
}
