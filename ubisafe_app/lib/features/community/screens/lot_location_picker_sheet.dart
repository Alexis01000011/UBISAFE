import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/design_system/colors.dart';
import '../../../core/design_system/typography.dart';

const double _kMaxRadiusM = 1000.0;

/// Lets the user pick a lot location within 1 km of their current position.
///
/// Call [LotLocationPickerSheet.show]; returns [LatLng] on confirm or null on cancel.
class LotLocationPickerSheet extends StatefulWidget {
  const LotLocationPickerSheet({super.key, required this.userPosition});

  final LatLng userPosition;

  static Future<LatLng?> show(BuildContext context, LatLng userPosition) {
    return showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => LotLocationPickerSheet(userPosition: userPosition),
    );
  }

  @override
  State<LotLocationPickerSheet> createState() => _LotLocationPickerSheetState();
}

class _LotLocationPickerSheetState extends State<LotLocationPickerSheet> {
  late LatLng _selected;
  bool _outOfRange = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.userPosition;
  }

  void _onCameraMove(CameraPosition pos) {
    final distM = Geolocator.distanceBetween(
      widget.userPosition.latitude,
      widget.userPosition.longitude,
      pos.target.latitude,
      pos.target.longitude,
    );
    setState(() {
      _selected = pos.target;
      _outOfRange = distM > _kMaxRadiusM;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenHeight * 0.75,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Selecciona la ubicación del lote',
              style: AppTypography.heading1.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Mueve el mapa hasta que el pin esté sobre el lote. Radio máximo: 1 km.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.userPosition,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onCameraMove: _onCameraMove,
                  circles: {
                    Circle(
                      circleId: const CircleId('lot_range'),
                      center: widget.userPosition,
                      radius: _kMaxRadiusM,
                      fillColor: Colors.amber.withValues(alpha: 0.15),
                      strokeColor: Colors.amber.shade700,
                      strokeWidth: 2,
                    ),
                  },
                ),
                const IgnorePointer(
                  child: Icon(
                    Icons.home_work_outlined,
                    size: 48,
                    color: Color(0xFF6D4C41),
                  ),
                ),
              ],
            ),
          ),
          if (_outOfRange)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                'El lote está a más de 1 km de tu posición.',
                style: AppTypography.caption.copyWith(color: AppColors.danger500),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4C41),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _outOfRange
                        ? null
                        : () => Navigator.of(context).pop(_selected),
                    child: const Text('Confirmar ubicación'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
