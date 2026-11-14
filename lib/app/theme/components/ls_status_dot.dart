import 'package:flutter/widgets.dart';

import '../context_ext.dart';
import '../tokens.dart';

/// Meaning of an [LsStatusDot].
enum LsStatus {
  /// Visible on the network (accentAlt).
  online,

  /// Session up (success).
  connected,

  /// Degraded (warning).
  warning,

  /// Failure (danger).
  error,

  /// Inactive (tertiary text).
  idle;

  /// Resolves the colour role for this status.
  Color color(LsColors c) => switch (this) {
    online => c.accentAlt,
    connected => c.success,
    warning => c.warning,
    error => c.danger,
    idle => c.textTertiary,
  };
}

/// Small status light with an optional steady glow.
///
/// Status is expressed with light, never by blinking (DESIGN.md › 原则 2).
class LsStatusDot extends StatelessWidget {
  /// Creates a status dot.
  const LsStatusDot({super.key, required this.status, this.glow = true, this.size});

  final LsStatus status;
  final bool glow;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final color = status.color(ls.colors);
    final d = size ?? ls.size.dot;
    return AnimatedContainer(
      duration: context.motionDuration(ls.motion.base),
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow && status != LsStatus.idle
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: d * 1.5)]
            : null,
      ),
    );
  }
}
