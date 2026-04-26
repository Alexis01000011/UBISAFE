import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the current [AppLifecycleState] via a [WidgetsBindingObserver].
///
/// Null until the first lifecycle event is received (initial state is
/// [AppLifecycleState.resumed] in practice, but avoid assuming that).
final appLifecycleProvider =
    StateNotifierProvider<_AppLifecycleNotifier, AppLifecycleState?>(
  (ref) => _AppLifecycleNotifier(),
);

class _AppLifecycleNotifier extends StateNotifier<AppLifecycleState?>
    with WidgetsBindingObserver {
  _AppLifecycleNotifier() : super(null) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
