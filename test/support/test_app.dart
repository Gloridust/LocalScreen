import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/app/app.dart';
import 'package:localscreen/core/media/fake_media_session.dart';
import 'package:localscreen/core/media/media_providers.dart';
import 'package:localscreen/core/node/fake_node_service.dart';
import 'package:localscreen/core/node/local_node.dart';
import 'package:localscreen/core/node/node_service.dart';
import 'package:localscreen/core/platform/autostart.dart';
import 'package:localscreen/core/platform/device_profile.dart';
import 'package:localscreen/core/prefs/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phone portrait.
const phoneSize = Size(390, 844);

/// Desktop window.
const desktopSize = Size(1280, 800);

/// Tablet landscape.
const tabletSize = Size(1180, 820);

/// Profile of the device under test.
const testProfile = DeviceProfile(
  defaultName: 'ThinkPad X1',
  kind: DeviceKind.laptop,
  platform: 'linux',
  storageDir: '/tmp/localscreen-test',
);

/// Pumps the whole app on a [FakeNodeService] and returns the service.
///
/// Animations are disabled through the accessibility features so ambient
/// loops stop; the fake network still runs on (fake-async) timers.
Future<FakeNodeService> pumpApp(
  WidgetTester tester, {
  Size size = phoneSize,
  double pixelRatio = 1,
  Map<String, Object> prefs = const {},
  FakeNodeService? node,
  bool reduceMotion = true,
  AutostartService? autostart,
}) async {
  SharedPreferences.setMockInitialValues({'ls.locale': 'zh', ...prefs});
  final sp = await SharedPreferences.getInstance();
  final service = node ?? FakeNodeService(discoveryInterval: const Duration(milliseconds: 100));
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  }
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        deviceProfileProvider.overrideWithValue(testProfile),
        nodeServiceProvider.overrideWithValue(service),
        autostartServiceProvider.overrideWithValue(autostart ?? InMemoryAutostartService()),
        mediaEngineProvider.overrideWithValue(
          const FakeMediaEngine(connectDelay: Duration(milliseconds: 50)),
        ),
      ],
      child: const LocalScreenApp(),
    ),
  );
  await tester.pump();
  return service;
}

/// Unmounts the app and stops the fake network so no timer outlives a test.
Future<void> disposeApp(WidgetTester tester, FakeNodeService service) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await service.dispose();
  await tester.pump(const Duration(seconds: 5));
}

bool _fontsLoaded = false;

/// Loads real fonts (system Noto Sans CJK + Material Icons) for goldens.
/// Returns false when they are not installed on this machine.
Future<bool> loadRealFonts() async {
  if (_fontsLoaded) return true;
  const cjk = [
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
  ];
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = flutterRoot == null
      ? null
      : File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!cjk.every((p) => File(p).existsSync()) || icons == null || !icons.existsSync()) return false;
  ByteData bytes(File f) => ByteData.sublistView(f.readAsBytesSync());
  // The app asks for Inter first; on this machine (as in tests) the system
  // CJK face stands in for it, exactly like the fallback chain does at runtime.
  for (final family in ['Inter', 'Noto Sans CJK SC']) {
    final loader = FontLoader(family);
    for (final p in cjk) {
      loader.addFont(Future.value(bytes(File(p))));
    }
    await loader.load();
  }
  final material = FontLoader('MaterialIcons')..addFont(Future.value(bytes(icons)));
  await material.load();
  _fontsLoaded = true;
  return true;
}
