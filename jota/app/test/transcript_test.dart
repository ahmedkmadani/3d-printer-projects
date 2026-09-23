import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/design/theme.dart';
import 'package:jota/design/transcript.dart';

Widget _host(String text) => MaterialApp(
      theme: JotaTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: JotaTranscript(text: text),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a short note does not fold', (WidgetTester tester) async {
    final String text = List<String>.filled(72, 'word').join(' ');
    await tester.pumpWidget(_host('$text.'));
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('a long note folds, expands and collapses',
      (WidgetTester tester) async {
    final String sentence = List<String>.filled(15, 'word').join(' ');
    final String text = List<String>.filled(20, '$sentence.').join(' ');
    await tester.pumpWidget(_host(text));
    expect(find.text('Show more'), findsOneWidget);

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(find.text('Show more'), findsNothing);

    // The opened text pushes the link below the test viewport.
    await tester.ensureVisible(find.text('Show less'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('Show more'), findsOneWidget);
  });
}
