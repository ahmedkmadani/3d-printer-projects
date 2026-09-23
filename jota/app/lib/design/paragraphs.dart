// ============================================================================
//  Jota — paragraphs
//
//  A minute of speech is a few hundred words in one breath. Whisper hands it
//  over as a single run; read on a phone that is a wall. This cuts the run at
//  sentence ends into paragraphs of a few sentences each, so a long note
//  reads like writing. Pure: strings in, strings out, so it is testable and
//  the screen only lays out what it is given.
// ============================================================================

/// Sentence ends in the scripts Jota reads: Latin ., ?, !, the Arabic
/// question mark and the Urdu/Arabic full stop.
final RegExp _sentenceEnd = RegExp(r'(?<=[.!?؟۔])\s+');

/// Words, for the fold threshold and the details card: runs of non-space.
int wordCount(String text) {
  final String t = text.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

/// Split [text] into paragraphs at sentence ends, closing a paragraph after
/// [maxSentences] sentences or once it holds about [maxWords] words. A note of
/// one or two sentences comes back as it was.
List<String> splitParagraphs(
  String text, {
  int maxSentences = 4,
  int maxWords = 60,
}) {
  final String t = text.trim();
  if (t.isEmpty) return const <String>[];
  final List<String> sentences = t
      .split(_sentenceEnd)
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList();
  if (sentences.length <= 2) return <String>[t];

  final List<String> out = <String>[];
  final List<String> current = <String>[];
  int words = 0;
  for (final String s in sentences) {
    final int w = wordCount(s);
    // Close the paragraph before a sentence that would push it past the
    // word budget, unless it is empty — a single long sentence still needs
    // a home.
    if (current.isNotEmpty &&
        (current.length >= maxSentences || words + w > maxWords)) {
      out.add(current.join(' '));
      current.clear();
      words = 0;
    }
    current.add(s);
    words += w;
  }
  if (current.isNotEmpty) out.add(current.join(' '));
  return out;
}
