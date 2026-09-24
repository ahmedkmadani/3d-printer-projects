// ============================================================================
//  Jota — what keeps coming back, in full
//
//  Reached from Home, never from the nav. It answers a question you ask
//  occasionally, and a destination you visit occasionally should not spend a
//  third of the bottom bar.
//
//  Each topic gets its count, and how many of those were this week, so "this
//  is getting worse" and "this was a bad month, once" can be told apart.
//
//  Laid out against the design lock: the serif title in the body under the
//  status line, the window said in words, one hairline, then the topics. The
//  window figure sits in the status line's right slot, which is exactly what
//  that slot is for — it is the one figure that describes the whole screen.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/script.dart';
import '../design/marks.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../insights/insights.dart';
import '../state/notes_controller.dart';

class PatternsScreen extends StatelessWidget {
  const PatternsScreen({super.key, this.weeks = 4});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    final NotesController notes = context.watch<NotesController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    final WeekSummary week = summarise(
      notes.notes,
      now: DateTime.now(),
      weeks: weeks,
      // The card on Home shows a handful; here there is room for the tail,
      // and the tail is where a thread you had not noticed tends to be.
      maxTopics: 12,
    );

    return JotaScreen(
      // Empty label: the status line's right slot now sits hard against the
      // right edge, so a name there would butt straight into the figure. The
      // screen already says what it is, in serif, four lines down — the label
      // was the second copy.
      label: '',
      upcase: false,
      value: '$weeks WEEKS',
      onBack: () => Navigator.of(context).pop(),
      // The hairline this screen keeps is the one under its serif title, in the
      // body. Drawing a second one under the status line spent two pieces of
      // chrome on a screen the design gives one.
      rule: false,
      child: week.topics.isEmpty
          ? const JotaEmpty(
              mark: JotaEmptyMarkView(EmptyMark.noPatterns),
              message: 'No patterns yet',
            )
          : ListView(
              padding: const EdgeInsets.only(
                top: JotaGrid.gapM,
                bottom: JotaGrid.gapXL,
              ),
              children: <Widget>[
                Text('What keeps coming back', style: t.headline),
                const SizedBox(height: JotaGrid.gapS),
                Text(
                  'Across your last $weeks weeks',
                  style: t.prose.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: JotaGrid.gapL),
                const JotaRule(),
                for (int i = 0; i < week.topics.length; i++) ...<Widget>[
                  const SizedBox(height: JotaGrid.gapM),
                  _TopicRow(topic: week.topics[i]),
                  const SizedBox(height: JotaGrid.gapM),
                  // No rule after the last one: a hairline under the final row
                  // draws a floor across nothing, and the list should simply
                  // stop where the topics do.
                  if (i < week.topics.length - 1) const JotaRule(),
                ],
              ],
            ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final int thisWeek =
        topic.weeklyCounts.isEmpty ? 0 : topic.weeklyCounts.last;
    final String figures = thisWeek > 0
        ? '${topic.noteCount} NOTES · $thisWeek THIS WEEK'
        : '${topic.noteCount} NOTES';

    // The bars per week are gone: with a handful of notes they were three
    // flat dashes and one block, which reads as broken, and an Arabic label
    // sat on the right while its bars sat on the left. Two plain figures
    // say the same thing. The whole row follows the label's script, so the
    // figures sit at the trailing edge in either direction.
    return Directionality(
      textDirection:
          isRtlText(topic.label) ? TextDirection.rtl : TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(
            child: NoteText(
              topic.label,
              style: t.prose.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: JotaGrid.gapM),
          Text(figures, style: t.meta.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}
