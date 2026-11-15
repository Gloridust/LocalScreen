import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n.dart';
import '../../../app/theme/lumen.dart';
import '../../../core/node/device_labels.dart';
import '../../../core/node/local_node.dart';
import '../../../core/platform/device_profile.dart';
import '../../../core/prefs/preferences.dart';

/// What the home screen shows about this device.
@immutable
class LocalDeviceView {
  /// Collects the view from providers.
  factory LocalDeviceView.watch(WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final profile = ref.watch(deviceProfileProvider);
    final node = ref.watch(localNodeProvider);
    return LocalDeviceView._(
      name: prefs.deviceName ?? profile.defaultName,
      icon: deviceKindIcon(profile.kind),
      discoverable: prefs.discoverable,
      node: node,
    );
  }

  const LocalDeviceView._({
    required this.name,
    required this.icon,
    required this.discoverable,
    required this.node,
  });

  final String name;
  final IconData icon;
  final bool discoverable;
  final LocalNodeState node;

  /// First LAN address once running.
  String? get address => switch (node) {
    LocalNodeRunning(:final identity) when identity.addresses.isNotEmpty =>
      identity.addresses.first,
    _ => null,
  };

  /// Whether the orb should glow and ripple.
  bool get radiating => discoverable && node is LocalNodeRunning;
}

/// "● 可被发现 · 192.168.1.10" status line.
class LocalStatusLine extends StatelessWidget {
  /// Creates the status line.
  const LocalStatusLine({super.key, required this.view, this.center = false});

  final LocalDeviceView view;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final (status, text) = switch (view.node) {
      LocalNodeStarting() => (LsStatus.idle, l10n.localStarting),
      LocalNodeFailed() => (LsStatus.error, l10n.localFailed),
      LocalNodeRunning() =>
        view.discoverable
            ? (LsStatus.online, l10n.localDiscoverable)
            : (LsStatus.idle, l10n.localHidden),
    };
    final address = view.address;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        LsStatusDot(status: status),
        SizedBox(width: ls.space.sm),
        Text(text, style: ls.text.label.copyWith(color: c.textSecondary)),
        if (address != null) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ls.space.sm),
            child: Text('·', style: ls.text.label.copyWith(color: c.textTertiary)),
          ),
          Text(address, style: ls.text.stat.copyWith(color: c.textSecondary)),
        ],
      ],
    );
  }
}

/// Compact / medium header: orb, name and status, centred.
class LocalDeviceHeader extends ConsumerWidget {
  /// Creates the header.
  const LocalDeviceHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final view = LocalDeviceView.watch(ref);
    return Column(
      children: [
        LsOrb(size: ls.size.orbCompact, icon: view.icon, active: view.radiating),
        SizedBox(height: ls.space.xs),
        Text(
          view.name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ls.text.title.copyWith(color: ls.colors.textPrimary),
        ),
        SizedBox(height: ls.space.sm),
        LocalStatusLine(view: view, center: true),
        if (view.node is LocalNodeFailed) ...[SizedBox(height: ls.space.lg), const _StartFailure()],
      ],
    );
  }
}

/// Expanded layout: the 360-wide local panel.
class LocalDevicePanel extends ConsumerWidget {
  /// Creates the panel.
  const LocalDevicePanel({super.key, required this.onManualConnect, required this.onOpenSettings});

  final VoidCallback onManualConnect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final view = LocalDeviceView.watch(ref);
    final running = view.node is LocalNodeRunning;
    return LsCard(
      padding: EdgeInsets.all(ls.space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Wordmark(),
          const Spacer(),
          Center(
            child: LsOrb(size: ls.size.orbExpanded, icon: view.icon, active: view.radiating),
          ),
          SizedBox(height: ls.space.md),
          Text(
            l10n.thisDevice,
            textAlign: TextAlign.center,
            style: ls.text.caption.copyWith(color: c.textTertiary),
          ),
          SizedBox(height: ls.space.xs),
          Text(
            view.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ls.text.title.copyWith(color: c.textPrimary),
          ),
          SizedBox(height: ls.space.sm),
          LocalStatusLine(view: view, center: true),
          if (view.node is LocalNodeFailed) ...[
            SizedBox(height: ls.space.lg),
            const _StartFailure(),
          ],
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: ls.space.lg, vertical: ls.space.md),
            decoration: BoxDecoration(
              color: ls.brightness == Brightness.dark ? c.bg : c.bg.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(ls.radius.md),
              border: Border.all(color: c.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_tethering_rounded, size: ls.size.icon, color: c.textSecondary),
                SizedBox(width: ls.space.md),
                Expanded(
                  child: Text(
                    l10n.discoverableToggle,
                    style: ls.text.label.copyWith(color: c.textPrimary),
                  ),
                ),
                LsSwitch(
                  value: view.discoverable,
                  semanticLabel: l10n.discoverableToggle,
                  onChanged: running
                      ? (v) => ref.read(localNodeProvider.notifier).setDiscoverable(v)
                      : null,
                ),
              ],
            ),
          ),
          SizedBox(height: ls.space.md),
          LsButton(
            label: l10n.manualConnect,
            icon: Icons.lan_outlined,
            expand: true,
            onPressed: running ? onManualConnect : null,
          ),
          SizedBox(height: ls.space.sm),
          LsButton.ghost(
            label: l10n.settings,
            icon: Icons.tune_rounded,
            expand: true,
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _StartFailure extends ConsumerWidget {
  const _StartFailure();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final l10n = context.l10n;
    return Column(
      children: [
        Text(
          l10n.localFailedHint,
          textAlign: TextAlign.center,
          style: ls.text.caption.copyWith(color: ls.colors.textSecondary),
        ),
        SizedBox(height: ls.space.md),
        LsButton(
          label: l10n.retry,
          size: LsButtonSize.small,
          icon: Icons.refresh_rounded,
          onPressed: () => ref.read(localNodeProvider.notifier).retry(),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    return Text(
      context.l10n.appTitle,
      style: ls.text.headline.copyWith(color: ls.colors.textPrimary),
    );
  }
}

/// Compact top bar: wordmark and settings.
class HomeTopBar extends StatelessWidget {
  /// Creates the top bar.
  const HomeTopBar({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Wordmark(),
        const Spacer(),
        LsIconButton(
          icon: Icons.tune_rounded,
          semanticLabel: context.l10n.settings,
          onPressed: onOpenSettings,
        ),
      ],
    );
  }
}
