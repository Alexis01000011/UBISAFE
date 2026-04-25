import 'package:flutter/material.dart';

/// Shown whenever a screen requires GPS but permission is denied
/// or the location service is unavailable.
class GpsRequiredEmptyState extends StatelessWidget {
  const GpsRequiredEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Ubicación requerida',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Activa el GPS y otorga permisos de ubicación para continuar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: deep-link to app settings via the `app_settings` package.
              },
              child: const Text('Abrir configuración'),
            ),
          ],
        ),
      ),
    );
  }
}
