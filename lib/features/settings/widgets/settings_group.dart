import 'package:flutter/widgets.dart';

import '../../../app/theme/lumen.dart';

/// A titled group of rows inside one card, separated by hairlines.
class SettingsGroup extends StatelessWidget {
  /// Creates a group.
  const SettingsGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: ls.space.xs, bottom: ls.space.sm),
          child: Text(title, style: ls.text.label.copyWith(color: c.textSecondary)),
        ),
        LsCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) LsDivider(indent: ls.space.lg + ls.space.xs),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One settings row: title, optional description, trailing control, and an
/// optional full-width control below (used for segmented controls on
/// narrow screens).
class SettingsRow extends StatelessWidget {
  /// Creates a row.
  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    this.leading,
    this.trailing,
    this.below,
    this.onTap,
  });

  final String title;
  final String? description;
  final Widget? leading;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    Widget content(bool lit) => AnimatedContainer(
      duration: context.motionDuration(ls.motion.fast),
      color: lit ? c.surfaceRaised : c.surface.withValues(alpha: 0),
      constraints: BoxConstraints(minHeight: ls.size.controlHeight + ls.space.md),
      padding: EdgeInsets.symmetric(
        horizontal: ls.space.lg + ls.space.xs,
        vertical: ls.space.md + ls.space.xs / 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, SizedBox(width: ls.space.md)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ls.text.body.copyWith(color: c.textPrimary)),
                    if (description != null) ...[
                      SizedBox(height: ls.space.xs / 2),
                      Text(description!, style: ls.text.caption.copyWith(color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[SizedBox(width: ls.space.lg), trailing!],
            ],
          ),
          if (below != null) ...[SizedBox(height: ls.space.md), below!],
        ],
      ),
    );
    if (onTap == null) return content(false);
    return LsPressable(
      onTap: onTap,
      scaleOnPress: false,
      semanticLabel: title,
      builder: (context, s) => content(s.highlighted),
    );
  }
}
