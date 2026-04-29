import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/api/api_client.dart';

/// Bottom sheet form for reporting a risk zone (CU-03).
/// Returns true if the report was submitted successfully.
class RiskFormBottomSheet extends ConsumerStatefulWidget {
  const RiskFormBottomSheet({super.key, required this.currentLocation});

  final LatLng currentLocation;

  static Future<bool> show(BuildContext context, LatLng currentLocation) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RiskFormBottomSheet(currentLocation: currentLocation),
    );
    return result == true;
  }

  @override
  ConsumerState<RiskFormBottomSheet> createState() =>
      _RiskFormBottomSheetState();
}

class _RiskFormBottomSheetState extends ConsumerState<RiskFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _threatCtrl = TextEditingController();
  String? _riskLevel;
  String? _duplicateError;
  bool _loading = false;

  @override
  void dispose() {
    _threatCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_riskLevel == null) {
      setState(() => _duplicateError = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona un nivel de riesgo')));
      return;
    }

    setState(() {
      _loading = true;
      _duplicateError = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final dio = ref.read(apiClientProvider);

    try {
      await dio.post<dynamic>(
        '/risk-zones',
        data: {
          'threat_type': _threatCtrl.text.trim(),
          'risk_level': _riskLevel,
          'location': {
            'lat': widget.currentLocation.latitude,
            'lng': widget.currentLocation.longitude,
          },
          'radius_meters': 100,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Zona de riesgo reportada')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.response?.statusCode == 409) {
        setState(() => _duplicateError = 'Ya existe un reporte activo en esta zona');
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Error al reportar la zona. Intenta de nuevo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reportar zona de riesgo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Lat: ${widget.currentLocation.latitude.toStringAsFixed(5)}, '
              'Lng: ${widget.currentLocation.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _threatCtrl,
              decoration: const InputDecoration(
                labelText: 'Tipo de amenaza',
                hintText: 'Ej: robo, accidente, vía bloqueada...',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Nivel de riesgo',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _LevelChip(
                  label: 'ALTO',
                  value: 'HIGH',
                  selectedColor: const Color(0xFFC62828),
                  selected: _riskLevel == 'HIGH',
                  onSelected: (v) => setState(() {
                    _riskLevel = v ? 'HIGH' : null;
                    _duplicateError = null;
                  }),
                ),
                _LevelChip(
                  label: 'MEDIO',
                  value: 'MEDIUM',
                  selectedColor: const Color(0xFFF57C00),
                  selected: _riskLevel == 'MEDIUM',
                  onSelected: (v) => setState(() {
                    _riskLevel = v ? 'MEDIUM' : null;
                    _duplicateError = null;
                  }),
                ),
                _LevelChip(
                  label: 'BAJO',
                  value: 'LOW',
                  selectedColor: const Color(0xFF0277BD),
                  selected: _riskLevel == 'LOW',
                  onSelected: (v) => setState(() {
                    _riskLevel = v ? 'LOW' : null;
                    _duplicateError = null;
                  }),
                ),
              ],
            ),
            if (_duplicateError != null) ...[
              const SizedBox(height: 8),
              Text(
                _duplicateError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reportar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.value,
    required this.selectedColor,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String value;
  final Color selectedColor;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: selectedColor.withValues(alpha: 0.2),
      checkmarkColor: selectedColor,
      labelStyle: TextStyle(
        color: selected ? selectedColor : null,
        fontWeight: selected ? FontWeight.bold : null,
      ),
      side: selected ? BorderSide(color: selectedColor) : null,
      onSelected: onSelected,
    );
  }
}
