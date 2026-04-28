import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/design_system/colors.dart';
import '../../../core/design_system/spacing.dart';
import '../../../core/design_system/typography.dart';
import '../../presence/services/gps_service.dart';

/// Full-screen blocking widget shown whenever a GPS-dependent screen cannot
/// function because permission is denied or the location service is off.
///
/// Observes [gpsStatusProvider] and auto-resolves (calls [onResolved]) when
/// the status becomes [GpsStatus.ready], without requiring navigation.
///
/// SDD §5.3.6.5
class GpsRequiredEmptyState extends ConsumerWidget {
  const GpsRequiredEmptyState({
    super.key,
    this.featureName,
    this.onResolved,
  });

  /// Optional context phrase, e.g. "para ver vendedores cercanos".
  final String? featureName;

  /// Called when [gpsStatusProvider] transitions to [GpsStatus.ready].
  final VoidCallback? onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(gpsStatusProvider);

    // Auto-resolve when GPS becomes available.
    ref.listen<AsyncValue<GpsStatus>>(gpsStatusProvider, (_, next) {
      if (next.value == GpsStatus.ready) onResolved?.call();
    });

    return statusAsync.when(
      // While the initial permission/service check is in flight, don't block.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        if (status == GpsStatus.ready) return const SizedBox.shrink();

        final copy = status == GpsStatus.permissionDenied
            ? _Copy(
                title: 'Necesitamos tu ubicación',
                description: featureName != null
                    ? 'UBISAFE usa tu ubicación $featureName. Concede el permiso para continuar.'
                    : 'UBISAFE usa tu ubicación para esta función. Concede el permiso para continuar.',
                cta: 'Conceder permiso',
              )
            : const _Copy(
                title: 'Activa el GPS',
                description:
                    'Tu dispositivo tiene el GPS apagado. Actívalo desde los ajustes para continuar.',
                cta: 'Abrir ajustes de ubicación',
              );

        return Semantics(
          label: '${copy.title}. ${copy.description}',
          child: ColoredBox(
            color: AppColors.surface,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      size: 72,
                      color: AppColors.warning700,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      copy.title,
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      copy.description,
                      style: AppTypography.body1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Semantics(
                      button: true,
                      label: copy.cta,
                      child: ElevatedButton(
                        onPressed: () => _handleCta(status),
                        child: Text(copy.cta),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCta(GpsStatus status) async {
    if (status == GpsStatus.permissionDenied) {
      await Geolocator.requestPermission();
    } else {
      await Geolocator.openLocationSettings();
    }
  }
}

class _Copy {
  const _Copy({
    required this.title,
    required this.description,
    required this.cta,
  });

  final String title;
  final String description;
  final String cta;
}
