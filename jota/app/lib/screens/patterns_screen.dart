// ============================================================================
//  Jota — what keeps coming back, in full
//
//  Reached from Home, never from the nav. It answers a question you ask
//  occasionally, and a destination you visit occasionally should not spend a
//  third of the bottom bar.
//
//  Each topic gets its count and a bar per week, so "this is getting worse" and
//  "this was a bad month, once" look different at a glance — which is the only
//  reason to draw the weeks at all.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/script.dart';
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
      label: 'Patterns',
      upcase: false,
      onBack: () => Navigator.of(context).pop(),
      child: week.topics.isEmpty
          ? Center(
              child: Text(
                'Nothing has come back often enough yet.',
                style: t.prose.copyWith(color: c.inkMuted),
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(top: JotaGrid.gapM),
              children: <Widget>[
                Text(
                  'Across your last $weeks weeks',
                  style: t.prose.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: JotaGrid.gapL),
                for (final Topic topic in week.topics) ...<Widget>[
                  _TopicRow(topic: topic),
                  const SizedBox(height: JotaGrid.gapM),
                  const JotaRule(),
                  const SizedBox(height: JotaGrid.gapM),
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
    final int peak =
        topic.weeklyCounts.fold(1, (int m, int v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
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
            Text(
              '${topic.noteCount} NOTES',
              style: t.reading.copyWith(color: c.inkMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: JotaGrid.gapS),
        // Bars, oldest week on the left. Scaled to this topic's own peak
        // rather than a shared maximum: the shape of one thread over time is
        // the question, not how it ranks against the others.
        SizedBox(
          height: 26,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final int v in topic.weeklyCounts) ...<Widget>[
                Container(
                  width: 14,
                  height: v == 0 ? JotaGrid.hairline : 26 * (v / peak),
                  color: v == 0 ? c.rule : c.ink,
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
