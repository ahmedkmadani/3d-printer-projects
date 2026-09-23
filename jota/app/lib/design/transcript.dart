// ============================================================================
//  Jota — a transcript, laid out to be read
//
//  Paragraphs at sentence ends (paragraphs.dart), a looser line height than
//  the prose role's, and a fold: past a couple of hundred words the first ten
//  lines show with a soft fade, and "Show more" opens the rest in place. A
//  short note is unchanged — one run of words, no link.
// ============================================================================
import 'package:flutter/material.dart';

import 'paragraphs.dart';
import 'script.dart';
import 'theme.dart';
import 'widgets.dart';

/// Words past which a transcript folds. About a minute of speech.
const int kFoldAfterWords = 120;

/// Lines shown while folded.
const int kFoldedLines = 10;

/// The transcript's own line height: the prose role reads at 1.6 for a
/// sentence; a page of it breathes at 1.5 with paragraph gaps doing the rest.
const double kTranscriptLineHeight = 1.5;

class JotaTranscript extends StatefulWidget {
  const JotaTranscript({super.key, required this.text});

  final String text;

  @override
  State<JotaTranscript> createState() => _JotaTranscriptState();
}

class _JotaTranscriptState extends State<JotaTranscript> {
  bool _expanded = false;

  @override
  void didUpdateWidget(JotaTranscript old) {
    super.didUpdateWidget(old);
    // New words (an edit, a second pass) start folded again.
    if (old.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final TextStyle style = t.prose.copyWith(height: kTranscriptLineHeight);
    final List<String> paragraphs = splitParagraphs(widget.text);
    final bool folds = wordCount(widget.text) > kFoldAfterWords;

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < paragraphs.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: JotaGrid.gapM),
          // NoteText per paragraph so an Arabic one keeps its direction and
          // face, and a mixed note can turn paragraph by paragraph.
          NoteText(paragraphs[i], style: style),
        ],
      ],
    );

    if (!folds) return body;

    final double lineHeight = (style.fontSize ?? 16) * kTranscriptLineHeight;
    final double foldedHeight = lineHeight * kFoldedLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnimatedSize(
          duration: JotaMotion.normal,
          curve: JotaMotion.curve,
          alignment: Alignment.topCenter,
          child: _expanded
              ? body
              : ClipRect(
                  child: SizedBox(
                    height: foldedHeight,
                    // The last two lines fade to the paper, so the cut reads
                    // as "there is more" rather than as a torn edge.
                    child: ShaderMask(
                      shaderCallback: (Rect r) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          c.ink,
                          c.ink,
                          c.ink.withValues(alpha: 0),
                        ],
                        stops: const <double>[0, 1 - 2 / kFoldedLines, 1],
                      ).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        maxHeight: double.infinity,
                        child: body,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: JotaGrid.gapS),
        Align(
          alignment: Alignment.centerLeft,
          child: JotaTextLink(
            label: _expanded ? 'Show less' : 'Show more',
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ),
      ],
    );
  }
}
