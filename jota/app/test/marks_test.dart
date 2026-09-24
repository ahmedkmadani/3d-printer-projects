// The marks, rendered: the full mark at splash size and part-drawn, and the
// four empty-state marks. The goldens under test/goldens are the reference
// renders; `flutter test --update-goldens` refreshes them after a deliberate
// change, and a diff in review is how a wrong number in marks.dart is caught.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/design/marks.dart';
import 'package:jota/design/theme.dart';

Widget _sheet() {
  return MaterialApp(
    theme: JotaTheme.light(),
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                JotaMark(size: 132),
                SizedBox(width: 24),
                JotaMark(size: 132, progress: 0.45),
                SizedBox(width: 24),
                JotaMark(size: 132, progress: 0.75),
                SizedBox(width: 24),
                JotaMark(size: 40),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final EmptyMark k in EmptyMark.values) ...<Widget>[
                  JotaEmptyMarkView(k),
                  const SizedBox(width: 24),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the marks render as their goldens', (WidgetTester tester) async {
    await tester.pumpWidget(_sheet());
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/marks.png'),
    );
  });

  test('no two thoughts share a height, and none mirror', () {
    // The face rule from marks.dart, as a test: tidying the numbers into
    // anything symmetrical brings the face straight back.
    final List<double> ys = kThoughts.map((Thought t) => t.y).toList();
    expect(ys.toSet().length, ys.length);
    for (final Thought a in kThoughts) {
      for (final Thought b in kThoughts) {
        if (identical(a, b)) continue;
        final bool mirrored = (a.y - b.y).abs() < 0.01 &&
            ((a.x - 0.5) + (b.x - 0.5)).abs() < 0.01;
        expect(mirrored, isFalse);
      }
    }
  });
}
