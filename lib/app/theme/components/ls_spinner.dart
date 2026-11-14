import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';

import '../context_ext.dart';

/// Small, thin activity indicator.
class LsSpinner extends StatelessWidget {
  /// Creates a spinner of [size] (defaults to the small icon size).
  const LsSpinner({super.key, this.color, this.size});

  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final d = size ?? ls.size.iconSmall;
    return SizedBox.square(
      dimension: d,
      child: CircularProgressIndicator(
        strokeWidth: ls.size.focusRing,
        strokeCap: StrokeCap.round,
        color: color ?? ls.colors.accent,
        // A determinate value freezes the arc when motion is reduced.
        value: context.reduceMotion ? 0.7 : null,
      ),
    );
  }
}
