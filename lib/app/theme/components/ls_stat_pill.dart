import 'package:flutter/widgets.dart';

import '../context_ext.dart';

/// Capsule showing one live statistic, e.g. `60 fps`.
class LsStatPill extends StatelessWidget {
  /// Creates a stat pill. [onMedia] uses a translucent fill for video overlays.
  const LsStatPill({super.key, required this.value, this.label, this.icon, this.onMedia = false});

  final String value;

  /// Optional muted prefix, e.g. `延迟`.
  final String? label;
  final IconData? icon;
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    return Container(
      height: ls.size.controlHeightSmall - ls.space.sm,
      padding: EdgeInsets.symmetric(horizontal: ls.space.md),
      decoration: BoxDecoration(
        color: onMedia ? c.textPrimary.withValues(alpha: 0.06) : c.surfaceRaised,
        borderRadius: BorderRadius.circular(ls.radius.full),
        border: Border.all(color: c.outline, width: ls.size.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: ls.size.iconSmall - ls.space.xs, color: c.textTertiary),
            SizedBox(width: ls.space.xs),
          ],
          if (label != null) ...[
            Text(label!, style: ls.text.stat.copyWith(color: c.textTertiary)),
            SizedBox(width: ls.space.xs),
          ],
          Text(
            value,
            style: ls.text.stat.copyWith(color: c.textPrimary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
