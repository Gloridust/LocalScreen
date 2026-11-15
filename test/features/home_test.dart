import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/app/theme/lumen.dart';
import 'package:localscreen/core/node/fake_node_service.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('home shows the empty state, then nearby peers as they appear', (tester) async {
    final node = await pumpApp(tester);
    expect(find.text('ThinkPad X1'), findsOneWidget);
    expect(find.text('正在寻找附近的设备…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('小米平板 6 Pro'), findsOneWidget);
    expect(find.text('Pixel 8'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    for (final p in FakeNodeService.demoPeers) {
      expect(find.text(p.name), findsOneWidget);
    }
    expect(find.text('正在寻找附近的设备…'), findsNothing);
    expect(find.text('Android · 192.168.1.42'), findsOneWidget);
    // Only Surface Go 3 is trusted in the demo network.
    expect(find.byType(LsTrustedMark), findsOneWidget);
    expect(find.text('4 台'), findsOneWidget);
    await disposeApp(tester, node);
  });

  testWidgets('expanded layout shows the local panel beside the grid', (tester) async {
    final node = await pumpApp(tester, size: desktopSize);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('这台设备'), findsOneWidget);
    expect(find.text('允许附近设备发现'), findsOneWidget);
    expect(find.byType(LsOrb), findsOneWidget);
    expect(find.text('Surface Go 3'), findsOneWidget);
    await disposeApp(tester, node);
  });

  testWidgets('manual IP connect opens the connect sheet for the probed device', (tester) async {
    final node = await pumpApp(tester, node: FakeNodeService(peers: const []));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('手动输入 IP'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), '10.0.0.7');
    await tester.pump();
    await tester.tap(find.text('连接'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('LocalScreen @ 10.0.0.7'), findsWidgets);
    expect(find.text('开始投屏'), findsOneWidget);
    await disposeApp(tester, node);
  });
}
