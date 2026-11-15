import 'package:flutter/widgets.dart';

import '../context_ext.dart';
import 'ls_pressable.dart';

/// Lumen toggle switch.
class LsSwitch extends StatelessWidget {
  /// Creates a switch; a null [onChanged] disables it.
  const LsSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final w = ls.size.switchWidth;
    final h = ls.size.switchHeight;
    final knob = ls.size.switchKnob;
    final pad = (h - knob) / 2;
    final duration = context.motionDuration(ls.motion.base);
    return Semantics(
      toggled: value,
      child: LsPressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        semanticLabel: semanticLabel,
        builder: (context, s) => LsFocusRing(
          visible: s.focused,
          radius: ls.radius.full,
          child: AnimatedOpacity(
            opacity: onChanged == null ? 0.4 : 1,
            duration: duration,
            child: AnimatedContainer(
              duration: duration,
              curve: ls.motion.base.curve,
              width: w,
              height: h,
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: value
                    ? c.accent
                    : c.textTertiary.withValues(alpha: s.highlighted ? 0.42 : 0.3),
                borderRadius: BorderRadius.circular(ls.radius.full),
                boxShadow: value && s.highlighted ? ls.glow : null,
              ),
              child: AnimatedAlign(
                duration: duration,
                curve: ls.motion.base.curve,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: knob,
                  height: knob,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value
                        ? c.onAccent
                        : ls.brightness == Brightness.dark
                        ? c.textPrimary
                        : c.surface,
                    boxShadow: value || ls.brightness == Brightness.dark
                        ? null
                        : [
                            BoxShadow(
                              color: c.textPrimary.withValues(alpha: 0.18),
                              blurRadius: ls.space.xs,
                              offset: Offset(0, ls.size.hairline),
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
