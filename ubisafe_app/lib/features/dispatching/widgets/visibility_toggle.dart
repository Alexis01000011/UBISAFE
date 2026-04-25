import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Toggle that allows a vendor to switch their visibility on/off
/// (i.e. appear or disappear from the buyer map).
class VisibilityToggle extends ConsumerWidget {
  const VisibilityToggle({
    super.key,
    required this.isVisible,
    required this.onChanged,
  });

  final bool isVisible;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(isVisible ? 'Visible para compradores' : 'Oculto'),
      secondary: Icon(
        isVisible ? Icons.visibility : Icons.visibility_off,
      ),
      value: isVisible,
      onChanged: onChanged,
    );
  }
}
