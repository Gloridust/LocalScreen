import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../context_ext.dart';

/// Ambient expanding rings that say "looking for / visible to others".
///
/// Three rings loop every `motion.ambient`, a third of a cycle apart. They
/// stop when [active] is false or the platform asks for reduced motion.
class LsRipples extends StatefulWidget {
  /// Creates ripples around a core of diameter [coreSize].
  const LsRipples({
    super.key,
    required this.coreSize,
    required this.color,
    this.active = true,
    this.spread = 1.9,
    this.child,
  });

  final double coreSize;
  final Color color;
  final bool active;

  /// Outer ring diameter as a multiple of [coreSize]; also the widget's size.
  final double spread;
  final Widget? child;

  @override
  State<LsRipples> createState() => _LsRipplesState();
}

class _LsRipplesState extends State<LsRipples> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LsRipples old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final ls = context.ls;
    _c.duration = ls.motion.ambient.duration;
    final run = widget.active && !context.reduceMotion;
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final extent = widget.coreSize * widget.spread;
    final visible = widget.active && !context.reduceMotion;
    return SizedBox.square(
      dimension: extent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: context.motionDuration(ls.motion.slow),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _RipplePainter(
                    animation: _c,
                    curve: ls.motion.ambient.curve,
                    color: widget.color,
                    coreRadius: widget.coreSize / 2,
                    stroke: ls.size.hairline * 1.5,
                  ),
                ),
              ),
            ),
          ),
          ?widget.child,
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.animation,
    required this.curve,
    required this.color,
    required this.coreRadius,
    required this.stroke,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Curve curve;
  final Color color;
  final double coreRadius;
  final double stroke;

  static const _rings = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    for (var i = 0; i < _rings; i++) {
      final phase = (animation.value + i / _rings) % 1.0;
      final t = curve.transform(phase);
      final radius = coreRadius + (maxRadius - coreRadius) * t;
      final fade = math.pow(1 - phase, 1.6).toDouble();
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.42 * fade);
      final halo = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.10 * fade),
          ],
          stops: const [0.6, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, halo);
      canvas.drawCircle(center, radius, ring);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.color != color || old.coreRadius != coreRadius || old.curve != curve;
}

/// The local device's light orb: signature gradient, inner highlight,
/// steady glow and three ambient ripples.
///
/// When [active] is false (not discoverable) the ripples stop and the orb
/// desaturates.
class LsOrb extends StatelessWidget {
  /// Creates an orb of diameter [size] with an optional centre [icon].
  const LsOrb({super.key, required this.size, this.icon, this.active = true});

  final double size;
  final IconData? icon;
  final bool active;

  /// Colour matrix that blends towards luminance as [saturation] drops.
  static List<double> _saturationMatrix(double saturation) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final k = 1 - saturation;
    return [
      lr * k + saturation, lg * k, lb * k, 0, 0, //
      lr * k, lg * k + saturation, lb * k, 0, 0, //
      lr * k, lg * k, lb * k + saturation, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final duration = context.motionDuration(ls.motion.slow);
    final highlight = ls.brightness == Brightness.dark ? c.textPrimary : c.surface;
    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ls.signatureGradient,
        boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.32), blurRadius: size * 0.45)],
      ),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        // Soft specular highlight for the "light" feel.
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.75,
          colors: [highlight.withValues(alpha: 0.34), highlight.withValues(alpha: 0)],
        ),
        border: Border.all(color: highlight.withValues(alpha: 0.12), width: ls.size.hairline),
      ),
      child: icon == null
          ? null
          : Icon(icon, size: size * 0.34, color: c.onAccent.withValues(alpha: 0.88)),
    );
    return LsRipples(
      coreSize: size,
      color: c.accent,
      active: active,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: active ? 1 : 0),
        duration: duration,
        curve: ls.motion.slow.curve,
        builder: (context, v, child) => Opacity(
          opacity: 0.55 + 0.45 * v,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(_saturationMatrix(0.08 + 0.92 * v)),
            child: child,
          ),
        ),
        child: core,
      ),
    );
  }
}
