// Direction and face for a note's own words.
//
// The rule under test (docs/brand.md): only the note's WORDS flip. Everything
// around them — dates, tags, buttons — follows the app language.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/design/script.dart';
import 'package:jota/design/theme.dart';

void main() {
  group('isRtlText', () {
    test('plain English is left to right', () {
      expect(isRtlText('Saying yes before I think. Again.'), isFalse);
      expect(isRtlText(''), isFalse);
      expect(isRtlText('00:47 · N-012'), isFalse);
    });

    test('Arabic is right to left', () {
      expect(isRtlText('الحدود مع العائلة'), isTrue);
      expect(isRtlText('نفس الكلام الرجعت ليهو تاني'), isTrue);
    });

    test('code-switching is decided by which script dominates', () {
      // The failure this guards against: a first-strong-character check reads
      // the leading English word and lays the whole line out left to right,
      // which is exactly how this user speaks — English opener, Arabic body.
      expect(isRtlText('okay so الحدود مع العائلة نفس الكلام تاني'), isTrue);
      // ...and the mirror case still reads as English.
      expect(
        isRtlText('I told him الحدود and then we moved on to the next thing'),
        isFalse,
      );
    });

    test('digits and punctuation do not vote', () {
      // One Arabic word with a pile of figures after it is still Arabic.
      expect(isRtlText('الشغل 2026 — 04:12, 003/005'), isTrue);
    });
  });

  group('styleForText', () {
    const TextStyle base = TextStyle(fontFamily: JotaFonts.sans, height: 1.4);

    test('leaves Latin text on the Latin face', () {
      expect(styleForText(base, 'hello').fontFamily, JotaFonts.sans);
    });

    test('moves Arabic text to the Arabic face', () {
      // Plex Sans carries no Arabic glyphs at all, so without this the text
      // falls through to whatever face the phone happens to have.
      final TextStyle s = styleForText(base, 'الحدود مع العائلة');
      expect(s.fontFamily, JotaFonts.arabic);
      expect(s.fontFamilyFallback, JotaFonts.arabicFallback);
      expect(s.height, greaterThan(base.height!));
    });
  });

  testWidgets('NoteText sets direction per note, not per screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr, // an English app…
        child: Column(
          children: <Widget>[
            NoteText('الحدود مع العائلة', style: TextStyle()),
            NoteText('Boundaries with family', style: TextStyle()),
          ],
        ),
      ),
    );

    final List<Text> texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts, hasLength(2));
    // …holding one Arabic note that flips, and one English note that does not.
    expect(texts[0].textDirection, TextDirection.rtl);
    expect(texts[1].textDirection, TextDirection.ltr);
  });
}
