import 'package:flutter/widgets.dart';

import '../context_ext.dart';

/// Large read-only PIN, grouped three-and-three (`482 913`).
class LsPinDisplay extends StatelessWidget {
  /// Creates a PIN display.
  const LsPinDisplay({super.key, required this.pin, this.semanticLabel});

  final String pin;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final half = pin.length ~/ 2;
    final style = ls.text.display.copyWith(
      color: c.textPrimary,
      fontSize: ls.text.display.fontSize! * 1.2,
      letterSpacing: ls.space.xs,
    );
    Widget group(String digits) => Text(digits, style: style);
    return Semantics(
      label: semanticLabel ?? pin.split('').join(' '),
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            group(pin.substring(0, half)),
            SizedBox(width: ls.space.lg),
            group(pin.substring(half)),
          ],
        ),
      ),
    );
  }
}

/// Circular countdown with the remaining seconds in the middle.
///
/// The ring drains from full to empty between now and [expiresAt]. It keeps
/// ticking under reduced motion because the number is information.
class LsCountdownRing extends StatefulWidget {
  /// Creates a countdown that ends at [expiresAt] out of a [total] window.
  const LsCountdownRing({super.key, required this.expiresAt, required this.total});

  final DateTime expiresAt;
  final Duration total;

  @override
  State<LsCountdownRing> createState() => _LsCountdownRingState();
}

class _LsCountdownRingState extends State<LsCountdownRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(LsCountdownRing old) {
    super.didUpdateWidget(old);
    if (old.expiresAt != widget.expiresAt || old.total != widget.total) _restart();
  }

  void _restart() {
    final remaining = widget.expiresAt.difference(DateTime.now());
    final totalMs = widget.total.inMilliseconds;
    if (totalMs <= 0 || remaining <= Duration.zero) {
      _c.value = 1;
      return;
    }
    _c.duration = widget.total;
    _c.value = 1 - remaining.inMilliseconds / totalMs;
    _c.forward();
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
    final d = ls.size.countdownRing;
    return SizedBox.square(
      dimension: d,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final left = 1 - _c.value;
          final seconds = (left * widget.total.inMilliseconds / 1000).ceil();
          final urgent = seconds <= 10;
          return CustomPaint(
            painter: _RingPainter(
              progress: left,
              track: c.outline,
              color: urgent ? c.warning : c.accent,
              stroke: ls.size.focusRing + 1,
            ),
            child: Center(
              child: Text(
                '$seconds',
                style: ls.text.stat.copyWith(
                  color: urgent ? c.warning : c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.stroke,
  });

  final double progress;
  final Color track;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawOval(r, base);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    const start = -1.5707963267948966; // 12 o'clock
    canvas.drawArc(r, start, 6.283185307179586 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
