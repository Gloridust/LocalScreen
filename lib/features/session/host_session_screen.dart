import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n.dart';
import '../../app/theme/lumen.dart';
import '../../core/media/media_session.dart';
import '../../core/node/device_labels.dart';
import '../pairing/connect_sheet.dart';
import 'active_session.dart';
import 'session_controller.dart';
import 'widgets/session_stats.dart';

/// Host side: a compact console while this screen is being sent.
class HostSessionScreen extends ConsumerWidget {
  /// Creates the console for [controller].
  const HostSessionScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: ls.colors.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(ls.space.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ls.size.cardMaxWidth),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => _Console(
                    controller: controller,
                    onStop: () => ref.read(activeSessionProvider.notifier).stop(),
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

class _Console extends StatelessWidget {
  const _Console({required this.controller, required this.onStop});

  final SessionController controller;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final peer = controller.peer;
    final phase = controller.phase;
    final (status, statusText) = switch (phase) {
      _ when controller.preparingDisplay => (LsStatus.warning, l10n.hostPreparingDisplay),
      MediaPhase.live => (LsStatus.connected, l10n.hostLive),
      MediaPhase.capturing when controller.virtualDisplayLabel != null => (
        LsStatus.warning,
        l10n.hostSelectingVirtualDisplay,
      ),
      MediaPhase.capturing => (LsStatus.warning, l10n.hostSelectingSource),
      MediaPhase.failed => (LsStatus.error, l10n.failNetwork),
      MediaPhase.idle || MediaPhase.connecting => (LsStatus.warning, l10n.hostConnecting),
    };
    return LsCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LsStatusDot(status: status),
              SizedBox(width: ls.space.sm),
              Expanded(
                child: Text(statusText, style: ls.text.label.copyWith(color: c.textSecondary)),
              ),
              if (phase != MediaPhase.live) const LsSpinner(),
            ],
          ),
          SizedBox(height: ls.space.xl),
          Text(l10n.hostCastingTo, style: ls.text.caption.copyWith(color: c.textTertiary)),
          SizedBox(height: ls.space.sm),
          Row(
            children: [
              LsDeviceBadge(icon: deviceKindIcon(peer.kind), highlighted: phase == MediaPhase.live),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l10n.hostElapsed, style: ls.text.caption.copyWith(color: c.textTertiary)),
                  SizedBox(height: ls.space.xs / 2),
                  ElapsedText(
                    since: controller.startedAt,
                    style: ls.text.headline.copyWith(
                      color: c.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: ls.space.lg),
          SessionStatPills(stats: controller.stats),
          SizedBox(height: ls.space.xl),
          const LsDivider(),
          SizedBox(height: ls.space.xl),
          Text(l10n.connectQualityLabel, style: ls.text.label.copyWith(color: c.textSecondary)),
          SizedBox(height: ls.space.sm),
          LsSegmented(
            segments: qualitySegments(l10n),
            value: controller.quality,
            onChanged: controller.setQuality,
          ),
          SizedBox(height: ls.space.xl),
          LsButton.danger(
            label: l10n.stopCasting,
            icon: Icons.stop_circle_outlined,
            expand: true,
            onPressed: onStop,
          ),
        ],
      ),
    );
  }
}
