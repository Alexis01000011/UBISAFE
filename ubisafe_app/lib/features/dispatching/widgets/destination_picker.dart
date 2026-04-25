import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// ☆ [iter.2] Map widget that lets the user tap to select a destination.
///
/// Used as a sub-widget inside [RideRequestModule].
class DestinationPicker extends StatefulWidget {
  const DestinationPicker({
    super.key,
    required this.initialPosition,
    required this.onDestinationSelected,
  });

  final LatLng initialPosition;
  final ValueChanged<LatLng> onDestinationSelected;

  @override
  State<DestinationPicker> createState() => _DestinationPickerState();
}

class _DestinationPickerState extends State<DestinationPicker> {
  LatLng? _selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initialPosition,
            zoom: 15,
          ),
          onTap: (latLng) {
            setState(() => _selected = latLng);
            widget.onDestinationSelected(latLng);
          },
          markers: _selected == null
              ? {}
              : {
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: _selected!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                  ),
                },
        ),
        if (_selected != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () => widget.onDestinationSelected(_selected!),
              child: const Text('Confirmar destino'),
            ),
          ),
      ],
    );
  }
}
