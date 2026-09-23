import 'package:flutter_test/flutter_test.dart';
import 'package:jota/design/paragraphs.dart';

void main() {
  test('one or two sentences come back untouched', () {
    expect(splitParagraphs('Hello there.'), <String>['Hello there.']);
    expect(
      splitParagraphs('One thing. Then another?'),
      <String>['One thing. Then another?'],
    );
  });

  test('a run of sentences closes a paragraph every four', () {
    final String text = List<String>.generate(9, (int i) => 'S$i.').join(' ');
    final List<String> p = splitParagraphs(text);
    expect(p.length, 3);
    expect(p.first, 'S0. S1. S2. S3.');
    expect(p.last, 'S8.');
  });

  test('a paragraph closes early when the word budget is spent', () {
    final String long = List<String>.filled(40, 'word').join(' ');
    final String text = '$long. $long. $long.';
    final List<String> p = splitParagraphs(text, maxWords: 60);
    // 40 + 40 would pass 60, so every sentence stands alone.
    expect(p.length, 3);
  });

  test('Arabic sentence ends count', () {
    final List<String> p =
        splitParagraphs('هل سمعت؟ نعم سمعت. حسناً. ثم ماذا؟ لا شيء.');
    expect(p.length, 2);
    expect(p.first, 'هل سمعت؟ نعم سمعت. حسناً. ثم ماذا؟');
  });

  test('wordCount counts runs of non-space', () {
    expect(wordCount(''), 0);
    expect(wordCount('  a  b   c '), 3);
    expect(wordCount('السلام عليكم'), 2);
  });
}
