import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/media/signalling.dart';
import 'package:localscreen/core/node/fake_node_service.dart';
import 'package:localscreen/features/session/host_session_screen.dart';

import '../support/test_app.dart';

Future<void> _wait(WidgetTester tester, Duration d) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('untrusted peer: PIN entry in place, wrong PIN shakes, right PIN starts casting', (
    tester,
  ) async {
    final node = await pumpApp(tester);
    await _wait(tester, const Duration(seconds: 1));
    await tester.tap(find.text('小米平板 6 Pro'));
    await _wait(tester, const Duration(milliseconds: 500));

    // Extend is selectable but explained.
    await tester.tap(find.text('扩展'));
    await tester.pump();
    expect(find.text('扩展屏即将支持，本次将以镜像方式投屏。'), findsOneWidget);

    await tester.tap(find.text('开始投屏'));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('输入 PIN'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '000000');
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('PIN 不正确，还可以再试 4 次。'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), FakeNodeService.demoPin);
    await _wait(tester, const Duration(seconds: 2));
    expect(find.byType(HostSessionScreen), findsOneWidget);
    expect(find.text('投屏中'), findsOneWidget);

    // Switching quality live reaches the display as a control message.
    await tester.tap(find.text('清晰'));
    await tester.pump();
    expect(
      node.sentSignals.map(SignalMessage.decode),
      contains(const ControlSignal(action: ControlSignal.quality, value: 'clear')),
    );

    await tester.tap(find.text('停止投屏'));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.byType(HostSessionScreen), findsNothing);
    expect(find.text('投屏已结束。'), findsOneWidget);
    await _wait(tester, const Duration(seconds: 4));
    await disposeApp(tester, node);
  });

  testWidgets('cancelling the sheet while waiting cancels the request', (tester) async {
    final node = await pumpApp(tester, size: desktopSize);
    await _wait(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Pixel 8'));
    await _wait(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('开始投屏'));
    await _wait(tester, const Duration(seconds: 1));
    await tester.tap(find.text('取消'));
    await _wait(tester, const Duration(milliseconds: 500));
    expect(find.text('输入 PIN'), findsNothing);
    expect(find.byType(HostSessionScreen), findsNothing);
    await disposeApp(tester, node);
  });
}
