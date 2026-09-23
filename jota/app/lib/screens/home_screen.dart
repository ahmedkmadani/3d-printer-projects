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
//  The device card, first under the hairline, answers the second question —
//  and tapping it syncs.
//
//  Laid out against the design lock (docs/brand.md and the Jota Design Lock
//  sheet): serif title, the two figures, a hairline, then two field-coloured
//  cards. The title moved OUT of the status line and into the body — the status
//  line is now just the app's name, the way the sheet draws it, so the one big
//  serif line on the screen is the only thing claiming to be a heading.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/note.dart';
import '../design/format.dart';
import '../design/script.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../insights/insights.dart';
import '../state/device_controller.dart';
import '../state/notes_controller.dart';
import 'note_detail_screen.dart';
import 'patterns_screen.dart';
import 'widgets/device_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onSeeNotes});

  /// Tapping the latest note's card when there is nothing else to show should
  /// land you in the archive rather than nowhere.
  final VoidCallback? onSeeNotes;

  @override
  Widget build(BuildContext context) {
    final NotesController notes = context.watch<NotesController>();
    final DeviceController device = context.watch<DeviceController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    // What is waiting, most urgent first: notes still on the device, a
    // transcription running, then nothing. The headline is the thing to do
    // next, and "This week" only when there is nothing to do.
    final int pending = device.pendingOnDevice ?? 0;
    Note? running;
    for (final Note n in notes.notes) {
      if (n.transcriptState == TranscriptState.running ||
          notes.isTranscribing(n)) {
        running = n;
        break;
      }
    }
    final String title = pending > 0
        ? '$pending note${pending == 1 ? '' : 's'} waiting'
        : running != null
            ? 'Transcribing'
            : 'This week';
    final String? lead = pending > 0
        ? 'On your Jota. Bring it close and it syncs.'
        : running != null
            ? '${running.displayId} is being read. It lands here when done.'
            : null;

    // DateTime.now() is read here rather than held in state: the summary is
    // cheap, and a cached "now" is how a screen ends up insisting it is still
    // last Tuesday after the phone has been asleep for a week.
    final WeekSummary week = summarise(notes.notes, now: DateTime.now());

    return JotaScreen(
      // STATUS RIGHT SLOT RULE: this screen's defining figure is now drawn at
      // 48pt in the body, so repeating it up here as `012` would be the same
      // datum twice at two sizes — the exact failure theme.h was written to
      // prevent.
      // Nothing up here. The mark lived in this slot for a while and earned
      // nothing: the status slot's rule, inherited from the panel, is ONE
      // DEFINING FIGURE — a count, a ratio, an id — and a logo is not a figure.
      // It was brand decoration in the one place the app reserves for
      // information, on the screen you open every day. The device does the same
      // thing: it wears the mark when idle and gets out of the way once you are
      // using it.
      label: '',
      // The heading and its hairline are in the BODY, so the status line does
      // not get one too. Two rules within forty pixels is two pieces of chrome
      // where the rule says there is one, and it fenced off a strip holding
      // nothing but the app's name.
      rule: false,
      child: ListView(
        padding: const EdgeInsets.only(
          top: JotaGrid.gapM,
          bottom: JotaGrid.gapXL,
        ),
        children: <Widget>[
          Text(title, style: t.headline),
          if (lead != null) ...<Widget>[
            const SizedBox(height: JotaGrid.gapS),
            Text(lead, style: t.prose.copyWith(color: c.inkMuted)),
          ],
          const SizedBox(height: JotaGrid.gapL),
          const DeviceCard(),
          const SizedBox(height: JotaGrid.gapL),
          // The two figures sit under the device card now: what is waiting
          // outranks how much was said, and the card is the thing to tap.
          if (lead != null) ...<Widget>[
            Text('THIS WEEK', style: _cardLabel(t, c)),
            const SizedBox(height: JotaGrid.gapM),
          ],
          _Figures(week: week),
          const SizedBox(height: JotaGrid.gapL),
          const JotaRule(),
          const SizedBox(height: JotaGrid.gapL),
          // Nothing recorded yet: one sentence about what to do, in place
          // of two cards about nothing.
          if (notes.notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: JotaGrid.gapXL),
              child: JotaEmpty(
                message: 'Press the button on your Jota and say something. '
                    'It will be here when you get back.',
              ),
            )
          // Hidden until there are enough notes for a count to mean
          // something: see kMinNotesForPatterns.
          else if (!enoughForPatterns(notes.notes) || week.topics.isEmpty)
            const _NothingYet()
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
            _LatestCard(
              note: week.latest!,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NoteDetailScreen(note: week.latest!),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- card ------------------------------------------------------------------
// The design's `.card`: the field colour, a soft radius, a mono label in caps,
// then its rows. Private rather than promoted into design/widgets.dart because
// only Home has cards — the rest of the app is hairlines and stadiums.
//
// Field fill and NO hairline: a border as well as a fill would make it a box,
// and the whole point of `field` is that it is a hair off the paper.
class _Card extends StatelessWidget {
  const _Card({required this.label, required this.children, this.onTap});

  final String label;
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(JotaGrid.gapM + JotaGrid.unit),
        decoration: BoxDecoration(
          color: c.field,
          borderRadius: const BorderRadius.all(
            Radius.circular(JotaCards.radius),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(label.toUpperCase(), style: _cardLabel(t, c)),
            for (final Widget w in children) ...<Widget>[
              const SizedBox(height: JotaGrid.gapM),
              w,
            ],
          ],
        ),
      ),
    );
  }
}

/// The card's own label, and the unit under a figure: mono, small, widely
/// tracked, muted. Every small caption on this screen is a figure's chrome, so
/// they all share the figure face.
TextStyle _cardLabel(JotaType t, JotaColors c) =>
    t.cardLabel.copyWith(color: c.inkMuted);

/// Two figures, in mono, because they are measurements. Nothing else on the
/// screen is allowed to be this big.
class _Figures extends StatelessWidget {
  const _Figures({required this.week});

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Figure(value: '${week.noteCount}', unit: 'NOTES'),
        const SizedBox(width: JotaGrid.gapXL),
        _Figure(value: week.spokenValue, unit: week.spokenUnit),
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
        // SANS, not the mono figure face — the one deliberate exception to
        // "every figure is mono" (docs/brand.md), and it is about this size
        // only. Plex Mono's zero carries a dot, which at 48pt beside a second
        // zero reads as a pair of eyes staring off the screen. Mono earns its
        // place where figures must ALIGN — ids, timers, a column of counts —
        // and these two stand alone.
        //
        // Regular weight, and tabular figures so 8 and 11 still occupy the
        // same width as the week turns over.
        // Counts up from zero the first time it is drawn: the number lands
        // rather than being there already, which is the difference between
        // a page and a device.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0,
            end: (int.tryParse(value) ?? 0).toDouble(),
          ),
          duration: const Duration(milliseconds: 700),
          curve: JotaMotion.curve,
          builder: (BuildContext context, double v, _) => Text(
            int.tryParse(value) == null ? value : v.round().toString(),
            style: t.prose.copyWith(
              fontSize: 44,
              fontWeight: FontWeight.w400,
              height: 1,
              letterSpacing: -0.5,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: JotaGrid.gapS),
        Text(unit, style: _cardLabel(t, c)),
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
    return _Card(
      label: 'What keeps coming back',
      onTap: onSeeAll,
      children: <Widget>[
        for (final Topic topic in topics)
          Row(
            children: <Widget>[
              Expanded(child: NoteText(topic.label, style: t.prose)),
              const SizedBox(width: JotaGrid.gapM),
              Text(
                '${topic.noteCount}',
                style: t.meta.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        // Ink, not the accent: this is a link, and the accent means live
        // or dangerous. See docs/brand.md.
        Text('SEE ALL PATTERNS →', style: t.navLabel),
      ],
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Text(
      // Said plainly, because "no patterns" reads as a failure otherwise —
      // and the honest reason is simply that there is not enough yet.
      'Nothing has come back often enough to call a pattern yet. Keep '
      'talking and it will.',
      style: t.prose.copyWith(color: c.inkMuted),
    );
  }
}

/// The newest note, on the same card as the findings so the two answers sit in
/// the same shape.
///
/// Stamp and tag on one line, the note's own words under them — the note-row
/// vocabulary from the archive, unchanged, so the same note looks like itself
/// in both places. The id and duration are deliberately absent: neither is how
/// anyone recognises a note, and the card has one line to make its case.
class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return _Card(
      label: 'Latest',
      onTap: onTap,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              fmtNoteStamp(note.recordedAt),
              style: t.meta.copyWith(color: c.inkMuted),
            ),
            const SizedBox(width: JotaGrid.gapM),
            // Inverted, as the sheet draws it: on a card that holds exactly one
            // note, the pill is the note's own mark rather than one of a set
            // you are choosing between.
            // Outlined, as on the list: here the tag is a label on a note,
            // and inversion is kept for a choice being made.
            if (note.tag != null) JotaTagPill(label: note.tag!),
          ],
        ),
        NoteText(
          note.preview,
          style: t.prose.copyWith(
            color: note.hasTranscript ? c.ink : c.inkMuted,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
