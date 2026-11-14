import 'package:flutter/material.dart';

import '../context_ext.dart';
import '../tokens.dart';

/// Shows [builder] as a Lumen sheet: a bottom panel on compact widths and a
/// centred dialog from `medium` up (DESIGN.md › 连接面板).
Future<T?> showLsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  String? barrierLabel,
}) {
  return Navigator.of(context).push<T>(
    _LsSheetRoute<T>(
      builder: builder,
      dismissible: dismissible,
      label: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
      tokens: context.ls,
      reduceMotion: context.reduceMotion,
    ),
  );
}

class _LsSheetRoute<T> extends PopupRoute<T> {
  _LsSheetRoute({
    required this.builder,
    required this.dismissible,
    required this.label,
    required this.tokens,
    required this.reduceMotion,
  });

  final WidgetBuilder builder;
  final bool dismissible;
  final String label;
  final LsTokens tokens;
  final bool reduceMotion;

  @override
  Color? get barrierColor => tokens.colors.scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => label;

  @override
  Duration get transitionDuration =>
      reduceMotion ? tokens.motion.fast.duration : tokens.motion.base.duration;

  @override
  Duration get reverseTransitionDuration => tokens.motion.fast.duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _LsSheetFrame(
      compact: _isCompact(context),
      child: Builder(builder: builder),
    );
  }

  bool _isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tokens.size.compactMax;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: tokens.motion.base.curve,
      reverseCurve: tokens.motion.fast.curve,
    );
    if (reduceMotion) return FadeTransition(opacity: curved, child: child);
    if (_isCompact(context)) {
      return SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
        child: child,
      );
    }
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
    );
  }
}

class _LsSheetFrame extends StatelessWidget {
  const _LsSheetFrame({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final mq = MediaQuery.of(context);
    final fill = ls.brightness == Brightness.dark ? c.surfaceRaised : c.surface;
    final radius = Radius.circular(ls.radius.xl);
    final content = Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: ls.text.body.copyWith(color: c.textPrimary),
        child: child,
      ),
    );
    if (compact) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.vertical(top: radius),
            border: Border(
              top: BorderSide(color: c.outline, width: ls.size.hairline),
            ),
            boxShadow: ls.floatingShadow,
          ),
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(ls.space.xl, ls.space.md, ls.space.xl, ls.space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: ls.space.xxl + ls.space.sm,
                      height: ls.space.xs,
                      margin: EdgeInsets.only(bottom: ls.space.lg),
                      decoration: BoxDecoration(
                        color: c.textTertiary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(ls.radius.full),
                      ),
                    ),
                  ),
                  content,
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ls.size.sheetMaxWidth,
            maxHeight: mq.size.height - ls.space.xxxl * 2,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.all(radius),
              border: Border.all(color: c.outline, width: ls.size.hairline),
              boxShadow: ls.floatingShadow,
            ),
            child: SingleChildScrollView(padding: EdgeInsets.all(ls.space.xxl), child: content),
          ),
        ),
      ),
    );
  }
}
