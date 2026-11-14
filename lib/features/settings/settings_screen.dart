import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/l10n.dart';
import '../../app/theme/lumen.dart';
import '../../core/media/quality.dart';
import '../../core/node/device_labels.dart';
import '../../core/node/local_node.dart';
import '../../core/node/node_service.dart';
import '../../core/platform/autostart.dart';
import '../../core/platform/device_profile.dart';
import '../../core/platform/virtual_display.dart';
import '../../core/prefs/preferences.dart';
import '../pairing/connect_sheet.dart';
import 'trusted_devices_controller.dart';
import 'widgets/settings_group.dart';

/// App version for the About group.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Settings: this device · connection · trusted devices · appearance · about.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final side = (width - ls.size.readableMaxWidth) / 2;
    final pad = side > ls.space.xl ? side : ls.space.lg + ls.space.xs;
    final groupGap = SizedBox(height: ls.space.xxl);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, ls.space.md, pad, ls.space.xxxl),
          children: [
            Row(
              children: [
                LsIconButton(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: l10n.back,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                SizedBox(width: ls.space.sm),
                Text(l10n.settings, style: ls.text.title.copyWith(color: c.textPrimary)),
              ],
            ),
            SizedBox(height: ls.space.xl),
            const _DeviceGroup(),
            groupGap,
            const _ConnectionGroup(),
            groupGap,
            const _TrustedGroup(),
            groupGap,
            const _AppearanceGroup(),
            groupGap,
            const _AboutGroup(),
          ],
        ),
      ),
    );
  }
}

/// Lays a segmented control trailing on wide screens and below on compact.
SettingsRow _choiceRow<T>(
  BuildContext context, {
  required String title,
  required List<LsSegment<T>> segments,
  required T value,
  required ValueChanged<T> onChanged,
}) {
  final ls = context.ls;
  final compact = context.windowClass == LsWindowClass.compact;
  final control = LsSegmented<T>(
    segments: segments,
    value: value,
    onChanged: onChanged,
    dense: true,
  );
  return SettingsRow(
    title: title,
    trailing: compact ? null : SizedBox(width: ls.size.sidePanelWidth * 0.75, child: control),
    below: compact ? control : null,
  );
}

class _DeviceGroup extends ConsumerWidget {
  const _DeviceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final prefs = ref.watch(preferencesProvider);
    final profile = ref.watch(deviceProfileProvider);
    final node = ref.watch(localNodeProvider);
    final name = prefs.deviceName ?? profile.defaultName;
    final address = switch (node) {
      LocalNodeRunning(:final identity) => [
        ...identity.addresses.take(1),
        if (identity.addresses.isNotEmpty) ':${identity.port}',
      ].join(),
      _ => '—',
    };
    return SettingsGroup(
      title: l10n.sectionDevice,
      children: [
        SettingsRow(
          title: l10n.deviceName,
          description: l10n.deviceNameDescription,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ls.size.sidePanelWidth / 2),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ls.text.body.copyWith(color: c.textSecondary),
                ),
              ),
              SizedBox(width: ls.space.xs),
              Icon(Icons.chevron_right_rounded, color: c.textTertiary, size: ls.size.icon),
            ],
          ),
          onTap: () => showLsSheet<void>(context, builder: (_) => _RenameSheet(initial: name)),
        ),
        SettingsRow(
          title: l10n.discoverable,
          description: l10n.discoverableDescription,
          trailing: LsSwitch(
            value: prefs.discoverable,
            semanticLabel: l10n.discoverable,
            onChanged: (v) => ref.read(localNodeProvider.notifier).setDiscoverable(v),
          ),
        ),
        if (ref.watch(autostartServiceProvider).supported)
          SettingsRow(
            title: l10n.launchAtStartup,
            description: l10n.launchAtStartupDescription,
            trailing: LsSwitch(
              value: prefs.launchAtStartup,
              semanticLabel: l10n.launchAtStartup,
              onChanged: (v) => ref.read(autostartControllerProvider).setEnabled(v),
            ),
          ),
        SettingsRow(
          title: l10n.localAddress,
          trailing: Text(address, style: ls.text.stat.copyWith(color: c.textSecondary)),
        ),
      ],
    );
  }
}

class _ConnectionGroup extends ConsumerWidget {
  const _ConnectionGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    return SettingsGroup(
      title: l10n.sectionConnection,
      children: [
        _choiceRow<ShareMode>(
          context,
          title: l10n.defaultMode,
          segments: modeSegments(
            l10n,
            extendSupported: ref.watch(extendSupportedProvider).value ?? false,
          ),
          value: prefs.defaultMode,
          onChanged: (m) => notifier.update((p) => p.copyWith(defaultMode: m)),
        ),
        _choiceRow<QualityPreset>(
          context,
          title: l10n.defaultQuality,
          segments: qualitySegments(l10n),
          value: prefs.defaultQuality,
          onChanged: (q) => notifier.update((p) => p.copyWith(defaultQuality: q)),
        ),
        SettingsRow(
          title: l10n.autoAccept,
          description: l10n.autoAcceptDescription,
          trailing: LsSwitch(
            value: prefs.autoAcceptTrusted,
            semanticLabel: l10n.autoAccept,
            onChanged: (v) => notifier.update((p) => p.copyWith(autoAcceptTrusted: v)),
          ),
        ),
      ],
    );
  }
}

class _TrustedGroup extends ConsumerWidget {
  const _TrustedGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final trusted = ref.watch(trustedDevicesProvider);
    return SettingsGroup(
      title: l10n.sectionTrusted,
      children: [
        if (trusted.isEmpty)
          Padding(
            padding: EdgeInsets.all(ls.space.lg + ls.space.xs),
            child: Text(l10n.trustedEmpty, style: ls.text.body.copyWith(color: c.textSecondary)),
          )
        else
          for (final d in trusted)
            SettingsRow(
              key: ValueKey(d.id),
              leading: LsDeviceBadge(icon: deviceKindIcon(d.kind)),
              title: d.name,
              description: deviceDetails(d),
              trailing: LsButton.ghost(
                label: l10n.forget,
                size: LsButtonSize.small,
                onPressed: () =>
                    showLsSheet<void>(context, builder: (_) => _ForgetSheet(device: d)),
              ),
            ),
      ],
    );
  }
}

class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    return SettingsGroup(
      title: l10n.sectionAppearance,
      children: [
        _choiceRow<ThemeMode>(
          context,
          title: l10n.theme,
          segments: [
            LsSegment(value: ThemeMode.system, label: l10n.themeSystem),
            LsSegment(value: ThemeMode.light, label: l10n.themeLight),
            LsSegment(value: ThemeMode.dark, label: l10n.themeDark),
          ],
          value: prefs.themeMode,
          onChanged: (m) => notifier.update((p) => p.copyWith(themeMode: m)),
        ),
        _choiceRow<String>(
          context,
          title: l10n.language,
          segments: [
            LsSegment(value: '', label: l10n.languageSystem),
            const LsSegment(value: 'zh', label: '中文'),
            const LsSegment(value: 'en', label: 'English'),
          ],
          value: prefs.locale?.languageCode ?? '',
          onChanged: (code) => notifier.update(
            (p) => code.isEmpty ? p.copyWith(clearLocale: true) : p.copyWith(locale: Locale(code)),
          ),
        ),
      ],
    );
  }
}

class _AboutGroup extends ConsumerWidget {
  const _AboutGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    final version = ref.watch(appVersionProvider).value ?? '—';
    final node = ref.watch(localNodeProvider);
    final id = node is LocalNodeRunning ? node.identity.id : '—';
    final value = ls.text.stat.copyWith(color: c.textSecondary);
    return SettingsGroup(
      title: l10n.sectionAbout,
      children: [
        SettingsRow(
          title: l10n.aboutVersion,
          trailing: Text(version, style: value),
        ),
        SettingsRow(
          title: l10n.aboutDeviceId,
          trailing: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ls.size.sidePanelWidth / 2),
            child: SelectableText(id, maxLines: 1, style: value),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(ls.space.lg + ls.space.xs),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: ls.size.iconSmall, color: c.textTertiary),
              SizedBox(width: ls.space.sm),
              Expanded(
                child: Text(
                  l10n.aboutPrivacy,
                  style: ls.text.caption.copyWith(color: c.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RenameSheet extends ConsumerStatefulWidget {
  const _RenameSheet({required this.initial});

  final String initial;

  @override
  ConsumerState<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends ConsumerState<_RenameSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String name) async {
    Navigator.of(context).pop();
    await ref.read(localNodeProvider.notifier).rename(name);
  }

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.deviceName, style: ls.text.headline.copyWith(color: c.textPrimary)),
        SizedBox(height: ls.space.sm),
        Text(l10n.deviceNameDescription, style: ls.text.body.copyWith(color: c.textSecondary)),
        SizedBox(height: ls.space.xl),
        LsTextField(
          controller: _controller,
          autofocus: true,
          maxLength: 48,
          textInputAction: TextInputAction.done,
          onSubmitted: _save,
        ),
        SizedBox(height: ls.space.xl),
        Row(
          children: [
            Expanded(
              child: LsButton.ghost(
                label: l10n.useDefaultName,
                expand: true,
                onPressed: () => _save(''),
              ),
            ),
            SizedBox(width: ls.space.md),
            Expanded(
              child: LsButton.primary(
                label: l10n.save,
                expand: true,
                onPressed: () => _save(_controller.text),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ForgetSheet extends ConsumerWidget {
  const _ForgetSheet({required this.device});

  final DeviceInfo device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ls = context.ls;
    final c = ls.colors;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.forgetTitle(device.name), style: ls.text.headline.copyWith(color: c.textPrimary)),
        SizedBox(height: ls.space.sm),
        Text(l10n.forgetBody, style: ls.text.body.copyWith(color: c.textSecondary)),
        SizedBox(height: ls.space.xl),
        Row(
          children: [
            Expanded(
              child: LsButton(
                label: l10n.cancel,
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: ls.space.md),
            Expanded(
              child: LsButton.danger(
                label: l10n.forget,
                expand: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(trustedDevicesProvider.notifier).forget(device);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
