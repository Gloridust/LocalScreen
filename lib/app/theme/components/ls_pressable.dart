import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../context_ext.dart';

/// Interaction state of a [LsPressable].
@immutable
class LsInteraction {
  /// Creates an interaction snapshot.
  const LsInteraction({
    this.hovered = false,
    this.pressed = false,
    this.focused = false,
    this.enabled = true,
  });

  final bool hovered;
  final bool pressed;

  /// True only for keyboard focus (focus highlight mode is traditional).
  final bool focused;
  final bool enabled;

  /// Hovered or keyboard-focused: the "lifted" look.
  bool get highlighted => enabled && (hovered || focused);
}

/// Shared tap target for every Lumen control.
///
/// Adds hover / keyboard-focus / pressed states, Enter & Space activation,
/// the 0.98 press scale (no ripple) and a pointer cursor. The visual is built
/// by [builder] from the current [LsInteraction].
class LsPressable extends StatefulWidget {
  /// Creates a pressable surface.
  const LsPressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.scaleOnPress = true,
    this.selected,
  });

  /// Null disables the control.
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, LsInteraction state) builder;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;
  final bool scaleOnPress;

  /// Exposed to accessibility for toggle-like controls.
  final bool? selected;

  @override
  State<LsPressable> createState() => _LsPressableState();
}

class _LsPressableState extends State<LsPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _activate() {
    if (!_enabled) return;
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final state = LsInteraction(
      hovered: _hovered,
      pressed: _pressed,
      focused: _focused,
      enabled: _enabled,
    );
    Widget child = widget.builder(context, state);
    if (widget.scaleOnPress) {
      child = AnimatedScale(
        scale: _pressed && _enabled ? ls.motion.pressScale : 1,
        duration: context.motionDuration(ls.motion.fast),
        curve: ls.motion.fast.curve,
        child: child,
      );
    }
    return Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          onTap: _enabled ? _activate : null,
          child: child,
        ),
      ),
    );
  }
}

/// Paints the keyboard-focus ring around [child] when [visible].
class LsFocusRing extends StatelessWidget {
  /// Creates a focus ring with the given corner [radius].
  const LsFocusRing({super.key, required this.visible, required this.radius, required this.child});

  final bool visible;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final gap = ls.size.focusRing;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: -gap * 2,
          top: -gap * 2,
          right: -gap * 2,
          bottom: -gap * 2,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: context.motionDuration(ls.motion.fast),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + gap * 2),
                  border: Border.all(color: ls.colors.accent, width: gap),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
