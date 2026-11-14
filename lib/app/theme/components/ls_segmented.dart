import 'package:flutter/widgets.dart';

import '../context_ext.dart';
import 'ls_pressable.dart';

/// One option of an [LsSegmented].
@immutable
class LsSegment<T> {
  /// Creates a segment.
  const LsSegment({required this.value, required this.label, this.icon, this.badge});

  final T value;
  final String label;
  final IconData? icon;

  /// Tiny trailing tag, e.g. "M2".
  final String? badge;
}

/// Segmented control with a sliding thumb.
class LsSegmented<T> extends StatelessWidget {
  /// Creates a segmented control.
  const LsSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final List<LsSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  /// Smaller height for inline use in settings rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final index = segments.indexWhere((s) => s.value == value);
    final inset = ls.space.xs;
    final height = dense ? ls.size.controlHeightSmall : ls.size.controlHeight - ls.space.xs;
    final count = segments.length;
    return Container(
      height: height,
      padding: EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: ls.brightness == Brightness.dark ? c.bg : c.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(ls.radius.md - (dense ? ls.space.xs : 0)),
        border: Border.all(color: c.outline, width: ls.size.hairline),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            AnimatedAlign(
              alignment: Alignment(count == 1 ? 0 : -1 + 2 * index / (count - 1), 0),
              duration: context.motionDuration(ls.motion.base),
              curve: ls.motion.base.curve,
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ls.brightness == Brightness.dark ? c.surfaceRaised : c.surface,
                    borderRadius: BorderRadius.circular(
                      ls.radius.md - inset - (dense ? ls.space.xs : 0),
                    ),
                    border: Border.all(color: c.outline, width: ls.size.hairline),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final s in segments)
                Expanded(
                  child: _SegmentLabel(
                    segment: s,
                    selected: s.value == value,
                    onTap: onChanged == null ? null : () => onChanged!(s.value),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({required this.segment, required this.selected, required this.onTap});

  final LsSegment<T> segment;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    return LsPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: segment.label,
      scaleOnPress: false,
      builder: (context, s) {
        final fg = selected
            ? c.textPrimary
            : s.highlighted
            ? c.textPrimary
            : c.textSecondary;
        return LsFocusRing(
          visible: s.focused,
          radius: ls.radius.sm,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segment.icon != null) ...[
                  Icon(segment.icon, size: ls.size.iconSmall, color: fg),
                  SizedBox(width: ls.space.xs),
                ],
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: context.motionDuration(ls.motion.fast),
                    style: ls.text.label.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: Text(segment.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (segment.badge != null) ...[
                  SizedBox(width: ls.space.xs),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: ls.space.sm),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(ls.radius.full),
                    ),
                    child: Text(
                      segment.badge!,
                      style: ls.text.caption.copyWith(color: c.accent, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
