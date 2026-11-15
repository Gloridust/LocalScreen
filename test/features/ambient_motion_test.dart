import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/app/motion_gate.dart';
import 'package:localscreen/app/theme/lumen.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildLsTheme(LsTokens.dark),
  home: MotionGate(child: Center(child: child)),
);

void main() {
  const cycle = Duration(milliseconds: 2400);

  testWidgets('ripples play a few cycles and then leave the window idle', (tester) async {
    await tester.pumpWidget(_host(const LsRipples(coreSize: 40, color: Colors.white)));
    await tester.pump(cycle);
    expect(tester.binding.hasScheduledFrame, isTrue, reason: 'still inside the burst');

    await tester.pump(cycle * const LsMotion().ambientCycles);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'an idle screen keeps redrawing');

    // Something worth a glance happens: one more burst, then rest again.
    LsAmbient.pulse();
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(cycle * (const LsMotion().ambientCycles + 1));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('continuous ripples keep going; inactive ones never start', (tester) async {
    await tester.pumpWidget(
      _host(const LsRipples(coreSize: 40, color: Colors.white, continuous: true)),
    );
    await tester.pump(cycle * 10);
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(
      _host(const LsRipples(coreSize: 40, color: Colors.white, active: false)),
    );
    await tester.pump(const Duration(seconds: 1));
    LsAmbient.pulse();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('nothing animates while the app is hidden', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    await tester.pumpWidget(
      _host(const LsRipples(coreSize: 40, color: Colors.white, continuous: true)),
    );
    await tester.pump(cycle);
    expect(tester.binding.hasScheduledFrame, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);

    // A window that only lost focus is still on screen and keeps moving.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });
}
