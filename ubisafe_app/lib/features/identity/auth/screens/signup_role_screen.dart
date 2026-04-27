import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_module.dart';

/// Step 2 of sign-up: choose role (BUYER / VENDOR) and create the account.
///
/// Receives name, phone, email and password from SignupDataScreen via route extra.
class SignupRoleScreen extends ConsumerStatefulWidget {
  const SignupRoleScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
  });

  final String name;
  final String phone;
  final String email;
  final String password;

  @override
  ConsumerState<SignupRoleScreen> createState() => _SignupRoleScreenState();
}

class _SignupRoleScreenState extends ConsumerState<SignupRoleScreen> {
  String _role = 'BUYER';
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(authModuleProvider).register(
            name: widget.name,
            phone: widget.phone,
            role: _role,
            email: widget.email,
            password: widget.password,
          );
      if (mounted) {
        context.go(_role == 'BUYER' ? '/home/buyer' : '/home/vendor');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Cómo usarás UbiSafe?')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'BUYER', label: Text('Comprador')),
                ButtonSegment(value: 'VENDOR', label: Text('Vendedor')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 24),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Crear cuenta'),
                  ),
          ],
        ),
      ),
    );
  }
}
