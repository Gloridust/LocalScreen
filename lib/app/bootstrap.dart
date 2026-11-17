import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log.dart';
import '../core/media/decode_load.dart';
import '../core/media/fake_media_session.dart';
import '../core/media/media_providers.dart';
import '../core/media/media_session.dart';
import '../core/media/screen_capture.dart';
import '../core/media/webrtc_media_session.dart';
import '../core/node/fake_node_service.dart';
import '../core/node/local_node.dart';
import '../core/node/node_service.dart';
import '../core/node/rust_node_service.dart';
import '../core/platform/autostart.dart';
import '../core/platform/device_profile.dart';
import '../core/platform/immersive.dart';
import '../core/platform/linux/mutter_monitor_capture.dart';
import '../core/platform/linux/mutter_virtual_display.dart';
import '../core/platform/virtual_display.dart';
import '../core/prefs/preferences.dart';
import '../core/update/release.dart';
import '../core/update/update_controller.dart';
import '../core/update/update_installer.dart';
import '../core/update/update_source.dart';
import '../core/update/version.dart';
import '../features/session/screen_source_picker.dart';
import 'app.dart';
import 'l10n.dart';
import 'window_frame.dart';

/// `--dart-define=LS_FAKE=true`: simulated network, no Rust core.
const fakeMode = bool.fromEnvironment('LS_FAKE');

/// With [fakeMode]: `pin` or `trusted` simulates an incoming request a few
/// seconds after launch.
const fakeIncoming = String.fromEnvironment('LS_FAKE_INCOMING');

/// Initialises platform services and runs the app.
Future<void> bootstrap(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final titleBar = await DesktopWindow.init(
    title: 'LocalScreen',
    args: args,
    minimized: args.contains(autostartFlag),
  );
  final prefs = await SharedPreferences.getInstance();
  final profile = await DeviceProfile.detect();
  final package = await PackageInfo.fromPlatform();
  if (!fakeMode) {
    await AppLog.start(
      '${profile.storageDir}${Platform.pathSeparator}logs',
      banner:
          'LocalScreen ${package.version}+${package.buildNumber} on ${profile.platform} '
          '(${Platform.operatingSystemVersion}), ${profile.kind.name}, '
          '${Platform.numberOfProcessors} cores, ${profile.memoryMb ?? '?'} MB RAM',
    );
  }
  final AutostartService autostart = fakeMode
      ? InMemoryAutostartService()
      : profile.isDesktop
      ? DesktopAutostartService()
      : const UnsupportedAutostartService();
  await reconcileAutostart(autostart, PreferencesStore(prefs));
  final version = AppVersion.tryParse(package.version);
  final updates = Directory(
    '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}localscreen-updates',
  );

  final NodeService node;
  final MediaEngine media;
  if (fakeMode) {
    final fake = FakeNodeService();
    node = fake;
    media = const FakeMediaEngine();
    _scheduleFakeIncoming(fake);
  } else {
    node = await RustNodeService.create();
    media = WebRtcMediaEngine(
      startingFramerateLimit: DecodeLoadMonitor.startingLimit(
        cores: Platform.numberOfProcessors,
        memoryMb: profile.memoryMb,
      ),
      capture: ScreenCapture(
        chooser: chooseScreenSource,
        direct: profile.platform == 'linux' ? const MutterMonitorCapture() : null,
        notificationText: () => _strings(prefs).captureNotificationText,
      ),
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceProfileProvider.overrideWithValue(profile),
        nodeServiceProvider.overrideWithValue(node),
        mediaEngineProvider.overrideWithValue(media),
        autostartServiceProvider.overrideWithValue(autostart),
        titleBarKindProvider.overrideWithValue(titleBar),
        if (!fakeMode && profile.platform == 'linux')
          virtualDisplayProvider.overrideWithValue(
            MutterVirtualDisplayProvider(placements: PreferencesPlacementStore(prefs)),
          ),
        appVersionProvider.overrideWithValue(version ?? AppVersion.unknown),
        updateDirectoryProvider.overrideWithValue(updates),
        ...switch ((fakeMode, version)) {
          (true, _) => [
            updateSourceProvider.overrideWithValue(FakeUpdateSource(_demoRelease)),
            updateInstallerProvider.overrideWithValue(FakeUpdateInstaller()),
          ],
          // Without a version there is nothing to compare against.
          (false, null) => const [],
          (false, _?) => [
            updateSourceProvider.overrideWithValue(GitHubUpdateSource()),
            updateInstallerProvider.overrideWithValue(
              UpdateInstaller.forPlatform(profile.platform),
            ),
          ],
        },
      ],
      child: const LocalScreenApp(),
    ),
  );
}

/// Localized strings for code that runs outside the widget tree.
AppLocalizations _strings(SharedPreferences prefs) {
  final chosen = PreferencesStore(prefs).load().locale;
  return lookupAppLocalizations(chosen ?? resolveAppLocale(PlatformDispatcher.instance.locales));
}

/// The release the `LS_FAKE` demo announces.
final _demoRelease = AppRelease(
  version: const AppVersion(9, 9, 0),
  page: Uri.parse('https://github.com/Gloridust/LocalScreen/releases'),
  publishedAt: DateTime(2026, 11, 16),
  notes: '''
## Changes
- Faster reconnects to trusted devices
- Smoother picture on busy Wi-Fi
''',
  assets: [
    ReleaseAsset(
      name: 'localscreen_9.9.0_amd64.deb',
      url: Uri.parse('https://example.invalid/localscreen_9.9.0_amd64.deb'),
      size: 15900000,
    ),
  ],
);

void _scheduleFakeIncoming(FakeNodeService fake) {
  if (fakeIncoming.isEmpty) return;
  Timer(const Duration(seconds: 4), () {
    fake.simulateIncomingRequest(
      from: fakeIncoming == 'trusted' ? FakeNodeService.demoPeers[1] : null,
      autoPairAfter: const Duration(seconds: 20),
    );
  });
}
