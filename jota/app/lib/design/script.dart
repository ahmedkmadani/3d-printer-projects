// ============================================================================
//  Jota — script direction for note text
//
//  Roughly half of what gets recorded is Arabic, so a note's own words may run
//  right to left while the app around them runs left to right.
//
//  THE RULE (docs/brand.md): only the note's WORDS flip. Dates, tags, buttons
//  and every other piece of chrome follow the APP language, not the note's. So
//  an Arabic note inside an English app keeps an English date on the left and
//  its tag where every other row has one. Switch the app to Arabic and the
//  chrome flips too — the note never decides that.
//
//  This is why direction is decided per Text widget and never by wrapping a
//  row in a Directionality: wrapping the row would drag the date and tag along
//  with it, and the list would stop being scannable the moment one note was in
//  the other language.
// ============================================================================
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Unicode blocks that mean "this is Arabic script".
///
/// Arabic (0600–06FF) and Arabic Supplement (0750–077F) cover everything
/// written here; the presentation forms (FB50–FDFF, FE70–FEFF) appear in text
/// pasted from older systems and are cheap to include.
bool _isArabicRune(int r) =>
    (r >= 0x0600 && r <= 0x06FF) ||
    (r >= 0x0750 && r <= 0x077F) ||
    (r >= 0xFB50 && r <= 0xFDFF) ||
    (r >= 0xFE70 && r <= 0xFEFF);

/// Latin letters, so a mixed sentence can be weighed rather than merely
/// sniffed. Digits and punctuation are deliberately NOT counted: they are
/// script-neutral and a note that is one Arabic word and three numbers is
/// still an Arabic note.
bool _isLatinRune(int r) =>
    (r >= 0x0041 && r <= 0x005A) || (r >= 0x0061 && r <= 0x007A);

/// Whether [text] should be laid out right to left.
///
/// Decided by WHICH SCRIPT DOMINATES, not by the first strong character.
/// First-strong is what `Directionality` and most naive checks use, and it
/// gets a code-switched sentence wrong every time: someone opening in English
/// and finishing in Arabic — which is exactly how this user speaks — would
/// have the whole paragraph laid out left to right with the Arabic half
/// running backwards off the wrong edge.
bool isRtlText(String text) {
  int arabic = 0;
  int latin = 0;
  for (final int r in text.runes) {
    if (_isArabicRune(r)) {
      arabic++;
    } else if (_isLatinRune(r)) {
      latin++;
    }
  }
  if (arabic == 0) return false;
  return arabic >= latin;
}

/// The same style, switched to the Arabic face when [text] needs it.
///
/// Applied per string rather than per screen because a single list holds both
/// languages, and because the Latin faces carry NO Arabic glyphs at all — an
/// Arabic note in Plex Sans falls through to whatever the phone happens to
/// have, which is a different design on every handset.
TextStyle styleForText(TextStyle base, String text) {
  if (!isRtlText(text)) return base;
  return base.copyWith(
    fontFamily: JotaFonts.arabic,
    fontFamilyFallback: JotaFonts.arabicFallback,
    // Arabic sits taller and needs the extra room; at the Latin line height
    // the dots below ba/ya collide with the line beneath.
    height: (base.height ?? 1.4) * 1.18,
  );
}

/// A note's own words: correct face, correct direction, correct alignment.
///
/// Use this for transcripts and summaries only. Never for a date, a tag, a
/// duration or a button — those are chrome and follow the app.
class NoteText extends StatelessWidget {
  const NoteText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final bool rtl = isRtlText(text);
    return Text(
      text,
      style: styleForText(style, text),
      maxLines: maxLines,
      overflow: overflow,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      // start, not left/right: it resolves against the textDirection above, so
      // each note aligns to its own reading edge without the caller caring.
      textAlign: TextAlign.start,
    );
  }
}
