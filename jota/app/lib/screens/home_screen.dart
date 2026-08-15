// ============================================================================
//  Jota — Home
//
//  The state of your week, in one glance: how much you spoke, what keeps
//  coming back, and the last thing you said.
//
//  This tab exists because the patterns had nowhere to live. Adding them as a
//  fourth destination would have said the app has four jobs when it has one;
//  burying them in Notes would have meant nobody ever saw them. Home answers
//  the two questions actually asked on opening the app — "how was my week" and
//  "is the device fine" — and carries the findings on the way past.
//
//  The device chip above the nav answers the second question, so this screen
//  does not repeat it.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/note.dart';
import '../design/format.dart';
import '../design/script.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../insights/insights.dart';
import '../state/notes_controller.dart';
import 'note_detail_screen.dart';
import 'patterns_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onSeeNotes});

  /// Tapping the latest note's card when there is nothing else to show should
  /// land you in the archive rather than nowhere.
  final VoidCallback? onSeeNotes;

  @override
  Widget build(BuildContext context) {
    final NotesController notes = context.watch<NotesController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    // DateTime.now() is read here rather than held in state: the summary is
    // cheap, and a cached "now" is how a screen ends up insisting it is still
    // last Tuesday after the phone has been asleep for a week.
    final WeekSummary week = summarise(notes.notes, now: DateTime.now());

    return JotaScreen(
      label: 'This week',
      upcase: false,
      value: fmtCount(week.noteCount),
      child: ListView(
        padding: const EdgeInsets.only(top: JotaGrid.gapL),
        children: <Widget>[
          _Figures(week: week),
          const SizedBox(height: JotaGrid.gapL),
          const JotaRule(),
          const SizedBox(height: JotaGrid.gapL),

          if (week.topics.isEmpty)
            _NothingYet(hasNotes: notes.notes.isNotEmpty)
          else
            _TopicsCard(
              topics: week.topics,
              onSeeAll: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PatternsScreen(),
                ),
              ),
            ),

          if (week.latest != null) ...<Widget>[
            const SizedBox(height: JotaGrid.gapL),
            Text('LATEST', style: t.label.copyWith(color: c.inkMuted)),
            const SizedBox(height: JotaGrid.gapS),
            _LatestNote(
              note: week.latest!,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NoteDetailScreen(note: week.latest!),
                ),
              ),
            ),
          ],
          const SizedBox(height: JotaGrid.gapXL),
        ],
      ),
    );
  }
}

/// Two figures, in mono, because they are measurements. Nothing else on the
/// screen is allowed to be this big.
class _Figures extends StatelessWidget {
  const _Figures({required this.week});

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Figure(value: '${week.noteCount}', unit: 'NOTES'),
        const SizedBox(width: JotaGrid.gapXL),
        _Figure(value: '${week.totalMinutes}', unit: 'MINUTES'),
        const Spacer(),
        if (week.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: JotaGrid.gapS),
            child: Text(
              'Nothing yet',
              style: t.prose.copyWith(color: c.inkMuted),
            ),
          ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(value, style: t.display),
        const SizedBox(height: 2),
        Text(unit, style: t.label.copyWith(color: c.inkMuted, fontSize: 11)),
      ],
    );
  }
}

/// The findings, on a card because they are a summary of the archive rather
/// than a part of it.
class _TopicsCard extends StatelessWidget {
  const _TopicsCard({required this.topics, required this.onSeeAll});

  final List<Topic> topics;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return GestureDetector(
      onTap: onSeeAll,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(JotaGrid.gapM),
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'WHAT KEEPS COMING BACK',
              style: t.label.copyWith(color: c.inkMuted, fontSize: 11),
            ),
            const SizedBox(height: JotaGrid.gapM),
            for (final Topic topic in topics) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: NoteText(topic.label, style: t.prose),
                  ),
                  Text(
                    '${topic.noteCount}',
                    style: t.reading.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: JotaGrid.gapS),
            ],
            const SizedBox(height: 2),
            // Ink, not the accent: this is a link, and the accent means live
            // or dangerous. See docs/brand.md.
            Text(
              'See all patterns →',
              style: t.label.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet({required this.hasNotes});

  final bool hasNotes;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Text(
      hasNotes
          // Said plainly, because "no patterns" reads as a failure otherwise —
          // and the honest reason is simply that there is not enough yet.
          ? 'Nothing has come back often enough to call a pattern yet. Keep '
              'talking and it will.'
          : 'Press the button on your Jota and say something. It will be here '
              'when you get back.',
      style: t.prose.copyWith(color: c.inkMuted),
    );
  }
}

class _LatestNote extends StatelessWidget {
  const _LatestNote({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(note.displayId, style: t.label),
              const SizedBox(width: JotaGrid.gapS),
              if (note.tag != null)
                Text(
                  note.tag!,
                  style: t.reading.copyWith(color: c.inkMuted),
                ),
              const Spacer(),
              Text(note.displayDuration, style: t.reading),
            ],
          ),
          const SizedBox(height: JotaGrid.gapS),
          NoteText(
            note.preview,
            style: t.prose.copyWith(
              color: note.hasTranscript ? c.ink : c.inkMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
