import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/app/window_frame.dart';
import 'package:localscreen/core/platform/immersive.dart';

import '../support/test_app.dart';

class _Controls implements WindowControls {
  final calls = <String>[];

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> toggleMaximize() async => calls.add('maximize');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> startDragging() async => calls.add('drag');
}

/// A title-bar button by its accessible name.
Finder _button(String label) => find.descendant(
  of: find.byType(TitleBar),
  matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label),
);

void main() {
  for (final kind in [TitleBarKind.windows, TitleBarKind.gnome]) {
    testWidgets('${kind.name}: the buttons drive the window', (tester) async {
      final controls = _Controls();
      final node = await pumpApp(
        tester,
        size: desktopSize,
        titleBar: kind,
        windowControls: controls,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getSize(find.byType(TitleBar)).height, TitleBar.heightFor(kind));

      for (final (label, call) in [('最小化', 'minimize'), ('最大化', 'maximize'), ('关闭', 'close')]) {
        await tester.tap(_button(label));
        await tester.pump();
        expect(controls.calls.last, call);
      }

      // The empty part of the bar moves the window; a double click maximizes.
      final strip = tester.getTopLeft(find.byType(TitleBar)) + const Offset(200, 10);
      await tester.dragFrom(strip, const Offset(40, 20));
      await tester.pump();
      expect(controls.calls.last, 'drag');
      await tester.tapAt(strip);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(strip);
      await tester.pump(const Duration(milliseconds: 400));
      expect(controls.calls.last, 'maximize');
      await disposeApp(tester, node);
    });
  }

  testWidgets('macOS keeps its own buttons and only leaves them room', (tester) async {
    final node = await pumpApp(tester, size: desktopSize, titleBar: TitleBarKind.macos);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TitleBar), findsOneWidget);
    expect(_button('关闭'), findsNothing);
    await disposeApp(tester, node);
  });

  testWidgets('where the system draws the title bar the app does not', (tester) async {
    final node = await pumpApp(tester, size: desktopSize);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TitleBar), findsNothing);
    expect(find.byType(MaterialApp), findsOneWidget);
    await disposeApp(tester, node);
  });
}
