// ============================================================================
//  Jota — note list
//
//  Home. Mirrors the device's MENU/NOTES screens: a status line with the count
//  in the right slot, a hairline, and rows. The device's own list is stadiums
//  because it has five items and no scrolling; a phone list of a hundred notes
//  is hairline-separated rows instead — a hundred stadiums would be noise.
//
//  Each row is the same three facts the device shows: the id, the duration, and
//  what was said. Id and duration in mono because they are figures; the
//  transcript in sans because it is prose. That split is the product.
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
import 'sync_screen.dart';

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
    final List<Note> visible = notes.visible;

    // STATUS RIGHT SLOT RULE: the one defining figure. Here it is how many
    // notes are in the archive.
    return JotaScreen(
      label: 'Notes',
      upcase: false,
      value: fmtCount(visible.length),
      showSignalDot: (device.pendingOnDevice ?? 0) > 0,
      padded: false,
      trailing: _HeaderActions(
        archived: visible.length,
        pending: device.pendingOnDevice,
        syncing: device.isSyncing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
                        color: context.ink.ink,
                        backgroundColor: context.ink.bg,
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
///   notes waiting      003    — at full ink, because it is a call to action
///   otherwise          008    — how many notes are in the archive
///
/// Never two figures, never a figure plus an icon. The device's status line has
/// room for one thing and so does this one.
class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.archived,
    required this.pending,
    required this.syncing,
  });

  final int archived;
  final int? pending;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    if (syncing) {
      return Text('SYNC', style: t.reading.copyWith(color: c.inkMuted));
    }
    if (pending != null && pending! > 0) {
      return Text(fmtCount(pending!), style: t.reading.copyWith(color: c.ink));
    }
    return Text(
      fmtCount(archived),
      style: t.reading.copyWith(color: c.inkMuted),
    );
  }
}

/// Selection by inversion, exactly like the device's rows — filled ink, label
/// knocked out. No tint, no colour, no checkmark.
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
          vertical: JotaGrid.gapM + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Meta line: WHEN it was said, and what it was filed under. The
            // note's id and its duration used to lead here — but neither is
            // how anyone finds a note. You remember the afternoon, not that it
            // was N-012 and ran 47 seconds. Both still exist, on the note
            // itself, where they are facts rather than the headline.
            //
            // The tag is a pill, and it inverts when set — the same selection
            // vocabulary as every other surface on both objects.
            Row(
              children: <Widget>[
                Text(
                  fmtNoteStamp(note.recordedAt),
                  style: t.reading.copyWith(color: c.inkMuted, fontSize: 11),
                ),
                const SizedBox(width: JotaGrid.gapS),
                if (note.tag != null) JotaTagPill(label: note.tag!),
                const Spacer(),
                Text(
                  note.displayDuration,
                  style: t.reading.copyWith(color: c.inkMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: JotaGrid.gapS),
            // Prose line: sans, because at this width mono would fit about
            // fifteen characters and shred the sentence.
            //
            // NoteText, not Text: these are the note's own words, so an Arabic
            // one flips to right-to-left and picks up the Arabic face. The id,
            // duration and tag above it deliberately do not — they are chrome
            // and follow the app.
            NoteText(
              transcribing ? 'Transcribing…' : note.preview,
              style: t.prose.copyWith(
                fontSize: 15,
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
                  MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                ),
              ),
            ),
    );
  }
}

/// Says why nothing is being transcribed, where the silence is actually
/// noticed.
///
/// Without this the app is quietly broken in the most confusing way possible:
/// notes arrive, play back perfectly, and simply never grow text. The only
/// hint was a message on the detail screen pointing at a Settings section that
/// did not exist.