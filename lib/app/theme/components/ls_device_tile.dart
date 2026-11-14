import 'package:flutter/widgets.dart';

import '../context_ext.dart';
import 'ls_pressable.dart';

/// Rounded-square badge holding a device-kind icon.
class LsDeviceBadge extends StatelessWidget {
  /// Creates a badge; [highlighted] tints it with the accent.
  const LsDeviceBadge({super.key, required this.icon, this.highlighted = false, this.size});

  final IconData icon;
  final bool highlighted;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final d = size ?? ls.size.deviceBadge;
    return AnimatedContainer(
      duration: context.motionDuration(ls.motion.fast),
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: highlighted
            ? c.accent.withValues(alpha: 0.14)
            : c.textPrimary.withValues(alpha: ls.brightness == Brightness.dark ? 0.05 : 0.04),
        borderRadius: BorderRadius.circular(ls.radius.sm + ls.space.xs / 2),
        border: Border.all(
          color: highlighted ? c.accent.withValues(alpha: 0.24) : c.outline,
          width: ls.size.hairline,
        ),
      ),
      child: Icon(icon, size: d * 0.5, color: highlighted ? c.accent : c.textSecondary),
    );
  }
}

/// Small shield + label marking a trusted device.
class LsTrustedMark extends StatelessWidget {
  /// Creates the mark with its localized [label].
  const LsTrustedMark({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ls.space.sm, vertical: ls.space.xs / 2),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ls.radius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: ls.size.iconSmall - ls.space.xs / 2, color: c.accent),
          SizedBox(width: ls.space.xs),
          Text(
            label,
            style: ls.text.caption.copyWith(color: c.accent, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// A nearby (or remembered) device row: badge · name · details · trust mark.
///
/// Hover lifts it to `surfaceRaised` with an accent outline.
class LsDeviceTile extends StatelessWidget {
  /// Creates a device tile.
  const LsDeviceTile({
    super.key,
    required this.icon,
    required this.name,
    required this.details,
    this.trailing,
    this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String name;

  /// Platform and address, rendered in secondary text.
  final String details;

  /// Usually an [LsTrustedMark] or an action button.
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    Widget body(bool lit) => AnimatedContainer(
      duration: context.motionDuration(ls.motion.fast),
      curve: ls.motion.fast.curve,
      constraints: BoxConstraints(minHeight: ls.size.deviceTileHeight),
      padding: EdgeInsets.symmetric(horizontal: ls.space.lg, vertical: ls.space.md),
      decoration: BoxDecoration(
        color: lit ? c.surfaceRaised : c.surface,
        borderRadius: BorderRadius.circular(ls.radius.lg - ls.space.xs),
        border: Border.all(
          color: lit ? c.accent.withValues(alpha: 0.55) : c.outline,
          width: ls.size.hairline,
        ),
      ),
      child: Row(
        children: [
          LsDeviceBadge(icon: icon, highlighted: lit),
          SizedBox(width: ls.space.md + ls.space.xs),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ls.text.body.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: ls.space.xs / 2),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ls.text.stat.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[SizedBox(width: ls.space.md), trailing!],
        ],
      ),
    );
    if (onTap == null) return body(false);
    return LsPressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? name,
      builder: (context, s) => LsFocusRing(
        visible: s.focused,
        radius: ls.radius.lg - ls.space.xs,
        child: body(s.highlighted),
      ),
    );
  }
}
