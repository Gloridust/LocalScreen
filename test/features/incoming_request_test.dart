import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/app/theme/lumen.dart';
import 'package:localscreen/core/node/fake_node_service.dart';
import 'package:localscreen/features/pairing/incoming_request_overlay.dart';
import 'package:localscreen/features/session/display_session_screen.dart';

import '../support/test_app.dart';

Future<void> _wait(WidgetTester tester, Duration d) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('untrusted host: the PIN is shown, grouped, with a countdown', (tester) async {
    final node = await pumpApp(tester);
    await _wait(tester, const Duration(seconds: 1));
    node.simulateIncomingRequest();
    await _wait(tester, const Duration(milliseconds: 500));

    expect(find.byType(IncomingRequestCard), findsOneWidget);
    expect(find.textContaining('Ubuntu 工作站', findRichText: true), findsWidgets);
    expect(find.text('482'), findsOneWidget);
    expect(find.text('913'), findsOneWidget);
    expect(find.byType(LsCountdownRing), findsOneWidget);
    expect(find.text('接受'), findsNothing);

    await tester.tap(find.text('拒绝'));
    await _wait(tester, const Duration(milliseconds: 500));
    expect(find.byType(IncomingRequestCard), findsNothing);
    await disposeApp(tester, node);
  });

  testWidgets('trusted host: Accept starts the immersive display session', (tester) async {
    final node = await pumpApp(tester, size: tabletSize);
    await _wait(tester, const Duration(seconds: 1));
    node.simulateIncomingRequest(withPin: false, from: FakeNodeService.demoPeers[1]);
    await _wait(tester, const Duration(milliseconds: 500));

    expect(find.text('482'), findsNothing);
    await tester.tap(find.text('接受'));
    await _wait(tester, const Duration(seconds: 2));

    expect(node.acceptedRequests, 1);
    expect(find.byType(IncomingRequestCard), findsNothing);
    expect(find.byType(DisplaySessionScreen), findsOneWidget);
    expect(find.text('Surface Go 3'), findsWidgets);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.byType(DisplaySessionScreen), findsNothing);
    await disposeApp(tester, node);
  });

  testWidgets('auto-accept skips the card for trusted hosts', (tester) async {
    final node = await pumpApp(tester, prefs: {'ls.autoAcceptTrusted': true});
    await _wait(tester, const Duration(seconds: 1));
    node.simulateIncomingRequest(withPin: false, from: FakeNodeService.demoPeers[1]);
    await _wait(tester, const Duration(milliseconds: 100));
    expect(find.byType(IncomingRequestCard), findsNothing);
    await _wait(tester, const Duration(seconds: 2));
    expect(node.acceptedRequests, 1);
    expect(find.byType(DisplaySessionScreen), findsOneWidget);
    await disposeApp(tester, node);
  });

  testWidgets('the host hanging up closes the display and says so', (tester) async {
    final node = await pumpApp(tester, size: tabletSize);
    await _wait(tester, const Duration(seconds: 1));
    final id = node.simulateIncomingRequest(withPin: false, from: FakeNodeService.demoPeers[1]);
    await _wait(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('接受'));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.byType(DisplaySessionScreen), findsOneWidget);

    node.simulateRemoteHangup(id);
    await _wait(tester, const Duration(seconds: 1));
    expect(find.byType(DisplaySessionScreen), findsNothing);
    expect(find.text('Surface Go 3 结束了投屏。'), findsOneWidget);
    await _wait(tester, const Duration(seconds: 4));
    await disposeApp(tester, node);
  });
}
