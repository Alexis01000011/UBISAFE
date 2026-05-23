import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/colors.dart';
import '../../../core/design_system/typography.dart';
import '../services/community_report_module.dart';

/// CU-07 — Vacant lot report form.
class LotFormBottomSheet extends ConsumerStatefulWidget {
  const LotFormBottomSheet({
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
        isDismissible: false,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => LotFormBottomSheet(currentLat: lat, currentLng: lng),
      );

  @override
  ConsumerState<LotFormBottomSheet> createState() =>
      _LotFormBottomSheetState();
}

class _LotFormBottomSheetState extends ConsumerState<LotFormBottomSheet> {
  bool _loading = false;
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(communityReportModuleProvider).createReport(
            threatType: 'lote',
            lat: widget.currentLat,
            lng: widget.currentLng,
            description: _descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null,
          );

      await ref.read(activeCommunityReportsProvider.notifier).refresh();

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
          'El lote está fuera del radio permitido (1 km desde tu posición).',
        'nearby_report_exists' =>
          'Ya existe un reporte activo en esta zona.',
        _ => code != null
            ? 'No se pudo enviar (error $code). Intenta de nuevo.'
            : 'Sin conexión. Reintentando…',
      };

      if (mounted) {
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
            'Reportar lote baldío',
            style: AppTypography.heading1.copyWith(color: Colors.white),
          ),
          const Divider(height: 24),
          Text(
            'Descripción (opcional)',
            style: AppTypography.label.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionController,
            maxLength: 200,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Describe brevemente el problema...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6D4C41),
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
