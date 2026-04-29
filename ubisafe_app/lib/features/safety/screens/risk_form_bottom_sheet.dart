import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/colors.dart';
import '../../../core/design_system/typography.dart';
import '../services/risk_report_module.dart';

/// W-17 — RiskFormBottomSheet (CU-03)
/// Transversal to BUYER and VENDOR roles.
/// Precondition: GPS must be active before calling [show].
class RiskFormBottomSheet extends ConsumerStatefulWidget {
  const RiskFormBottomSheet({
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => RiskFormBottomSheet(currentLat: lat, currentLng: lng),
      );

  @override
  ConsumerState<RiskFormBottomSheet> createState() =>
      _RiskFormBottomSheetState();
}

class _RiskFormBottomSheetState extends ConsumerState<RiskFormBottomSheet> {
  String? _threatType;
  final _descCtrl = TextEditingController();
  bool _loading = false;

  static const _threatOptions = [
    'Robo/Asalto',
    'Accidente',
    'Zona insegura',
    'Iluminación deficiente',
    'Otro',
  ];

  // Map display label → API risk_level value
  String _resolveLevel(String threatType) {
    switch (threatType) {
      case 'Robo/Asalto':
        return 'HIGH';
      case 'Accidente':
        return 'HIGH';
      case 'Zona insegura':
        return 'MEDIUM';
      case 'Iluminación deficiente':
        return 'LOW';
      default:
        return 'MEDIUM';
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_threatType == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(riskReportModuleProvider).createRiskZone(
            threatType: _threatType!,
            riskLevel: _resolveLevel(_threatType!),
            lat: widget.currentLat,
            lng: widget.currentLng,
          );

      // Refresh map polygons
      await ref.read(activeRiskZonesProvider.notifier).refresh();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zona reportada. Gracias.')),
        );
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = code == 409
          ? 'Ya existe un reporte activo en esta zona.'
          : 'No se pudo enviar. Intenta de nuevo.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
          // Handle
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
          // Title
          Text(
            'Reportar zona de riesgo',
            style: AppTypography.heading1.copyWith(color: AppColors.neutral900),
          ),
          const Divider(height: 24),
          // Threat type dropdown (required)
          Text(
            'Tipo de riesgo *',
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
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) => setState(() => _threatType = v),
          ),
          const SizedBox(height: 16),
          // Description (optional)
          Text(
            'Descripción',
            style: AppTypography.label.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            minLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Describe brevemente...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
          // Location chip (readonly)
          Row(
            children: [
              const Icon(Icons.location_on, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Lat ${widget.currentLat.toStringAsFixed(4)}, '
                  'Lng ${widget.currentLng.toStringAsFixed(4)}',
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
          // Submit button
          ElevatedButton(
            onPressed: (_threatType == null || _loading) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning700,
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
                : const Text('Enviar reporte'),
          ),
        ],
      ),
    );
  }
}
