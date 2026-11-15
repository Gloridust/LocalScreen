import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../context_ext.dart';

/// Asks every resting [LsRipples] to play another burst: something happened
/// that is worth a glance (the window came back, a device appeared).
abstract final class LsAmbient {
  /// Bumped by [pulse].
  static final pulses = ValueNotifier<int>(0);

  /// Plays one burst on all visible ripples.
  static void pulse() => pulses.value++;
}

/// Ambient expanding rings that say "looking for / visible to others".
///
/// Three rings, a third of a cycle apart. They play `motion.ambientCycles`
/// cycles when they appear, become [active] or [LsAmbient.pulse] is called,
/// then rest as still rings: an idle window must not keep redrawing. With
/// [continuous] they loop for as long as they are shown, for short waits
/// the user is watching. They do not move at all when [active] is false or
/// the platform asks for reduced motion.
class LsRipples extends StatefulWidget {
  /// Creates ripples around a core of diameter [coreSize].
  const LsRipples({
    super.key,
    required this.coreSize,
    required this.color,
    this.active = true,
    this.continuous = false,
    this.spread = 1.9,
    this.child,
  });

  final double coreSize;
  final Color color;
  final bool active;

  /// Loop without resting; only for waits that end on their own.
  final bool continuous;

  /// Outer ring diameter as a multiple of [coreSize]; also the widget's size.
  final double spread;
  final Widget? child;

  @override
  State<LsRipples> createState() => _LsRipplesState();
}

class _LsRipplesState extends State<LsRipples> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  /// Whether the rings were allowed to move at the last [_sync].
  bool _ran = false;

  @override
  void initState() {
    super.initState();
    LsAmbient.pulses.addListener(_play);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LsRipples old) {
    super.didUpdateWidget(old);
    _sync(restart: old.continuous != widget.continuous);
  }

  bool get _mayRun => widget.active && !context.reduceMotion;

  void _sync({bool restart = false}) {
    _c.duration = context.ls.motion.ambient.duration;
    final run = _mayRun;
    if (run && (!_ran || restart)) {
      _play();
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
    _ran = run;
  }

  /// Starts a burst (or the loop) unless one is already running.
  void _play() {
    if (!mounted || !_mayRun || _c.isAnimating) return;
    if (widget.continuous) {
      _c.repeat();
    } else {
      // Ends on a whole cycle, where the rings sit evenly spaced.
      _c.repeat(count: context.ls.motion.ambientCycles);
    }
  }

  @override
  void dispose() {
    LsAmbient.pulses.removeListener(_play);
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
      canvas.drawCircle(center, radius, ring);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.color != color || old.coreRadius != coreRadius || old.curve != curve;
}

/// The local device's orb: a flat accent circle with the device icon and
/// three ambient ripples.
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
    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent),
      child: icon == null ? null : Icon(icon, size: size * 0.34, color: c.onAccent),
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
