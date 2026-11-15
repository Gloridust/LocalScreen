import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../context_ext.dart';
import 'ls_status_dot.dart';

/// Transient capsule message at the bottom of the screen.
abstract final class LsToast {
  static OverlayEntry? _current;

  /// Shows [message] on [overlay], replacing any toast already visible.
  static void show(OverlayState overlay, String message, {LsStatus tone = LsStatus.idle}) {
    _current?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Toast(
        message: message,
        tone: tone,
        onDone: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.tone, required this.onDone});

  final String message;
  final LsStatus tone;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed && !_c.isAnimating) _run();
  }

  Future<void> _run() async {
    final ls = context.ls;
    _c.duration = ls.motion.base.duration;
    await _c.forward();
    await Future<void>.delayed(ls.motion.toastLinger);
    if (!mounted) return;
    await _c.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final bottom = MediaQuery.paddingOf(context).bottom + ls.space.xl;
    final curved = CurvedAnimation(parent: _c, curve: ls.motion.base.curve);
    final offset = context.reduceMotion ? 0.0 : ls.motion.entranceOffset;
    return Positioned(
      left: ls.space.lg,
      right: ls.space.lg,
      bottom: bottom,
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, child) => Opacity(
                opacity: curved.value,
                child: Transform.translate(
                  offset: Offset(0, offset * (1 - curved.value)),
                  child: child,
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ls.size.sheetMaxWidth),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ls.space.lg + ls.space.xs,
                    vertical: ls.space.md,
                  ),
                  decoration: BoxDecoration(
                    color: ls.brightness == Brightness.dark ? c.surfaceRaised : c.surface,
                    borderRadius: BorderRadius.circular(ls.radius.full),
                    border: Border.all(color: c.outline, width: ls.size.hairline),
                    boxShadow: ls.floatingShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LsStatusDot(status: widget.tone),
                      SizedBox(width: ls.space.md),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: ls.text.label.copyWith(color: c.textPrimary),
                        ),
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
