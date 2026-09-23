// ============================================================================
//  Jota — note detail
//
//  The design lock's "One note", top to bottom: the stamp and the tag, what it
//  was ABOUT on a field-coloured card, the player as a single stadium, then the
//  raw words. Gemma's summary above, the transcript below — audio is there,
//  never required. The design's serif headline is the note's subject, and there
//  is no subject to draw yet; see the note where it would go.
//
//  The device's NOTE VIEW screen (screens.cpp, screenNoteView) stops at a meta
//  line and the transcript because it has 200x200 pixels. The phone adds the
//  two things it can afford: playback, and a tag.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/note_player.dart';
import '../data/note.dart';
import '../design/format.dart';
import '../design/script.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/notes_controller.dart';
import 'widgets/note_actions.dart';
import '../state/services.dart';

class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.note});

  final Note note;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late Note _note = widget.note;

  Note _refresh(NotesController c) {
    for (final Note n in c.notes) {
      if (n.deviceId == _note.deviceId && n.noteId == _note.noteId) return n;
    }
    return _note;
  }

  @override
  Widget build(BuildContext context) {
    final NotesController notes = context.watch<NotesController>();
    _note = _refresh(notes);

    final Services services = context.read<Services>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return JotaScreen(
      // No title up here — the note's date is its title, in the body. The
      // header is a way back and the note's id, which is the one figure this
      // screen is defined by.
      label: '',
      upcase: false,
      value: _note.displayId,
      onBack: () => Navigator.of(context).pop(),
      // The design draws this screen with NO hairline anywhere: the meta line,
      // the card and the pill already separate themselves, and a rule under the
      // status line would be the only divider on a page that needs none.
      rule: false,
      // Pinned, as drawn: everything above it scrolls, the one action does
      // not. Outlined rather than filled — this screen is for reading, and a
      // solid pill would read as the thing you came here to do.
      footer: JotaButton(
        label: 'Edit tag',
        upcase: false,
        onTap: () => _editTag(context, notes, services),
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: JotaGrid.gapM),
        children: <Widget>[
          // Meta ABOVE the title, as drawn: the stamp and the tag are how you
          // confirm you opened the right note, so they come first and small.
          // The duration used to sit on the right of this line and is gone —
          // it is in the player now, next to the position, where the two
          // figures make a ratio instead of two lonely halves.
          Row(
            children: <Widget>[
              Text(
                fmtNoteStamp(_note.recordedAt),
                style: t.reading.copyWith(
                  color: c.inkMuted,
                  fontSize: 11,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(width: JotaGrid.gapS),
              // Inverted here, outlined in the list: this is the tag that was
              // chosen for this note, and inversion is what "chosen" looks
              // like everywhere in the product.
              if (_note.tag != null)
                JotaTagPill(label: _note.tag!, selected: true),
            ],
          ),
          const SizedBox(height: JotaGrid.gapL),

          // NO serif headline here. There was one — `August 15`, under a meta
          // line already reading `SAT 15 AUG · 15:22` — which is the same datum
          // twice at two sizes, and put a numeral in the serif face, which
          // docs/brand.md forbids outright (numbers are never serif).
          //
          // The design's headline on this screen is the note's SUBJECT
          // ("After the session"), and there is no subject field: Gemma is what
          // would write one and Gemma is not wired up. The first words of the
          // transcript were the other candidate and are worse — they repeat,
          // verbatim, the paragraph two blocks below, and an Arabic note would
          // put a right-to-left fragment in a Latin serif. So the date stays in
          // the meta line where it costs one line, and the headline waits for
          // the thing it is meant to hold.

          // What the note was ABOUT, above the words themselves — the design's
          // first block, and the half problem.md says every voice recorder
          // ignores. Gemma fills this in; until it exists the card says so
          // rather than showing invented bullets, because a summary you cannot
          // trust is worse than none.
          _SummaryCard(note: _note),
          const SizedBox(height: JotaGrid.gapL),

          _PlayerPill(
            key: ValueKey<String>('${_note.deviceId}/${_note.noteId}'),
            createPlayer: services.newPlayer,
            deviceId: _note.deviceId,
            noteId: _note.noteId,
            durationSeconds: _note.secs,
          ),
          const SizedBox(height: JotaGrid.gapL),

          // No hairline between the player and the words. The design runs
          // card, player, transcript as one column with one rhythm; a rule in
          // there made the transcript look like a different screen's content.
          _TranscriptBlock(
            note: _note,
            transcribing: notes.isTranscribing(_note),
            onTranscribe: () => notes.transcribe(_note),
            onEdit: () => _editTranscript(context, notes),
          ),

          if (_note.transcriptError != null) ...<Widget>[
            const SizedBox(height: JotaGrid.gapM),
            Text(
              _note.transcriptError!,
              style: t.reading.copyWith(color: c.signal),
            ),
          ],

          // NOT in the design sheet, and kept anyway: deleting a note has no
          // other route in the app, and a note you cannot delete is a promise
          // the privacy story does not get to make. It sits at the very bottom
          // of the scroll, label-only in the signal colour, so it is reachable
          // without being offered.
          const SizedBox(height: JotaGrid.gapXL),
          Row(
            children: <Widget>[
              Expanded(
                child: JotaButton(
                  label: 'Share',
                  upcase: false,
                  height: JotaRows.heightCompact,
                  onTap: () => shareNote(context, _note),
                ),
              ),
              const SizedBox(width: JotaRows.gap),
              Expanded(
                child: JotaButton(
                  label: 'Delete',
                  danger: true,
                  upcase: false,
                  height: JotaRows.heightCompact,
                  onTap: () => _confirmDelete(context, notes),
                ),
              ),
            ],
          ),
          const SizedBox(height: JotaGrid.gapL),
        ],
      ),
    );
  }

  /// The tag list, on a sheet rather than inline.
  ///
  /// It used to be a wrap of stadium rows sitting permanently under the
  /// transcript — a settings control parked on a reading screen, and the
  /// heaviest block on it. The design has one outlined button instead, so the
  /// choice comes when it is asked for.
  Future<void> _editTag(
    BuildContext context,
    NotesController notes,
    Services services,
  ) async {
    final List<String> tags = services.settings.tags;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.ink.bg,
      builder: (BuildContext sheetContext) {
        final JotaType t = sheetContext.type;
        final JotaColors c = sheetContext.ink;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              JotaGrid.margin,
              JotaGrid.gapL,
              JotaGrid.margin,
              JotaGrid.gapL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Tag', style: t.headline.copyWith(fontSize: 28)),
                const SizedBox(height: JotaGrid.gapS),
                Text(
                  tags.isEmpty
                      ? 'No tags yet — add them in Settings.'
                      : 'Tap the one it belongs to. Tap it again to clear it.',
                  style: t.prose.copyWith(color: c.inkMuted),
                ),
                if (tags.isNotEmpty) ...<Widget>[
                  const SizedBox(height: JotaGrid.gapL),
                  Wrap(
                    spacing: JotaRows.gap,
                    runSpacing: JotaRows.gap,
                    children: <Widget>[
                      for (final String tag in tags)
                        IntrinsicWidth(
                          child: JotaRow(
                            label: tag,
                            selected: _note.tag == tag,
                            height: JotaRows.heightCompact,
                            onTap: () {
                              notes.setTag(
                                _note,
                                _note.tag == tag ? null : tag,
                              );
                              Navigator.of(sheetContext).pop();
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editTranscript(
    BuildContext context,
    NotesController notes,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: _note.transcript ?? '');

    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.ink.bg,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: JotaGrid.margin,
            right: JotaGrid.margin,
            top: JotaGrid.gapL,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + JotaGrid.gapL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Transcript', style: context.type.label),
              const SizedBox(height: JotaGrid.gapM),
              TextField(
                controller: controller,
                maxLines: 8,
                minLines: 4,
                autofocus: true,
                style: context.type.prose,
                decoration: const InputDecoration(
                  hintText: 'What was said',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: JotaGrid.gapM),
              JotaButton(
                label: 'Save',
                primary: true,
                upcase: false,
                onTap: () =>
                    Navigator.of(sheetContext).pop(controller.text.trim()),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      await notes.setTranscript(_note, result);
    }
    controller.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    NotesController notes,
  ) async {
    if (!await confirmDeleteNote(context)) return;
    if (!context.mounted) return;
    await notes.delete(_note);
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// "What it was about" — the few real points inside a ramble.
///
/// A PLACEHOLDER for now. Sorting is Gemma's job and Gemma is not wired up, so
/// this states that plainly instead of filling the card with plausible
/// sentences. On a screen whose whole promise is "you can trust what you read
/// here", inventing the summary would be the one unrecoverable lie.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JotaGrid.gapL,
        vertical: JotaGrid.gapM + 4,
      ),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius:
            const BorderRadius.all(Radius.circular(JotaCards.radius)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Mono, not sans: the design draws every card label in the figure
          // face, spaced out and small, so a label never reads as the start of
          // a sentence.
          Text(
            'WHAT IT WAS ABOUT',
            style: t.reading.copyWith(
              color: c.inkMuted,
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: JotaGrid.gapM),
          Text(
            note.hasTranscript
                ? 'Not sorted yet. The points inside this note will appear '
                    'here once Jota can read it back to itself.'
                : 'Nothing to sort yet — this note has no words on it.',
            style: t.prose.copyWith(color: c.inkMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Playback as ONE stadium: the circle, the hairline scrubber, the ratio.
///
/// Private to this screen rather than the shared `PlaybackBar`, which is a
/// 132pt PLAY button over a 12pt outlined progress bar — three stacked shapes
/// where the design has one, and the loudest thing on a screen whose point is
/// that the audio is optional.
/// Play as a triangle, pause as two bars — the two shapes everyone already
/// reads, drawn in the app's own ink rather than borrowed from an icon set.
class _TransportMark extends CustomPainter {
  const _TransportMark({required this.playing, required this.color});

  final bool playing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = color;
    final double w = size.width;
    final double h = size.height;
    if (playing) {
      final double bar = w * 0.3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.08, 0, bar, h),
          const Radius.circular(1),
        ),
        p,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w - bar - w * 0.08, 0, bar, h),
          const Radius.circular(1),
        ),
        p,
      );
      return;
    }
    // Nudged right by a hair: a triangle centred on its bounding box reads as
    // sitting left of centre inside a circle.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.15, 0)
        ..lineTo(w, h / 2)
        ..lineTo(w * 0.15, h)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(_TransportMark old) =>
      old.playing != playing || old.color != color;
}

class _PlayerPill extends StatefulWidget {
  const _PlayerPill({
    super.key,
    required this.createPlayer,
    required this.deviceId,
    required this.noteId,
    required this.durationSeconds,
  });

  /// A factory rather than an instance: this widget owns the player's lifetime
  /// and disposes it, and a note change should get a fresh one.
  final NotePlayer Function() createPlayer;

  final String deviceId;
  final int noteId;
  final int durationSeconds;

  @override
  State<_PlayerPill> createState() => _PlayerPillState();
}

class _PlayerPillState extends State<_PlayerPill> {
  static const double _circle = 28;

  late final NotePlayer _player = widget.createPlayer();
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;

  Duration _position = Duration.zero;
  bool _loading = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _playingSub = _player.playingChanges.listen((_) {
      if (mounted) setState(() {});
    });
    _positionSub = _player.position.listen((Duration p) {
      if (!mounted) return;
      setState(() => _position = p);

      // Neither implementation reports "finished" as a stop, so the pill would
      // otherwise sit at the end still showing PAUSE.
      final Duration? total = _player.duration;
      if (total != null &&
          total > Duration.zero &&
          p >= total &&
          _player.playing) {
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }

    if (!_ready) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final bool ok = await _player.load(widget.deviceId, widget.noteId);
        if (!mounted) return;
        if (!ok) {
          setState(() {
            _loading = false;
            _error = 'Audio file is missing';
          });
          return;
        }
        _ready = true;
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Could not play this note ($e)';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    }

    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    final Duration total =
        _player.duration ?? Duration(seconds: widget.durationSeconds);
    final double fraction = total.inMilliseconds <= 0
        ? 0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          decoration: BoxDecoration(
            // Radius = height/2, so it is a stadium like every other shape in
            // the product. The pill is 50 high: 28 of circle, 11 either side.
            borderRadius: JotaRows.borderRadiusOf(_circle + 22),
            border: Border.all(color: c.rule, width: JotaGrid.hairline),
          ),
          child: Row(
            children: <Widget>[
              Semantics(
                button: true,
                label: _player.playing ? 'Pause' : 'Play',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: Container(
                    width: _circle,
                    height: _circle,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.ink,
                      shape: BoxShape.circle,
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(c.onInk),
                            ),
                          )
                        // Drawn, not an icon: these were the only Material
                        // glyphs left in the app, and a set whose weight and
                        // corner treatment are not ours has no business inside
                        // the one circle the design draws bare.
                        : CustomPaint(
                            size: const Size(14, 14),
                            painter: _TransportMark(
                              playing: _player.playing,
                              color: c.onInk,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: JotaGrid.gapM),
              Expanded(
                child: _Scrubber(
                  fraction: fraction,
                  onSeek: (double f) async {
                    if (total.inMilliseconds <= 0) return;
                    await _player.seek(total * f);
                  },
                ),
              ),
              const SizedBox(width: JotaGrid.gapM),
              // Both figures, both mono, both zero-padded — the same shape as
              // a ratio in a status slot, and small enough that the audio
              // stays an offer rather than an instruction.
              Text(
                '${fmtDuration(_position.inSeconds)} / '
                '${fmtDuration(total.inSeconds)}',
                style: t.reading.copyWith(color: c.inkMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: JotaGrid.gapS),
          Text(_error!, style: t.reading.copyWith(color: c.signal)),
        ],
      ],
    );
  }
}

/// The scrubber inside the pill: a hairline track with the played part in ink.
///
/// Not [JotaProgressBar] — that is an outlined stadium 12 high, which inside a
/// pill reads as a second pill. Tap maths uses THIS widget's box rather than
/// the row's, so a tap lands where it looks like it landed.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.fraction, required this.onSeek});

  final double fraction;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) {
            if (box.maxWidth <= 0) return;
            onSeek((d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0));
          },
          // A tall transparent box around a 4pt line: the line is the design,
          // but a 4pt tap target is not a tap target.
          child: SizedBox(
            height: 24,
            child: Center(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: c.rule,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.ink,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TranscriptBlock extends StatelessWidget {
  const _TranscriptBlock({
    required this.note,
    required this.transcribing,
    required this.onTranscribe,
    required this.onEdit,
  });

  final Note note;
  final bool transcribing;
  final VoidCallback onTranscribe;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    // The words fade in when they land. Keyed on the text itself, so an edit
    // cross-fades too and a rebuild for any other reason does nothing.
    final bool running =
        transcribing || note.transcriptState == TranscriptState.running;
    final String key = running
        ? 'running'
        : note.hasTranscript
            ? 'text:${note.transcript}'
            : 'none';
    return AnimatedSwitcher(
      duration: JotaMotion.normal,
      switchInCurve: JotaMotion.curve,
      child: KeyedSubtree(key: ValueKey<String>(key), child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    if (transcribing || note.transcriptState == TranscriptState.running) {
      return Text(
        'Transcribing…',
        style: t.prose.copyWith(color: c.inkMuted),
      );
    }

    if (note.hasTranscript) {
      return GestureDetector(
        onLongPress: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Prose is the one place sans beats mono — the same reason the
            // device gives in screens.cpp. NoteText so an Arabic transcript
            // reads right to left in the Arabic face; the chrome around it
            // stays in the app's direction.
            NoteText(note.transcript!, style: t.prose),
            const SizedBox(height: JotaGrid.gapM),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    note.transcriptState == TranscriptState.manual
                        ? 'Edited by hand'
                        : 'Hold to edit',
                    style: t.prose.copyWith(color: c.inkMuted, fontSize: 12),
                  ),
                ),
                // A second pass is worth offering: the model changes (the
                // first Arabic note went through an English-only model and
                // came back English), and a note read badly once is not a
                // note to re-record. Runs through whatever model Settings
                // names now and replaces the words.
                GestureDetector(
                  onTap: onTranscribe,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Transcribe again',
                    style: t.prose.copyWith(color: c.inkMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // The device says NO TRANSCRIPT, centred, and nothing else. The phone can
    // do something about it, so it offers the one action that helps.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          note.transcriptState == TranscriptState.done
              ? 'No speech detected'
              : 'Not transcribed yet',
          style: t.prose.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: JotaGrid.gapM),
        Row(
          children: <Widget>[
            Expanded(
              child: JotaButton(
                label: 'Transcribe',
                primary: true,
                upcase: false,
                height: JotaRows.heightCompact,
                onTap: onTranscribe,
              ),
            ),
            const SizedBox(width: JotaRows.gap),
            Expanded(
              child: JotaButton(
                label: 'Write it',
                upcase: false,
                height: JotaRows.heightCompact,
                onTap: onEdit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
