import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n.dart';
import '../../app/theme/lumen.dart';
import '../../core/node/device_labels.dart';
import '../../core/node/node_service.dart';
import 'incoming_request.dart';

/// Full-screen translucent layer with the incoming-request card.
///
/// Not dismissible by tapping outside: the user answers explicitly, or the
/// request expires.
class IncomingRequestRoute extends PageRoute<void> {
  /// Creates the route with the tokens of the presenting context.
  IncomingRequestRoute({required this.tokens, required this.reduceMotion});

  final LsTokens tokens;
  final bool reduceMotion;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => tokens.motion.base.duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return const IncomingRequestLayer();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: tokens.motion.base.curve);
    return FadeTransition(opacity: curved, child: child);
  }
}

/// Scrim, blur and the centred [IncomingRequestCard].
class IncomingRequestLayer extends ConsumerWidget {
  /// Creates the layer.
  const IncomingRequestLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final request = ref.watch(incomingRequestProvider);
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: ls.space.lg, sigmaY: ls.space.lg),
                child: ColoredBox(color: ls.colors.scrim),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(ls.space.lg),
                  child: request == null
                      ? const SizedBox.shrink()
                      : IncomingRequestCard(request: request),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "`host` 想把这台设备用作副屏" with either the PIN or Accept / Decline.
class IncomingRequestCard extends ConsumerWidget {
  /// Creates the card for [request].
  const IncomingRequestCard({super.key, required this.request});

  final IncomingRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final notifier = ref.read(incomingRequestProvider.notifier);
    final peer = request.peer;
    final pin = request.pin;
    final mode = request.mode == ShareMode.extend ? l10n.modeExtend : l10n.modeMirror;
    final badge = ls.size.deviceBadge + ls.space.lg;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: context.reduceMotion ? 1 : 0.96, end: 1),
      duration: context.motionDuration(ls.motion.base),
      curve: ls.motion.base.curve,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ls.size.cardMaxWidth),
        child: Container(
          padding: EdgeInsets.fromLTRB(ls.space.xxl, ls.space.lg, ls.space.xxl, ls.space.xxl),
          decoration: BoxDecoration(
            color: ls.brightness == Brightness.dark ? c.surfaceRaised : c.surface,
            borderRadius: BorderRadius.circular(ls.radius.xl),
            border: Border.all(color: c.outline, width: ls.size.hairline),
            boxShadow: ls.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LsRipples(
                coreSize: badge,
                color: c.accent,
                // The request times out by itself.
                continuous: true,
                spread: 1.8,
                child: LsDeviceBadge(
                  icon: deviceKindIcon(peer.kind),
                  highlighted: true,
                  size: badge,
                ),
              ),
              _Title(name: peer.name, text: l10n.incomingWants(peer.name)),
              SizedBox(height: ls.space.sm),
              Text(
                '${deviceDetails(peer)} · $mode',
                textAlign: TextAlign.center,
                style: ls.text.stat.copyWith(color: c.textSecondary),
              ),
              SizedBox(height: ls.space.xl),
              if (pin != null) ...[
                _PinBlock(request: request, pin: pin),
                SizedBox(height: ls.space.xl),
                LsButton.ghost(label: l10n.decline, expand: true, onPressed: notifier.decline),
              ] else ...[
                InlineTrustNote(text: l10n.incomingTrustedHint),
                SizedBox(height: ls.space.xl),
                Row(
                  children: [
                    Expanded(
                      child: LsButton(
                        label: l10n.decline,
                        expand: true,
                        onPressed: notifier.decline,
                      ),
                    ),
                    SizedBox(width: ls.space.md),
                    Expanded(
                      child: LsButton.primary(
                        label: l10n.accept,
                        expand: true,
                        autofocus: true,
                        loading: request.responding,
                        onPressed: notifier.accept,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.name, required this.text});

  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final base = ls.text.headline.copyWith(color: c.textSecondary, fontWeight: FontWeight.w500);
    final at = text.indexOf(name);
    final spans = at < 0
        ? [TextSpan(text: text)]
        : [
            TextSpan(text: text.substring(0, at)),
            TextSpan(
              text: name,
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: text.substring(at + name.length)),
          ];
    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: TextAlign.center,
    );
  }
}

class _PinBlock extends StatelessWidget {
  const _PinBlock({required this.request, required this.pin});

  final IncomingRequest request;
  final String pin;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: ls.space.lg, vertical: ls.space.xl),
      decoration: BoxDecoration(
        color: ls.brightness == Brightness.dark ? c.bg : c.bg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(ls.radius.lg - ls.space.xs),
        border: Border.all(color: c.outline, width: ls.size.hairline),
      ),
      child: Column(
        children: [
          Text(
            l10n.incomingPinHint(request.peer.name),
            textAlign: TextAlign.center,
            style: ls.text.label.copyWith(color: c.textSecondary),
          ),
          SizedBox(height: ls.space.md),
          LsPinDisplay(pin: pin),
          SizedBox(height: ls.space.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LsCountdownRing(expiresAt: request.expiresAt, total: IncomingRequest.pinLifetime),
              SizedBox(width: ls.space.md),
              Flexible(
                child: Text(
                  l10n.incomingPinValidity,
                  style: ls.text.caption.copyWith(color: c.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shield + "trusted device" line used on the trusted request card.
class InlineTrustNote extends StatelessWidget {
  /// Creates the note.
  const InlineTrustNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_rounded, size: ls.size.iconSmall, color: c.accent),
        SizedBox(width: ls.space.sm),
        Flexible(
          child: Text(text, style: ls.text.label.copyWith(color: c.textSecondary)),
        ),
      ],
    );
  }
}
