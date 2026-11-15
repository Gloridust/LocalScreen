import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/app/theme/lumen.dart';
import 'package:localscreen/core/update/release.dart';
import 'package:localscreen/core/update/update_controller.dart';
import 'package:localscreen/core/update/update_installer.dart';
import 'package:localscreen/core/update/update_source.dart';
import 'package:localscreen/core/update/version.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

Future<void> _wait(WidgetTester tester, Duration d) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _newer = AppRelease(
  version: const AppVersion(0, 2, 0),
  page: Uri.parse('https://example.invalid/0.2.0'),
  publishedAt: DateTime(2026, 11, 16),
  notes: '## 更新内容\n- 重连更快\n- 弱网下画面更稳',
  assets: [
    ReleaseAsset(
      name: 'localscreen_0.2.0_amd64.deb',
      url: Uri.parse('https://example.invalid/pkg.deb'),
      size: 15900000,
    ),
  ],
);

const _soon = UpdateSchedule(firstCheck: Duration(milliseconds: 200));

void main() {
  testWidgets('home announces a new version; the sheet installs it', (tester) async {
    final installer = FakeUpdateInstaller();
    final node = await pumpApp(
      tester,
      size: desktopSize,
      updates: FakeUpdateSource(_newer),
      installer: installer,
      updateSchedule: _soon,
    );
    expect(find.textContaining('0.2.0'), findsNothing);
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('新版本 0.2.0 可用'), findsOneWidget);
    expect(find.text('当前 0.1.3'), findsOneWidget);

    await tester.tap(find.text('更新'));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('LocalScreen 0.2.0'), findsOneWidget);
    expect(find.text('重连更快'), findsOneWidget);
    expect(find.text('安装时会请你输入系统密码。'), findsOneWidget);

    await tester.tap(find.textContaining('下载并安装'));
    await _wait(tester, const Duration(seconds: 2));
    expect(installer.installed, hasLength(1));
    expect(find.text('重启'), findsWidgets);

    await tester.tap(find.text('重启').last);
    await _wait(tester, const Duration(milliseconds: 500));
    expect(installer.relaunches, 1);
    await disposeApp(tester, node);
  });

  testWidgets('skipping a version hides the banner for good', (tester) async {
    final node = await pumpApp(
      tester,
      updates: FakeUpdateSource(_newer),
      installer: FakeUpdateInstaller(),
      updateSchedule: _soon,
    );
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('新版本 0.2.0 可用'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('忽略此版本'));
    await _wait(tester, const Duration(milliseconds: 600));
    expect(find.text('新版本 0.2.0 可用'), findsNothing);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('ls.skippedUpdate'), '0.2.0');
    await disposeApp(tester, node);
  });

  testWidgets('where the app cannot install, the sheet leads to the download page', (tester) async {
    final installer = FakeUpdateInstaller(canInstallHere: false);
    final node = await pumpApp(
      tester,
      size: desktopSize,
      updates: FakeUpdateSource(_newer),
      installer: installer,
      updateSchedule: _soon,
    );
    await _wait(tester, const Duration(seconds: 1));
    await tester.tap(find.text('更新'));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.textContaining('下载并安装'), findsNothing);

    await tester.tap(find.text('前往下载页'));
    await _wait(tester, const Duration(milliseconds: 300));
    expect(installer.opened.single, _newer.page);
    expect(installer.installed, isEmpty);
    await disposeApp(tester, node);
  });

  testWidgets('settings: the switch is remembered and a check can be asked for', (tester) async {
    final source = FakeUpdateSource(
      AppRelease(version: testVersion, page: Uri.parse('https://example.invalid/same')),
    );
    final node = await pumpApp(
      tester,
      size: desktopSize,
      updates: source,
      installer: FakeUpdateInstaller(),
      prefs: {'ls.autoCheckUpdates': false},
    );
    await _wait(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('设置'));
    await _wait(tester, const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.text('立即检查'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('立即检查'));
    await _wait(tester, const Duration(milliseconds: 300));
    expect(find.text('尚未检查'), findsOneWidget);
    expect(source.checks, 0);

    final row = find.ancestor(of: find.text('自动检查更新'), matching: find.byType(Row)).first;
    final toggle = find.descendant(of: row, matching: find.byType(LsSwitch));
    expect(tester.widget<LsSwitch>(toggle).value, isFalse);

    await tester.tap(find.text('立即检查'));
    await _wait(tester, const Duration(seconds: 1));
    expect(source.checks, 1);
    expect(find.textContaining('已是最新版本'), findsOneWidget);

    await tester.tap(toggle);
    await _wait(tester, const Duration(milliseconds: 300));
    expect(tester.widget<LsSwitch>(toggle).value, isTrue);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getBool('ls.autoCheckUpdates'), isTrue);
    await disposeApp(tester, node);
  });

  testWidgets('without an update source the settings group is absent', (tester) async {
    final node = await pumpApp(tester, size: desktopSize);
    await _wait(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('设置'));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('自动检查更新'), findsNothing);
    await disposeApp(tester, node);
  });
}
