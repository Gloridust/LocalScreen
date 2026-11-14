import 'package:flutter/widgets.dart';

import '../context_ext.dart';
import 'ls_pressable.dart';

/// Surface card: hairline outline over `surface`, no shadow.
///
/// With [onTap] it becomes interactive: hover lifts it to `surfaceRaised`
/// and draws an accent outline.
class LsCard extends StatelessWidget {
  /// Creates a card.
  const LsCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.selected = false,
    this.semanticLabel,
    this.clip = false,
  });

  final Widget child;

  /// Defaults to `space.xl`.
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Keeps the accent outline on, e.g. for the current choice.
  final bool selected;
  final String? semanticLabel;

  /// Clips children to the rounded shape (for lists with dividers).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final pad = padding ?? EdgeInsets.all(ls.space.xl);
    if (onTap == null) {
      return _frame(context, pad, lifted: false, accent: selected);
    }
    return LsPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      builder: (context, s) => LsFocusRing(
        visible: s.focused,
        radius: ls.radius.lg,
        child: _frame(context, pad, lifted: s.highlighted, accent: selected || s.highlighted),
      ),
    );
  }

  Widget _frame(
    BuildContext context,
    EdgeInsetsGeometry pad, {
    required bool lifted,
    required bool accent,
  }) {
    final ls = context.ls;
    final c = ls.colors;
    return AnimatedContainer(
      duration: context.motionDuration(ls.motion.fast),
      curve: ls.motion.fast.curve,
      padding: pad,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: lifted ? c.surfaceRaised : c.surface,
        borderRadius: BorderRadius.circular(ls.radius.lg),
        border: Border.all(
          color: accent ? c.accent.withValues(alpha: 0.55) : c.outline,
          width: ls.size.hairline,
        ),
      ),
      child: child,
    );
  }
}

/// Hairline divider used between rows inside a card.
class LsDivider extends StatelessWidget {
  /// Creates a divider, optionally inset from the start.
  const LsDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: SizedBox(
        height: ls.size.hairline,
        width: double.infinity,
        child: ColoredBox(color: ls.colors.outline),
      ),
    );
  }
}
