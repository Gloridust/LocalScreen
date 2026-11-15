import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n.dart';
import '../../app/theme/lumen.dart';
import '../../core/update/update_controller.dart';
import 'update_format.dart';
import 'update_sheet.dart';
import 'update_widgets.dart';

/// Home-screen card announcing a new version and following its install.
/// Takes no space while there is nothing to say.
class UpdateBanner extends ConsumerWidget {
  /// Creates the banner; [padding] applies only while it is shown.
  const UpdateBanner({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final state = ref.watch(updateBannerProvider);
    final content = state == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: padding,
            child: _BannerCard(state: state),
          );
    final duration = context.motionDuration(ls.motion.base);
    // With motion reduced there is nothing to animate (and AnimatedSize
    // does not accept a zero duration).
    if (duration == Duration.zero) return content;
    return AnimatedSize(
      duration: duration,
      curve: ls.motion.base.curve,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

class _BannerCard extends ConsumerWidget {
  const _BannerCard({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final controller = ref.read(updateControllerProvider.notifier);
    final version = '${state.release?.version}';
    final caption = ls.text.caption.copyWith(color: c.textSecondary);
    void open() => showUpdateSheet(context);
    final dismiss = LsIconButton(
      icon: Icons.close_rounded,
      semanticLabel: l10n.updateLater,
      onPressed: controller.skip,
    );

    final (IconData icon, String title, Widget detail, List<Widget> actions) = switch (state) {
      UpdateDownloading(:final fraction) => (
        Icons.downloading_rounded,
        l10n.updateBannerTitle(version),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: ls.space.xs),
            UpdateProgressBar(fraction: fraction),
            SizedBox(height: ls.space.xs),
            Text(l10n.updateDownloading(((fraction ?? 0) * 100).round()), style: caption),
          ],
        ),
        const [],
      ),
      UpdateInstalling() => (
        Icons.downloading_rounded,
        l10n.updateBannerTitle(version),
        Text(l10n.updateInstalling, style: caption),
        [LsSpinner(size: ls.size.icon)],
      ),
      UpdateInstalled() => (
        Icons.restart_alt_rounded,
        l10n.updateInstalledTitle(version),
        Text(l10n.updateInstalledSubtitle, style: caption),
        [
          LsButton.primary(
            label: l10n.updateRestart,
            size: LsButtonSize.small,
            onPressed: controller.restart,
          ),
        ],
      ),
      UpdateOpened() => (
        Icons.open_in_new_rounded,
        l10n.updateOpenedTitle,
        Text(l10n.updateOpenedSubtitleMac, style: caption),
        [dismiss],
      ),
      UpdateFailed(:final failure) => (
        Icons.error_outline_rounded,
        l10n.updateBannerTitle(version),
        Text(updateFailureText(l10n, failure), style: caption.copyWith(color: c.danger)),
        [LsButton(label: l10n.retry, size: LsButtonSize.small, onPressed: open), dismiss],
      ),
      _ => (
        Icons.arrow_upward_rounded,
        l10n.updateBannerTitle(version),
        Text(l10n.updateBannerSubtitle('${ref.watch(appVersionProvider)}'), style: caption),
        [
          LsButton.primary(label: l10n.updateAction, size: LsButtonSize.small, onPressed: open),
          dismiss,
        ],
      ),
    };

    return LsCard(
      padding: EdgeInsets.fromLTRB(ls.space.lg, ls.space.md, ls.space.sm, ls.space.md),
      onTap: open,
      semanticLabel: title,
      child: Row(
        children: [
          UpdateBadge(icon: icon, danger: state is UpdateFailed),
          SizedBox(width: ls.space.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ls.text.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
                ),
                detail,
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(width: ls.space.sm),
            for (final (i, a) in actions.indexed) ...[if (i > 0) SizedBox(width: ls.space.xs), a],
          ] else
            SizedBox(width: ls.space.sm),
        ],
      ),
    );
  }
}
