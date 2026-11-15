import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/app/theme/lumen.dart';
import 'package:localscreen/core/platform/autostart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

Future<void> _wait(WidgetTester tester, Duration d) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('launch-at-startup switch updates the OS entry and the preference', (tester) async {
    final autostart = InMemoryAutostartService();
    final node = await pumpApp(tester, size: desktopSize, autostart: autostart);
    await _wait(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('设置'));
    await _wait(tester, const Duration(seconds: 1));

    final row = find.ancestor(of: find.text('开机自启'), matching: find.byType(Row)).first;
    final toggle = find.descendant(of: row, matching: find.byType(LsSwitch));
    expect(tester.widget<LsSwitch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await _wait(tester, const Duration(milliseconds: 300));
    expect(autostart.enabled, isTrue);
    expect(tester.widget<LsSwitch>(toggle).value, isTrue);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getBool('ls.launchAtStartup'), isTrue);

    await tester.tap(toggle);
    await _wait(tester, const Duration(milliseconds: 300));
    expect(autostart.enabled, isFalse);
    await disposeApp(tester, node);
  });

  testWidgets('the switch is hidden where autostart does not apply', (tester) async {
    final node = await pumpApp(
      tester,
      size: desktopSize,
      autostart: const UnsupportedAutostartService(),
    );
    await _wait(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('设置'));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('开机自启'), findsNothing);
    expect(find.text('设备名称'), findsOneWidget);
    await disposeApp(tester, node);
  });

  testWidgets('forgetting a trusted device asks first, then removes it', (tester) async {
    final node = await pumpApp(tester, size: desktopSize);
    await _wait(tester, const Duration(seconds: 1));
    await tester.tap(find.text('设置'));
    await _wait(tester, const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.text('移除'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('移除'));
    await _wait(tester, const Duration(milliseconds: 500));
    expect(find.text('移除 Surface Go 3？'), findsOneWidget);
    await tester.tap(find.widgetWithText(LsButton, '移除').last);
    await _wait(tester, const Duration(milliseconds: 500));
    expect(find.text('Surface Go 3'), findsNothing);
    expect(await node.listTrusted(), isEmpty);
    await disposeApp(tester, node);
  });
}
