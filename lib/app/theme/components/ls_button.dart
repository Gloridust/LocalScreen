import 'package:flutter/widgets.dart';

import '../context_ext.dart';
import '../tokens.dart';
import 'ls_pressable.dart';
import 'ls_spinner.dart';

/// Visual weight of an [LsButton].
enum LsButtonVariant {
  /// Signature-gradient fill; one per screen.
  primary,

  /// Hairline outline on surface.
  secondary,

  /// Text only; fills on hover.
  ghost,

  /// Destructive: soft danger tint.
  danger,
}

/// Height class of an [LsButton].
enum LsButtonSize { regular, small }

/// The Lumen button.
class LsButton extends StatelessWidget {
  /// Creates a button. A null [onPressed] renders it disabled.
  const LsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = LsButtonVariant.secondary,
    this.size = LsButtonSize.regular,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.autofocus = false,
  });

  /// Primary call to action.
  const LsButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = LsButtonSize.regular,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.autofocus = false,
  }) : variant = LsButtonVariant.primary;

  /// Low-emphasis text button.
  const LsButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = LsButtonSize.regular,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.autofocus = false,
  }) : variant = LsButtonVariant.ghost;

  /// Destructive action.
  const LsButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = LsButtonSize.regular,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.autofocus = false,
  }) : variant = LsButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final LsButtonVariant variant;
  final LsButtonSize size;
  final IconData? icon;

  /// Fill the available width.
  final bool expand;

  /// Shows a spinner and ignores taps.
  final bool loading;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final enabled = onPressed != null && !loading;
    return LsPressable(
      onTap: enabled ? onPressed : null,
      autofocus: autofocus,
      semanticLabel: label,
      builder: (context, s) {
        final style = _ButtonStyle.resolve(ls, variant, s);
        final height = size == LsButtonSize.regular
            ? ls.size.controlHeight
            : ls.size.controlHeightSmall;
        final radius = size == LsButtonSize.regular ? ls.radius.md : ls.radius.sm;
        final content = Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              Padding(
                padding: EdgeInsets.only(right: ls.space.sm),
                child: LsSpinner(color: style.foreground, size: ls.size.iconSmall),
              )
            else if (icon != null)
              Padding(
                padding: EdgeInsets.only(right: ls.space.sm),
                child: Icon(icon, size: ls.size.iconSmall, color: style.foreground),
              ),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ls.text.label.copyWith(color: style.foreground, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
        return LsFocusRing(
          visible: s.focused,
          radius: radius,
          child: AnimatedOpacity(
            opacity: onPressed == null ? 0.4 : 1,
            duration: context.motionDuration(ls.motion.fast),
            child: AnimatedContainer(
              duration: context.motionDuration(ls.motion.fast),
              curve: ls.motion.fast.curve,
              height: height,
              constraints: BoxConstraints(minWidth: ls.size.minTarget),
              padding: EdgeInsets.symmetric(
                horizontal: size == LsButtonSize.regular ? ls.space.xl : ls.space.lg,
              ),
              decoration: BoxDecoration(
                color: style.fill,
                gradient: style.gradient,
                borderRadius: BorderRadius.circular(radius),
                border: style.border == null
                    ? null
                    : Border.all(color: style.border!, width: ls.size.hairline),
                boxShadow: style.shadow,
              ),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _ButtonStyle {
  const _ButtonStyle({
    required this.foreground,
    this.fill,
    this.gradient,
    this.border,
    this.shadow,
  });

  final Color foreground;
  final Color? fill;
  final Gradient? gradient;
  final Color? border;
  final List<BoxShadow>? shadow;

  static _ButtonStyle resolve(LsTokens ls, LsButtonVariant variant, LsInteraction s) {
    final c = ls.colors;
    final lit = s.highlighted;
    switch (variant) {
      case LsButtonVariant.primary:
        return _ButtonStyle(
          foreground: c.onAccent,
          gradient: ls.signatureGradient,
          shadow: lit ? ls.glow : const [],
        );
      case LsButtonVariant.secondary:
        return _ButtonStyle(
          foreground: c.textPrimary,
          fill: lit ? c.surfaceRaised : c.surface,
          border: lit ? c.accent.withValues(alpha: 0.5) : c.outline,
        );
      case LsButtonVariant.ghost:
        return _ButtonStyle(
          foreground: lit ? c.textPrimary : c.textSecondary,
          fill: lit ? c.surfaceRaised : c.surface.withValues(alpha: 0),
        );
      case LsButtonVariant.danger:
        return _ButtonStyle(
          foreground: c.danger,
          fill: c.danger.withValues(alpha: lit ? 0.2 : 0.12),
          border: c.danger.withValues(alpha: lit ? 0.48 : 0.28),
        );
    }
  }
}

/// Square icon-only button with a tooltip-free semantic label.
class LsIconButton extends StatelessWidget {
  /// Creates an icon button.
  const LsIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.tone,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;

  /// Overrides the icon colour (e.g. danger for "disconnect").
  final Color? tone;

  /// Draws a resting surface instead of being transparent until hover.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    return LsPressable(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, s) {
        final fg = tone ?? (s.highlighted ? c.textPrimary : c.textSecondary);
        final bg = s.highlighted
            ? (tone?.withValues(alpha: 0.16) ?? c.surfaceRaised)
            : filled
            ? c.surface
            : c.surface.withValues(alpha: 0);
        return LsFocusRing(
          visible: s.focused,
          radius: ls.radius.full,
          child: AnimatedContainer(
            duration: context.motionDuration(ls.motion.fast),
            width: ls.size.minTarget,
            height: ls.size.minTarget,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: filled ? Border.all(color: c.outline) : null,
            ),
            child: Icon(icon, size: ls.size.icon, color: fg),
          ),
        );
      },
    );
  }
}
