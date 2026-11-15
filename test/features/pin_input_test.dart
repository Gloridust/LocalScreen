import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/app/theme/lumen.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildLsTheme(LsTokens.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 360, child: child)),
  ),
);

void main() {
  testWidgets('accepts digits only and completes after six', (tester) async {
    String? completed;
    await tester.pumpWidget(_host(LsPinInput(onCompleted: (v) => completed = v)));
    await tester.enterText(find.byType(EditableText), '4a8-2');
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(completed, isNull);

    await tester.enterText(find.byType(EditableText), '4829137');
    await tester.pump();
    expect(completed, '482913');
    expect(find.text('7'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a new shake signal clears the cells', (tester) async {
    var signal = 0;
    late StateSetter set;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return LsPinInput(onCompleted: (_) {}, shakeSignal: signal);
          },
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), '123');
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    set(() => signal++);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);
  });
}
