import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Step 1 of sign-up: collect name and phone number.
/// Step 2 (/signup-role) collects the role and creates the account.
class SignupDataScreen extends StatefulWidget {
  const SignupDataScreen({super.key});

  @override
  State<SignupDataScreen> createState() => _SignupDataScreenState();
}

class _SignupDataScreenState extends State<SignupDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    context.go(
      '/signup-role',
      extra: {'name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim()},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Ingresa un número válido'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _next,
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
