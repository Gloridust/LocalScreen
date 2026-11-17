import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../core/platform/immersive.dart';
import 'l10n.dart';
import 'theme/lumen.dart';

/// Who draws the title bar; overridden at startup.
final titleBarKindProvider = Provider<TitleBarKind>((ref) => TitleBarKind.native);

/// The window controls the title bar acts on; swapped for a fake in tests.
abstract interface class WindowControls {
  Future<void> minimize();
  Future<void> toggleMaximize();
  Future<void> close();
  Future<void> startDragging();
}

/// [WindowControls] through window_manager.
class WindowManagerControls implements WindowControls {
  /// Creates the controls.
  const WindowManagerControls();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();
}

/// The controls in use.
final windowControlsProvider = Provider<WindowControls>((ref) => const WindowManagerControls());

/// Puts the app-drawn title bar above [child] where the system's is hidden,
/// and takes it away while the window is fullscreen (the display side of a
/// session).
class WindowFrame extends ConsumerStatefulWidget {
  /// Wraps [child].
  const WindowFrame({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends ConsumerState<WindowFrame> with WindowListener {
  bool _maximized = false;
  bool _fullScreen = false;
  bool _focused = true;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(titleBarKindProvider) == TitleBarKind.native) return;
    try {
      windowManager.addListener(this);
      _listening = true;
      windowManager.isMaximized().then((v) {
        if (mounted) setState(() => _maximized = v);
      }, onError: (_) {});
    } on Object catch (e) {
      debugPrint('window state unavailable: $e');
    }
  }

  @override
  void dispose() {
    if (_listening) windowManager.removeListener(this);
    super.dispose();
  }

  void _set(VoidCallback change) {
    if (mounted) setState(change);
  }

  @override
  void onWindowMaximize() => _set(() => _maximized = true);

  @override
  void onWindowUnmaximize() => _set(() => _maximized = false);

  @override
  void onWindowEnterFullScreen() => _set(() => _fullScreen = true);

  @override
  void onWindowLeaveFullScreen() => _set(() => _fullScreen = false);

  @override
  void onWindowFocus() => _set(() => _focused = true);

  @override
  void onWindowBlur() => _set(() => _focused = false);

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(titleBarKindProvider);
    if (kind == TitleBarKind.native) return widget.child;
    return ColoredBox(
      color: context.ls.colors.bg,
      child: Column(
        children: [
          if (!_fullScreen) TitleBar(kind: kind, maximized: _maximized, focused: _focused),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

/// The strip at the top of the window: drags the window, double-click
/// maximizes, and on Windows and GNOME carries the window buttons. It has
/// the page's own background, so it reads as part of the app.
class TitleBar extends ConsumerWidget {
  /// Creates the bar.
  const TitleBar({super.key, required this.kind, this.maximized = false, this.focused = true});

  final TitleBarKind kind;
  final bool maximized;

  /// Buttons dim while another window has the focus, as system ones do.
  final bool focused;

  /// Height of the bar for [kind].
  static double heightFor(TitleBarKind kind) => switch (kind) {
    TitleBarKind.native => 0,
    TitleBarKind.windows => 36,
    TitleBarKind.gnome => 44,
    // Room for the traffic lights, which macOS centres in 28 points.
    TitleBarKind.macos => 28,
  };

  /// Space the macOS traffic lights take at the left edge.
  static const _trafficLights = 76.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final l10n = context.l10n;
    final controls = ref.watch(windowControlsProvider);
    final buttons = switch (kind) {
      TitleBarKind.windows || TitleBarKind.gnome => [
        _WindowButton(
          kind: kind,
          glyph: _Glyph.minimize,
          label: l10n.windowMinimize,
          focused: focused,
          onPressed: controls.minimize,
        ),
        _WindowButton(
          kind: kind,
          glyph: maximized ? _Glyph.restore : _Glyph.maximize,
          label: maximized ? l10n.windowRestore : l10n.windowMaximize,
          focused: focused,
          onPressed: controls.toggleMaximize,
        ),
        _WindowButton(
          kind: kind,
          glyph: _Glyph.close,
          label: l10n.windowClose,
          focused: focused,
          onPressed: controls.close,
        ),
      ],
      _ => const <Widget>[],
    };
    final gap = kind == TitleBarKind.gnome ? ls.space.md : 0.0;
    return SizedBox(
      height: heightFor(kind),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => controls.startDragging(),
              onDoubleTap: controls.toggleMaximize,
              child: SizedBox.expand(
                child: kind == TitleBarKind.macos
                    ? const Padding(padding: EdgeInsets.only(left: _trafficLights))
                    : null,
              ),
            ),
          ),
          for (final (i, b) in buttons.indexed) ...[if (i > 0) SizedBox(width: gap), b],
          if (kind == TitleBarKind.gnome) SizedBox(width: ls.space.md),
        ],
      ),
    );
  }
}

enum _Glyph { minimize, maximize, restore, close }

/// One window button: a flat rectangle on Windows (close turns red under the
/// pointer, as the system's does), a round tinted button on GNOME.
class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.kind,
    required this.glyph,
    required this.label,
    required this.focused,
    required this.onPressed,
  });

  final TitleBarKind kind;
  final _Glyph glyph;
  final String label;
  final bool focused;
  final VoidCallback onPressed;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;
  bool _pressed = false;

  /// The red of the system's own close button.
  static const _closeRed = Color(0xFFC42B1C);

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final windows = widget.kind == TitleBarKind.windows;
    final close = widget.glyph == _Glyph.close;
    final lit = _hovered || _pressed;
    final Color fill;
    final Color ink;
    if (windows) {
      fill = !lit
          ? Colors.transparent
          : close
          ? _closeRed.withValues(alpha: _pressed ? 0.85 : 1)
          : c.textPrimary.withValues(alpha: _pressed ? 0.12 : 0.07);
      ink = lit && close ? Colors.white : c.textPrimary;
    } else {
      fill = c.textPrimary.withValues(alpha: _pressed ? 0.18 : (_hovered ? 0.13 : 0.08));
      ink = c.textPrimary;
    }
    final size = windows ? const Size(46, 36) : const Size.square(24);
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: context.motionDuration(ls.motion.fast),
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              color: fill,
              shape: windows ? BoxShape.rectangle : BoxShape.circle,
            ),
            child: Center(
              child: CustomPaint(
                size: Size.square(windows ? 10 : 8),
                painter: _GlyphPainter(
                  widget.glyph,
                  ink.withValues(alpha: widget.focused || lit ? 1 : 0.45),
                  stroke: windows ? 1 : 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin-line window glyphs, so they match the system's rather than the
/// heavier icon font.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color, {required this.stroke});

  final _Glyph glyph;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    switch (glyph) {
      case _Glyph.minimize:
        canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), paint);
      case _Glyph.maximize:
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h).deflate(stroke / 2), paint);
      case _Glyph.restore:
        final back = w * 0.22;
        canvas.drawRect(Rect.fromLTWH(0, back, w - back, h - back).deflate(stroke / 2), paint);
        canvas.drawPath(
          Path()
            ..moveTo(back, back)
            ..lineTo(back, 0)
            ..lineTo(w, 0)
            ..lineTo(w, h - back)
            ..lineTo(w - back, h - back),
          paint,
        );
      case _Glyph.close:
        canvas
          ..drawLine(Offset.zero, Offset(w, h), paint)
          ..drawLine(Offset(w, 0), Offset(0, h), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.stroke != stroke;
}
