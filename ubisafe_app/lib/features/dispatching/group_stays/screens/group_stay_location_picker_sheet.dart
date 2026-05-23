import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/design_system/colors.dart';
import '../../../../core/design_system/typography.dart';

/// Lets the vendor pick the location for a group stay.
///
/// Call [GroupStayLocationPickerSheet.show]; returns [LatLng] on confirm or null on cancel.
class GroupStayLocationPickerSheet extends StatefulWidget {
  const GroupStayLocationPickerSheet({super.key, required this.initialPosition});

  final LatLng initialPosition;

  static Future<LatLng?> show(BuildContext context, LatLng initialPosition) {
    return showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          GroupStayLocationPickerSheet(initialPosition: initialPosition),
    );
  }

  @override
  State<GroupStayLocationPickerSheet> createState() =>
      _GroupStayLocationPickerSheetState();
}

class _GroupStayLocationPickerSheetState
    extends State<GroupStayLocationPickerSheet> {
  late LatLng _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPosition;
  }

  void _onCameraMove(CameraPosition pos) {
    setState(() => _selected = pos.target);
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
              'Punto de tu estancia',
              style: AppTypography.heading1
                  .copyWith(color: AppColors.secondary700),
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Mueve el mapa hasta que el pin esté en el lugar donde estarás.',
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
                    target: widget.initialPosition,
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onCameraMove: _onCameraMove,
                ),
                const IgnorePointer(
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 48,
                    color: AppColors.secondary700,
                  ),
                ),
              ],
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
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(_selected),
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
