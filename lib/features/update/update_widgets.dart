import 'package:flutter/material.dart';

import '../../app/theme/lumen.dart';

/// Round badge in front of update messages.
class UpdateBadge extends StatelessWidget {
  /// Creates a badge showing [icon]; [danger] tints it for failures.
  const UpdateBadge({super.key, required this.icon, this.danger = false});

  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final tone = danger ? ls.colors.danger : ls.colors.accent;
    final size = ls.size.deviceBadge - ls.space.xs;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: tone.withValues(alpha: 0.14)),
      child: Icon(icon, size: ls.size.icon, color: tone),
    );
  }
}

/// Thin download progress bar; indeterminate while [fraction] is null.
class UpdateProgressBar extends StatelessWidget {
  /// Creates the bar.
  const UpdateProgressBar({super.key, required this.fraction});

  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final height = ls.space.xs;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ls.radius.full),
      child: SizedBox(
        height: height,
        child: fraction == null
            ? LinearProgressIndicator(
                minHeight: height,
                color: ls.colors.accent,
                backgroundColor: ls.colors.outline,
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: ls.colors.outline),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: fraction),
                    duration: context.motionDuration(ls.motion.base),
                    curve: ls.motion.base.curve,
                    builder: (context, value, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: ColoredBox(color: ls.colors.accent),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
