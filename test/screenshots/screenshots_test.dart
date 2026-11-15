// Renders the key screens with real fonts into docs/screenshots/.
//
// Skipped during normal runs (fonts differ between machines); regenerate with
//   flutter test --update-goldens test/screenshots
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/node/fake_node_service.dart';

import '../support/test_app.dart';

const _out = '../../docs/screenshots';

/// flutter_test draws shadows as hard shapes by default; screenshots should
/// look like the app. Must be restored before the test body ends.
void _realShadows(bool on) => debugDisableShadows = !on;

Future<void> _settle(WidgetTester tester, [Duration d = const Duration(seconds: 2)]) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, Object> _prefs({required String theme, String locale = 'zh'}) => {
  'ls.themeMode': theme,
  'ls.locale': locale,
};

void main() {
  final skip = !autoUpdateGoldenFiles;

  Future<FakeNodeService> boot(
    WidgetTester tester,
    Size size,
    String theme, {
    String locale = 'zh',
  }) async {
    expect(await loadRealFonts(), isTrue, reason: 'Noto Sans CJK and Material Icons are required');
    _realShadows(true);
    final node = await pumpApp(
      tester,
      size: size,
      pixelRatio: 2,
      reduceMotion: false,
      prefs: _prefs(theme: theme, locale: locale),
    );
    await _settle(tester);
    return node;
  }

  testWidgets('home · expanded · dark', skip: skip, (tester) async {
    final node = await boot(tester, desktopSize, 'dark');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/home_expanded_dark.png'));
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('home · compact · light', skip: skip, (tester) async {
    final node = await boot(tester, phoneSize, 'light');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/home_compact_light.png'));
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('home · compact · dark · searching', skip: skip, (tester) async {
    expect(await loadRealFonts(), isTrue);
    _realShadows(true);
    final node = await pumpApp(
      tester,
      pixelRatio: 2,
      reduceMotion: false,
      prefs: _prefs(theme: 'dark'),
      node: FakeNodeService(peers: const []),
    );
    await _settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/home_compact_dark_empty.png'),
    );
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('connect sheet · options · compact dark', skip: skip, (tester) async {
    final node = await boot(tester, phoneSize, 'dark');
    await tester.tap(find.text('MacBook Air'));
    await _settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('扩展'));
    await _settle(tester, const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/connect_options_compact_dark.png'),
    );
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('connect sheet · PIN entry · expanded dark', skip: skip, (tester) async {
    final node = await boot(tester, desktopSize, 'dark');
    await tester.tap(find.text('小米平板 6 Pro'));
    await _settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('开始投屏'));
    await _settle(tester, const Duration(seconds: 1));
    await tester.enterText(find.byType(EditableText), '000000');
    await _settle(tester, const Duration(seconds: 1));
    await tester.enterText(find.byType(EditableText), '482');
    await _settle(tester, const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/connect_pin_expanded_dark.png'),
    );
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('incoming request · PIN · tablet dark', skip: skip, (tester) async {
    final node = await boot(tester, tabletSize, 'dark');
    node.simulateIncomingRequest();
    await _settle(tester, const Duration(seconds: 3));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/incoming_pin_tablet_dark.png'),
    );
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('incoming request · trusted · compact light', skip: skip, (tester) async {
    final node = await boot(tester, phoneSize, 'light');
    node.simulateIncomingRequest(withPin: false, from: FakeNodeService.demoPeers[1]);
    await _settle(tester, const Duration(seconds: 1));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/incoming_trusted_compact_light.png'),
    );
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('host console · expanded dark', skip: skip, (tester) async {
    final node = await boot(tester, desktopSize, 'dark');
    await tester.tap(find.text('Surface Go 3'));
    await _settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('开始投屏'));
    await _settle(tester, const Duration(seconds: 4));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/host_console_expanded_dark.png'),
    );
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('display session · tablet', skip: skip, (tester) async {
    final node = await boot(tester, tabletSize, 'dark');
    node.simulateIncomingRequest(withPin: false, from: FakeNodeService.demoPeers[1]);
    await _settle(tester, const Duration(seconds: 1));
    await tester.tap(find.text('接受'));
    await _settle(tester, const Duration(milliseconds: 1500));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/display_session_tablet.png'),
    );
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('settings · expanded dark', skip: skip, (tester) async {
    final node = await boot(tester, desktopSize, 'dark');
    await tester.tap(find.text('设置'));
    await _settle(tester, const Duration(seconds: 1));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/settings_expanded_dark.png'),
    );
    await disposeApp(tester, node);
    _realShadows(false);
  });

  testWidgets('settings · compact light · English', skip: skip, (tester) async {
    final node = await boot(tester, phoneSize, 'light', locale: 'en');
    await tester.tap(
      find.byTooltip('Settings').hitTestable().evaluate().isEmpty
          ? find.bySemanticsLabel('Settings').first
          : find.byTooltip('Settings'),
    );
    await _settle(tester, const Duration(seconds: 1));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$_out/settings_compact_light_en.png'),
    );
    await disposeApp(tester, node);
    _realShadows(false);
  });
}
