// ============================================================================
//  Jota — note list
//
//  The archive, drawn exactly as the design lock draws it: a serif title, the
//  one line that says how to sync, a hairline, and then nothing but notes.
//
//  Each row is the two facts you actually reach for — WHEN it was said and what
//  it was filed under — over the note's own words. The id and the duration are
//  gone from the row: nobody finds a note by remembering it was N-012 and ran
//  47 seconds. Both still exist on the note itself, where they are facts rather
//  than the headline.
//
//  Stamp and tag in mono because they are figures and identifiers; the summary
//  in sans because it is prose. That split is the product.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/note.dart';
import '../design/format.dart';
import '../design/script.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/notes_controller.dart';
import 'note_detail_screen.dart';
import 'connect_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A scan on open is what makes "put it on the desk and it syncs" true
      // while the app is in the foreground.
      context.read<DeviceController>().startScan();
      context.read<NotesController>().drainTranscriptions();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<DeviceController>().startScan();
      context.read<NotesController>().drainTranscriptions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NotesController notes = context.watch<NotesController>();
    final DeviceController device = context.watch<DeviceController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final List<Note> visible = notes.visible;

    return JotaScreen(
      // The screen's name is the serif title in the body, as drawn, so the
      // status label is empty rather than saying "Notes" twice within forty
      // pixels of itself.
      label: '',
      upcase: false,
      // No signal dot here. The design carries "is the device holding
      // something" in the words — `2 NEW` — and the accent dot lives on the
      // device chip above the nav, where it is about the device rather than
      // about this list.
      // A STRING, not a widget: a trailing widget that renders nothing still
      // counts as "this strip has content", and the strip then holds 40pt of
      // blank paper open above the heading on the common case where nothing is
      // pending.
      value: _pendingLabel(device),
      // The title and its hairline are in the body, below. A second rule under
      // the status line made two hairlines of chrome where the design has one.
      rule: false,
      padded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              JotaGrid.margin,
              JotaGrid.gapM,
              JotaGrid.margin,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Notes', style: t.headline),
                const SizedBox(height: JotaGrid.gapS),
                // The only instruction on the screen, and it is one line. It
                // names the gesture that covers the times the OS refuses to
                // wake the app for the device.
                Text(
                  'Pull down to sync',
                  style: t.prose.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: JotaGrid.gapL),
                const JotaRule(),
              ],
            ),
          ),
          // No filter strip and no "add a key" banner. Both were chrome
          // sitting between you and the list: the strip spent a row of the
          // screen on a control for an archive that is usually short enough to
          // scroll, and the banner turned every empty morning into a nag about
          // configuration. Where the key matters is Settings, and it says so
          // there — see the "what leaves your phone" card.
          Expanded(
            child: notes.loading
                ? const SizedBox.shrink()
                : visible.isEmpty
                    ? _EmptyArchive(hasDevice: device.hasPairedDevice)
                    : RefreshIndicator(
                        color: c.ink,
                        backgroundColor: c.bg,
                        onRefresh: () => device.syncNow().then((_) {}),
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: JotaGrid.gapL),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: JotaGrid.margin,
                            ),
                            child: JotaRule(),
                          ),
                          itemBuilder: (BuildContext context, int i) {
                            return _NoteRow(
                              note: visible[i],
                              transcribing: notes.isTranscribing(visible[i]),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      NoteDetailScreen(note: visible[i]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// STATUS RIGHT SLOT RULE: exactly one figure, and it is the most urgent one
/// this screen has.
///
///   syncing            SYNC   — something is happening right now
///   notes waiting      2 NEW  — the device is holding something for you
///   otherwise          empty
///
/// The archive count used to sit here when nothing was pending. It is gone: a
/// number that never changes is not news, and the design's slot only ever holds
/// something worth acting on. The count is not zero-padded here because it is
/// read as words — "two new" — not as a measurement.
/// SYNC while it is running, `2 NEW` when the device is holding notes, and
/// nothing at all otherwise — the status slot carries only something worth
/// acting on.
String? _pendingLabel(DeviceController device) {
  if (device.isSyncing) return 'SYNC';
  final int? pending = device.pendingOnDevice;
  if (pending != null && pending > 0) return '$pending NEW';
  return null;
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.onTap,
    required this.transcribing,
  });

  final Note note;
  final VoidCallback onTap;
  final bool transcribing;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: JotaGrid.margin,
          vertical: JotaGrid.gapM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Meta line: WHEN it was said, and what it was filed under. The
            // tag is a stadium, outlined — it is a label here, not a choice,
            // and inversion is reserved for selection everywhere in this
            // product. It inverts on the note's own screen, where it is the
            // one that was chosen.
            Row(
              children: <Widget>[
                Text(
                  fmtNoteStamp(note.recordedAt),
                  style: t.reading.copyWith(
                    color: c.inkMuted,
                    fontSize: 11,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(width: JotaGrid.gapS),
                if (note.tag != null) JotaTagPill(label: note.tag!),
              ],
            ),
            const SizedBox(height: JotaGrid.gapS),
            // Prose line: sans, because at this width mono would fit about
            // fifteen characters and shred the sentence.
            //
            // NoteText, not Text: these are the note's own words, so an Arabic
            // one flips to right-to-left and picks up the Arabic face. The
            // stamp and tag above it deliberately do not — they are chrome and
            // follow the app.
            NoteText(
              transcribing ? 'Transcribing…' : note.preview,
              style: t.prose.copyWith(
                color: note.hasTranscript ? c.ink : c.inkMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive({required this.hasDevice});

  final bool hasDevice;

  @override
  Widget build(BuildContext context) {
    return JotaEmpty(
      message: hasDevice ? 'No notes yet' : 'No device paired',
      action: hasDevice
          ? null
          : SizedBox(
              width: 200,
              child: JotaButton(
                label: 'Pair a device',
                primary: true,
                upcase: false,
                height: JotaRows.heightTall,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ConnectScreen()),
                ),
              ),
            ),
    );
  }
}
