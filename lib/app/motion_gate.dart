import 'package:flutter/widgets.dart';

import 'theme/lumen.dart';

/// Stops every animation below it while the app cannot be seen (window
/// minimized or hidden, app in the background), so waiting for connections
/// costs nothing. When the app comes back it plays one ambient burst.
class MotionGate extends StatefulWidget {
  /// Wraps [child].
  const MotionGate({super.key, required this.child});

  final Widget child;

  @override
  State<MotionGate> createState() => _MotionGateState();
}

class _MotionGateState extends State<MotionGate> with WidgetsBindingObserver {
  bool _visible = _isVisible(WidgetsBinding.instance.lifecycleState);

  /// Visible unless the platform says otherwise; `inactive` is a window
  /// that merely lost focus and is still on screen.
  static bool _isVisible(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached => false,
    AppLifecycleState.resumed || AppLifecycleState.inactive || null => true,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = _isVisible(state);
    if (visible != _visible) setState(() => _visible = visible);
    if (state == AppLifecycleState.resumed) LsAmbient.pulse();
  }

  @override
  Widget build(BuildContext context) => TickerMode(enabled: _visible, child: widget.child);
}
