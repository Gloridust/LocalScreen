import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n.dart';
import '../../app/theme/lumen.dart';
import '../../core/media/media_session.dart';
import '../../core/platform/immersive.dart';
import 'active_session.dart';
import 'session_controller.dart';
import 'widgets/session_stats.dart';

/// Display side: the host's picture, immersive and fullscreen, with a
/// capsule toolbar that appears on tap / pointer movement and hides again
/// after `motion.toolbarLinger`.
class DisplaySessionScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [controller].
  const DisplaySessionScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  ConsumerState<DisplaySessionScreen> createState() => _DisplaySessionScreenState();
}

class _DisplaySessionScreenState extends ConsumerState<DisplaySessionScreen> {
  static final _theme = buildLsTheme(LsTokens.dark);
  bool _toolbar = true;
  bool _fill = false;
  Timer? _hide;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    unawaited(Immersive.enter());
    _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _focus.dispose();
    unawaited(Immersive.exit());
    super.dispose();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(LsTokens.dark.motion.toolbarLinger, () {
      if (mounted && widget.controller.phase == MediaPhase.live) setState(() => _toolbar = false);
    });
  }

  void _poke() {
    if (!_toolbar) setState(() => _toolbar = true);
    _scheduleHide();
  }

  void _toggleToolbar() {
    setState(() => _toolbar = !_toolbar);
    if (_toolbar) _scheduleHide();
  }

  void _toggleFit() {
    setState(() => _fill = !_fill);
    _poke();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _poke();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      _toggleFit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme,
      child: Builder(builder: _buildThemed),
    );
  }

  Widget _buildThemed(BuildContext context) {
    final ls = context.ls;
    final controller = widget.controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => _poke(),
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: _toolbar ? MouseCursor.defer : SystemMouseCursors.none,
          onHover: (_) => _poke(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Touch toggles the toolbar; a mouse click only keeps it up,
            // because hovering has already revealed it.
            onTapUp: (details) =>
                details.kind == PointerDeviceKind.touch ? _toggleToolbar() : _poke(),
            child: Scaffold(
              backgroundColor: ls.colors.bg,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: controller.buildView(fill: _fill)),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => controller.phase == MediaPhase.live
                        ? const SizedBox.shrink()
                        : const _WaitingForPicture(),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + ls.space.lg,
                    left: ls.space.lg,
                    right: ls.space.lg,
                    child: Center(
                      child: AnimatedSlide(
                        offset: _toolbar ? Offset.zero : const Offset(0, -0.4),
                        duration: context.motionDuration(ls.motion.base),
                        curve: ls.motion.base.curve,
                        child: AnimatedOpacity(
                          opacity: _toolbar ? 1 : 0,
                          duration: context.motionDuration(ls.motion.base),
                          child: IgnorePointer(
                            ignoring: !_toolbar,
                            child: _SessionToolbar(
                              controller: controller,
                              fill: _fill,
                              onToggleFit: _toggleFit,
                              onDisconnect: () => ref.read(activeSessionProvider.notifier).stop(),
                              onInteract: _poke,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingForPicture extends StatelessWidget {
  const _WaitingForPicture();

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final core = ls.size.deviceBadge;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LsRipples(
            coreSize: core,
            color: c.accent,
            spread: 2.4,
            child: Container(
              width: core,
              height: core,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surface,
                border: Border.all(color: c.outline),
              ),
              child: Icon(Icons.connected_tv_rounded, color: c.textSecondary, size: ls.size.icon),
            ),
          ),
          Text(
            context.l10n.sessionWaitingPicture,
            style: ls.text.body.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SessionToolbar extends StatelessWidget {
  const _SessionToolbar({
    required this.controller,
    required this.fill,
    required this.onToggleFit,
    required this.onDisconnect,
    required this.onInteract,
  });

  final SessionController controller;
  final bool fill;
  final VoidCallback onToggleFit;
  final VoidCallback onDisconnect;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final narrow = context.windowClass == LsWindowClass.compact;
    return MouseRegion(
      onHover: (_) => onInteract(),
      child: GestureDetector(
        onTap: onInteract,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ls.radius.full),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: ls.space.xl, sigmaY: ls.space.xl),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                ls.space.lg + ls.space.xs,
                ls.space.xs,
                ls.space.xs,
                ls.space.xs,
              ),
              decoration: BoxDecoration(
                color: c.surfaceRaised.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(ls.radius.full),
                border: Border.all(color: c.outline, width: ls.size.hairline),
              ),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final live = controller.phase == MediaPhase.live;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LsStatusDot(status: live ? LsStatus.connected : LsStatus.warning),
                      SizedBox(width: ls.space.sm + ls.space.xs),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: ls.size.sidePanelWidth / 2),
                          child: Text(
                            controller.peer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ls.text.label.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: ls.space.md),
                      SessionStatPills(stats: controller.stats, onMedia: true, dense: narrow),
                      SizedBox(width: ls.space.sm),
                      LsIconButton(
                        icon: fill ? Icons.fit_screen_rounded : Icons.crop_free_rounded,
                        semanticLabel: fill ? l10n.fitContain : l10n.fitCover,
                        onPressed: onToggleFit,
                      ),
                      LsIconButton(
                        icon: Icons.close_rounded,
                        tone: c.danger,
                        semanticLabel: l10n.disconnect,
                        onPressed: onDisconnect,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
