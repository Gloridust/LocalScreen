import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../context_ext.dart';
import '../tokens.dart';

/// Six-cell PIN entry.
///
/// A single hidden text field drives the cells, which gives auto-advance,
/// backspace, paste and IME support for free. Increment [shakeSignal] to play
/// the "wrong PIN" shake once; the input is cleared at the same time.
class LsPinInput extends StatefulWidget {
  /// Creates a PIN input of [length] digits.
  const LsPinInput({
    super.key,
    required this.onCompleted,
    this.length = 6,
    this.shakeSignal = 0,
    this.enabled = true,
    this.autofocus = true,
    this.error = false,
    this.semanticLabel,
  });

  final ValueChanged<String> onCompleted;
  final int length;
  final int shakeSignal;
  final bool enabled;
  final bool autofocus;

  /// Tints the cells with `danger` until the next keystroke.
  final bool error;
  final String? semanticLabel;

  @override
  State<LsPinInput> createState() => _LsPinInputState();
}

class _LsPinInputState extends State<LsPinInput> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(vsync: this, duration: const LsMotion().slow.duration);
    _controller.addListener(_onChanged);
    _focus.addListener(() => setState(() {}));
    _showError = widget.error;
  }

  @override
  void didUpdateWidget(LsPinInput old) {
    super.didUpdateWidget(old);
    if (widget.shakeSignal != old.shakeSignal) {
      _controller.clear();
      _showError = true;
      if (!context.reduceMotion) _shake.forward(from: 0);
      _focus.requestFocus();
    }
    if (widget.error != old.error) _showError = widget.error;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onChanged() {
    final text = _controller.text;
    setState(() {
      if (text.isNotEmpty) _showError = false;
    });
    if (text.length == widget.length) widget.onCompleted(text);
  }

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final text = _controller.text;
    final active = _focus.hasFocus && widget.enabled
        ? math.min(text.length, widget.length - 1)
        : -1;
    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            // One damped horizontal oscillation.
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 4) * (1 - t) * ls.space.md;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final groupGap = ls.space.lg;
              final gap = ls.space.sm;
              final available = constraints.maxWidth - groupGap - gap * (widget.length - 2);
              final cellW = math.min(ls.size.pinCellWidth, available / widget.length);
              final cellH = cellW / ls.size.pinCellWidth * ls.size.pinCellHeight;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // The real input: invisible but focusable and hit-testable.
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: widget.autofocus,
                        enabled: widget.enabled,
                        keyboardType: TextInputType.number,
                        maxLength: widget.length,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < widget.length; i++) ...[
                          if (i > 0) SizedBox(width: i == widget.length ~/ 2 ? groupGap : gap),
                          _PinCell(
                            width: cellW,
                            height: cellH,
                            digit: i < text.length ? text[i] : null,
                            active: i == active,
                            error: _showError,
                            enabled: widget.enabled,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PinCell extends StatelessWidget {
  const _PinCell({
    required this.width,
    required this.height,
    required this.digit,
    required this.active,
    required this.error,
    required this.enabled,
  });

  final double width;
  final double height;
  final String? digit;
  final bool active;
  final bool error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final r = ls.radius.md - ls.space.xs;
    final stroke = ls.size.focusRing - 0.5;
    final fill = ls.brightness == Brightness.dark ? c.bg : c.surface;
    final duration = context.motionDuration(ls.motion.fast);
    final content = AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
      ),
      child: Text(
        digit ?? '',
        key: ValueKey(digit),
        style: ls.text.display.copyWith(
          color: enabled ? c.textPrimary : c.textTertiary,
          fontSize: ls.text.display.fontSize! * math.min(1, width / ls.size.pinCellWidth),
        ),
      ),
    );
    if (active) {
      // Focused cell: signature-gradient ring plus the soft accent glow.
      return Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(stroke),
        decoration: BoxDecoration(
          gradient: ls.signatureGradient,
          borderRadius: BorderRadius.circular(r),
          boxShadow: ls.glow,
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(r - stroke)),
          child: content,
        ),
      );
    }
    return AnimatedContainer(
      duration: duration,
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: error ? Color.alphaBlend(c.danger.withValues(alpha: 0.08), fill) : fill,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: error
              ? c.danger.withValues(alpha: 0.7)
              : digit != null
              ? c.textTertiary.withValues(alpha: 0.6)
              : c.outline,
          width: ls.size.hairline,
        ),
      ),
      child: content,
    );
  }
}
