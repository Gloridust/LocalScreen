import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n.dart';
import '../../app/theme/lumen.dart';
import '../../core/media/quality.dart';
import '../../core/node/device_labels.dart';
import '../../core/node/node_service.dart';
import 'outgoing_request.dart';
import 'widgets/inline_note.dart';

/// Host side: choose mode and quality, start casting, and enter the PIN
/// in place when the display asks for one.
class ConnectSheet extends ConsumerWidget {
  /// Creates the sheet; it reads [outgoingRequestProvider].
  const ConnectSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final request = ref.watch(outgoingRequestProvider);
    if (request == null) return const SizedBox.shrink();
    final pinStage =
        request.phase == OutgoingPhase.awaitingPin || request.phase == OutgoingPhase.verifying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeerHeader(peer: request.peer),
        SizedBox(height: ls.space.xl),
        _MaybeAnimatedSize(
          child: AnimatedSwitcher(
            duration: context.motionDuration(ls.motion.base),
            switchInCurve: ls.motion.base.curve,
            switchOutCurve: ls.motion.fast.curve,
            transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            child: pinStage
                ? _PinStage(key: const ValueKey('pin'), request: request)
                : _OptionsStage(key: const ValueKey('options'), request: request),
          ),
        ),
      ],
    );
  }
}

/// [AnimatedSize] unless motion is reduced (a zero-length AnimatedSize
/// would re-layout itself mid-layout).
class _MaybeAnimatedSize extends StatelessWidget {
  const _MaybeAnimatedSize({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    if (context.reduceMotion) return child;
    return AnimatedSize(
      duration: ls.motion.base.duration,
      curve: ls.motion.base.curve,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class _PeerHeader extends StatelessWidget {
  const _PeerHeader({required this.peer});

  final DeviceInfo peer;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    return Row(
      children: [
        LsDeviceBadge(icon: deviceKindIcon(peer.kind), highlighted: true),
        SizedBox(width: ls.space.md + ls.space.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                peer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ls.text.headline.copyWith(color: c.textPrimary),
              ),
              SizedBox(height: ls.space.xs / 2),
              Text(deviceDetails(peer), style: ls.text.stat.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
        if (peer.trusted)
          LsTrustedMark(label: context.l10n.trusted, icon: Icons.verified_user_rounded),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    return Padding(
      padding: EdgeInsets.only(bottom: ls.space.sm),
      child: Text(text, style: ls.text.label.copyWith(color: ls.colors.textSecondary)),
    );
  }
}

/// Short description of [quality], shared with settings and the console.
String qualityLabel(AppLocalizations l10n, QualityPreset quality) => switch (quality) {
  QualityPreset.smooth => l10n.qualitySmooth,
  QualityPreset.balanced => l10n.qualityBalanced,
  QualityPreset.clear => l10n.qualityClear,
};

/// The three quality presets as segments.
List<LsSegment<QualityPreset>> qualitySegments(AppLocalizations l10n) => [
  for (final q in QualityPreset.values) LsSegment(value: q, label: qualityLabel(l10n, q)),
];

/// The share modes as segments; Extend carries a "soon" badge in M1.
List<LsSegment<ShareMode>> modeSegments(AppLocalizations l10n) => [
  LsSegment(
    value: ShareMode.extend,
    label: l10n.modeExtend,
    icon: Icons.add_to_queue_rounded,
    badge: OutgoingRequest.extendSupported ? null : l10n.comingSoon,
  ),
  LsSegment(value: ShareMode.mirror, label: l10n.modeMirror, icon: Icons.screen_share_outlined),
];

class _OptionsStage extends ConsumerWidget {
  const _OptionsStage({super.key, required this.request});

  final OutgoingRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final notifier = ref.read(outgoingRequestProvider.notifier);
    final busy = request.phase == OutgoingPhase.requesting;
    final failed = request.phase == OutgoingPhase.failed;
    final editable = !busy;
    final modeDescription = request.mode == ShareMode.extend
        ? l10n.modeExtendDescription
        : l10n.modeMirrorDescription;
    final qualityDescription = switch (request.quality) {
      QualityPreset.smooth => l10n.qualitySmoothDescription,
      QualityPreset.balanced => l10n.qualityBalancedDescription,
      QualityPreset.clear => l10n.qualityClearDescription,
    };
    final failure = switch (request.failure) {
      OutgoingFailure.declined => l10n.failDeclined(request.peer.name),
      OutgoingFailure.timeout => l10n.failTimeout(request.peer.name),
      OutgoingFailure.pinFailed => l10n.failPin,
      OutgoingFailure.network => l10n.failNetwork,
      OutgoingFailure.request => l10n.failRequest,
      null => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(l10n.connectModeLabel),
        LsSegmented<ShareMode>(
          segments: modeSegments(l10n),
          value: request.mode,
          onChanged: editable ? notifier.setMode : null,
        ),
        SizedBox(height: ls.space.sm),
        Text(modeDescription, style: ls.text.caption.copyWith(color: c.textSecondary)),
        if (request.mode == ShareMode.extend && !OutgoingRequest.extendSupported) ...[
          SizedBox(height: ls.space.md),
          InlineNote(icon: Icons.info_outline_rounded, text: l10n.modeExtendUnavailable),
        ],
        SizedBox(height: ls.space.xl),
        _FieldLabel(l10n.connectQualityLabel),
        LsSegmented<QualityPreset>(
          segments: qualitySegments(l10n),
          value: request.quality,
          onChanged: editable ? notifier.setQuality : null,
        ),
        SizedBox(height: ls.space.sm),
        Text(qualityDescription, style: ls.text.caption.copyWith(color: c.textSecondary)),
        if (failure != null) ...[
          SizedBox(height: ls.space.xl),
          InlineNote(icon: Icons.error_outline_rounded, text: failure, tone: c.danger),
        ],
        SizedBox(height: ls.space.xxl),
        LsButton.primary(
          label: busy
              ? l10n.waitingForPeer(request.peer.name)
              : failed
              ? l10n.retry
              : l10n.startCasting,
          icon: failed ? Icons.refresh_rounded : Icons.cast_rounded,
          expand: true,
          loading: busy,
          autofocus: true,
          onPressed: busy ? null : notifier.start,
        ),
      ],
    );
  }
}

class _PinStage extends ConsumerWidget {
  const _PinStage({super.key, required this.request});

  final OutgoingRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final notifier = ref.read(outgoingRequestProvider.notifier);
    final verifying = request.phase == OutgoingPhase.verifying;
    final attempts = request.attemptsLeft;
    final Widget status;
    if (verifying) {
      status = Row(
        key: const ValueKey('verifying'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LsSpinner(),
          SizedBox(width: ls.space.sm),
          Text(l10n.pinVerifying, style: ls.text.caption.copyWith(color: c.textSecondary)),
        ],
      );
    } else if (request.rejections > 0 && attempts != null) {
      status = Text(
        l10n.pinWrong(attempts),
        key: ValueKey('wrong-${request.rejections}'),
        textAlign: TextAlign.center,
        style: ls.text.caption.copyWith(color: c.danger),
      );
    } else {
      status = SizedBox(
        key: const ValueKey('idle'),
        height: ls.text.caption.fontSize! * ls.text.caption.height!,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.pinTitle,
          textAlign: TextAlign.center,
          style: ls.text.headline.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: ls.space.sm),
        Text(
          l10n.pinPrompt(request.peer.name),
          textAlign: TextAlign.center,
          style: ls.text.body.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: ls.space.xl),
        LsPinInput(
          enabled: !verifying,
          shakeSignal: request.rejections,
          semanticLabel: l10n.pinInputLabel,
          onCompleted: notifier.submitPin,
        ),
        SizedBox(height: ls.space.lg),
        AnimatedSwitcher(duration: context.motionDuration(ls.motion.fast), child: status),
        SizedBox(height: ls.space.xl),
        LsButton.ghost(
          label: l10n.cancel,
          expand: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
