import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../core/platform/mutter_virtual_display.dart';
import '../core/platform/virtual_display.dart';
import '../core/prefs/preferences.dart';
import '../features/session/screen_source_picker.dart';
import 'app.dart';
import 'l10n.dart';

/// `--dart-define=LS_FAKE=true`: simulated network, no Rust core.
const fakeMode = bool.fromEnvironment('LS_FAKE');

/// With [fakeMode]: `pin` or `trusted` simulates an incoming request a few
/// seconds after launch.
const fakeIncoming = String.fromEnvironment('LS_FAKE_INCOMING');

/// Initialises platform services and runs the app.
Future<void> bootstrap(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await DesktopWindow.init(title: 'LocalScreen', minimized: args.contains(autostartFlag));
  final prefs = await SharedPreferences.getInstance();
  final profile = await DeviceProfile.detect();
  final AutostartService autostart = fakeMode
      ? InMemoryAutostartService()
      : profile.isDesktop
      ? DesktopAutostartService()
      : const UnsupportedAutostartService();
  await reconcileAutostart(autostart, PreferencesStore(prefs));

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
      capture: ScreenCapture(
        chooser: chooseScreenSource,
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
        if (!fakeMode && profile.platform == 'linux')
          virtualDisplayProvider.overrideWithValue(MutterVirtualDisplayProvider()),
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

void _scheduleFakeIncoming(FakeNodeService fake) {
  if (fakeIncoming.isEmpty) return;
  Timer(const Duration(seconds: 4), () {
    fake.simulateIncomingRequest(
      from: fakeIncoming == 'trusted' ? FakeNodeService.demoPeers[1] : null,
      autoPairAfter: const Duration(seconds: 20),
    );
  });
}
