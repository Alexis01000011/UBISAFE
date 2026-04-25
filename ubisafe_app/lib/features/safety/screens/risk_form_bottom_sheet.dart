import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom sheet form for reporting a risk zone.
class RiskFormBottomSheet extends ConsumerStatefulWidget {
  const RiskFormBottomSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const RiskFormBottomSheet(),
      );

  @override
  ConsumerState<RiskFormBottomSheet> createState() =>
      _RiskFormBottomSheetState();
}

class _RiskFormBottomSheetState extends ConsumerState<RiskFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String _category = 'robbery';

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // TODO: persist risk zone to Firestore via a RiskZoneModule.
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
            Text(
              'Reportar zona de riesgo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: const [
                DropdownMenuItem(value: 'robbery', child: Text('Robo')),
                DropdownMenuItem(value: 'harassment', child: Text('Acoso')),
                DropdownMenuItem(value: 'accident', child: Text('Accidente')),
                DropdownMenuItem(value: 'other', child: Text('Otro')),
              ],
              onChanged: (v) => setState(() => _category = v!),
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Enviar reporte'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
