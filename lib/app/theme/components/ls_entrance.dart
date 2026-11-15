import 'package:flutter/widgets.dart';

import '../context_ext.dart';

/// List-item entrance: rises 8 dp and fades in, staggered by [index].
///
/// Plays once per element; give it a stable key so items that are already
/// visible do not replay. Reduced motion shows the item immediately.
class LsEntrance extends StatefulWidget {
  /// Creates an entrance for the item at [index] of a batch.
  const LsEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<LsEntrance> createState() => _LsEntranceState();
}

class _LsEntranceState extends State<LsEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final ls = context.ls;
    if (context.reduceMotion) {
      _c.value = 1;
      return;
    }
    _c.duration = ls.motion.base.duration;
    // Cap the stagger so late items in a long list do not lag behind.
    final delay = ls.motion.stagger * widget.index.clamp(0, 8);
    Future<void>.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final curved = CurvedAnimation(parent: _c, curve: ls.motion.base.curve);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, ls.motion.entranceOffset * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
