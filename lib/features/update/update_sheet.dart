import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/l10n.dart';
import '../../app/theme/lumen.dart';
import '../../core/update/release.dart';
import '../../core/update/release_notes.dart';
import '../../core/update/update_controller.dart';
import '../../core/update/update_source.dart';
import '../session/active_session.dart';
import 'update_format.dart';
import 'update_widgets.dart';

/// Shows what the announced release brings and installs it.
Future<void> showUpdateSheet(BuildContext context) =>
    showLsSheet<void>(context, builder: (_) => const UpdateSheet());

/// Release notes, what installing involves, and the one action that fits
/// the current step. Follows the controller, so progress shows live.
class UpdateSheet extends ConsumerWidget {
  /// Creates the sheet.
  const UpdateSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final state = ref.watch(updateControllerProvider);
    final release = state.release;
    if (release == null) return const SizedBox.shrink();
    final installer = ref.watch(updateInstallerProvider);
    final busy = ref.watch(activeSessionProvider) != null;
    final current = ref.watch(appVersionProvider);
    final published = release.publishedAt;
    final meta = l10n.updateSheetMeta(
      '$current',
      published == null ? '—' : DateFormat.yMMMd(l10n.localeName).format(published.toLocal()),
    );
    final notes = parseReleaseNotes(release.notes);
    final hint = switch (state) {
      UpdateInstalled() => l10n.updateInstalledSubtitle,
      UpdateOpened() => l10n.updateOpenedSubtitleMac,
      _ when busy => l10n.updateHintSession,
      _ => installHint(l10n, installer),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const UpdateBadge(icon: Icons.arrow_upward_rounded),
            SizedBox(width: ls.space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LocalScreen ${release.version}',
                    style: ls.text.headline.copyWith(color: c.textPrimary),
                  ),
                  SizedBox(height: ls.space.xs / 2),
                  Text(meta, style: ls.text.caption.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        if (notes.isNotEmpty) ...[
          SizedBox(height: ls.space.xl),
          Text(l10n.updateWhatsNew, style: ls.text.label.copyWith(color: c.textSecondary)),
          SizedBox(height: ls.space.sm),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: ls.size.sidePanelWidth * 0.6),
            child: SingleChildScrollView(child: _ReleaseNotes(blocks: notes)),
          ),
        ],
        SizedBox(height: ls.space.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: LsButton.ghost(
            label: l10n.updateViewRelease,
            icon: Icons.open_in_new_rounded,
            size: LsButtonSize.small,
            onPressed: () => ref.read(updateControllerProvider.notifier).openPage(),
          ),
        ),
        SizedBox(height: ls.space.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: ls.size.iconSmall, color: c.textTertiary),
            SizedBox(width: ls.space.sm),
            Expanded(
              child: Text(hint, style: ls.text.caption.copyWith(color: c.textTertiary)),
            ),
          ],
        ),
        SizedBox(height: ls.space.xl),
        _Action(state: state, release: release, busy: busy),
      ],
    );
  }
}

class _Action extends ConsumerWidget {
  const _Action({required this.state, required this.release, required this.busy});

  final UpdateState state;
  final AppRelease release;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final controller = ref.read(updateControllerProvider.notifier);
    final installer = ref.watch(updateInstallerProvider);
    final package = installer.package;
    final asset = package == null ? null : release.assetFor(package);
    final canInstall = installer.canInstall && asset != null;

    Widget primary(String label, VoidCallback? onPressed, {bool loading = false}) =>
        LsButton.primary(label: label, expand: true, loading: loading, onPressed: onPressed);
    final openPage = primary(l10n.updateOpenPage, controller.openPage);
    final install = canInstall
        ? primary(
            l10n.updateInstallButton(formatBytes(asset.size)),
            busy ? null : controller.install,
          )
        : openPage;

    return switch (state) {
      UpdateDownloading(:final fraction, :final received, :final total) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UpdateProgressBar(fraction: fraction),
          SizedBox(height: ls.space.sm),
          Row(
            children: [
              Text(
                l10n.updateDownloading(((fraction ?? 0) * 100).round()),
                style: ls.text.caption.copyWith(color: c.textSecondary),
              ),
              const Spacer(),
              if (total > 0)
                Text(
                  '${formatBytes(received)} / ${formatBytes(total)}',
                  style: ls.text.stat.copyWith(color: c.textTertiary),
                ),
            ],
          ),
        ],
      ),
      UpdateInstalling() => primary(l10n.updateInstalling, null, loading: true),
      UpdateInstalled() => primary(l10n.updateRestart, busy ? null : controller.restart),
      UpdateOpened() => openPage,
      UpdateFailed(:final failure) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            updateFailureText(l10n, failure),
            textAlign: TextAlign.center,
            style: ls.text.caption.copyWith(color: c.danger),
          ),
          SizedBox(height: ls.space.md),
          if (failure == UpdateFailure.noPackage) openPage else install,
        ],
      ),
      _ => install,
    };
  }
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.blocks});

  final List<NoteBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final body = ls.text.body.copyWith(color: c.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, block) in blocks.indexed)
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : (block is NoteHeading ? ls.space.md : ls.space.xs),
            ),
            child: switch (block) {
              NoteHeading(:final text) => Text(
                text,
                style: ls.text.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
              ),
              NoteBullet(:final text) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: ls.space.sm),
                    child: Text('•', style: body.copyWith(color: c.accent)),
                  ),
                  Expanded(child: Text(text, style: body)),
                ],
              ),
              NoteParagraph(:final text) => Text(text, style: body),
            },
          ),
      ],
    );
  }
}
