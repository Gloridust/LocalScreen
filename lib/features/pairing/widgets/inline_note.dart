import 'package:flutter/widgets.dart';

import '../../../app/theme/lumen.dart';

/// One-line explanatory note with a tinted background.
class InlineNote extends StatelessWidget {
  /// Creates a note; [tone] picks the tint (accent, warning or danger).
  const InlineNote({super.key, required this.icon, required this.text, this.tone});

  final IconData icon;
  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final color = tone ?? c.accent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ls.space.md,
        vertical: ls.space.sm + ls.space.xs / 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ls.radius.sm),
        border: Border.all(color: color.withValues(alpha: 0.18), width: ls.size.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: ls.space.xs / 2),
            child: Icon(icon, size: ls.size.iconSmall, color: color),
          ),
          SizedBox(width: ls.space.sm),
          Expanded(
            child: Text(
              text,
              style: ls.text.caption.copyWith(color: c.textPrimary, height: 18 / 12),
            ),
          ),
        ],
      ),
    );
  }
}
