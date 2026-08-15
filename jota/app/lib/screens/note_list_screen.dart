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
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/note.dart';
import '../design/format.dart';
import '../design/script.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/notes_controller.dart';
import '../state/services.dart';
import 'note_detail_screen.dart';
import 'settings_screen.dart';
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

  /// Whether transcription is unconfigured. Checked once per appearance rather
  /// than watched: a keychain read is async and the answer changes only when
  /// the user sets a key, which comes back through _refreshKeyState.
  bool _needsKey = false;

  Future<void> _refreshKeyState() async {
    final bool has = await context.read<Services>().settings.hasApiKey();
    if (!mounted || has == !_needsKey) return;
    setState(() => _needsKey = !has);
  }

  @override
  Widget build(BuildContext context) {
    final NotesController notes = context.watch<NotesController>();
    final DeviceController device = context.watch<DeviceController>();
    unawaited(_refreshKeyState());
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
          if (_needsKey) const _NoKeyBanner(),
          if (notes.tagsInUse.isNotEmpty)
            _TagFilterStrip(
              tags: notes.tagsInUse,
              selected: notes.tagFilter,
              onSelect: notes.setTagFilter,
            ),
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

class _TagFilterStrip extends StatelessWidget {
  const _TagFilterStrip({
    required this.tags,
    required this.selected,
    required this.onSelect,
  });

  final List<String> tags;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: JotaRows.heightCompact + JotaGrid.gapM * 2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: JotaGrid.margin,
          vertical: JotaGrid.gapM,
        ),
        children: <Widget>[
          _FilterPill(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final String tag in tags) ...<Widget>[
            const SizedBox(width: JotaRows.gap),
            _FilterPill(
              label: tag,
              selected: selected == tag,
              onTap: () => onSelect(selected == tag ? null : tag),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selection by inversion, exactly like the device's rows — filled ink, label
/// knocked out. No tint, no colour, no checkmark.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: JotaRow(
        label: label,
        selected: selected,
        height: JotaRows.heightCompact,
        onTap: onTap,
      ),
    );
  }
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
          vertical: JotaGrid.gapM + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Figure line: everything here is a measurement, so all of it is
            // mono and all of it is zero-padded.
            Row(
              children: <Widget>[
                Text(note.displayId, style: t.label),
                const SizedBox(width: JotaGrid.gapM),
                Text(
                  fmtClock(note.recordedAt),
                  style: t.reading.copyWith(color: c.inkMuted),
                ),
                const Spacer(),
                if (note.tag != null) ...<Widget>[
                  Text(
                    note.tag!,
                    style: t.reading.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(width: JotaGrid.gapM),
                ],
                Text(note.displayDuration, style: t.reading),
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
class _NoKeyBanner extends StatelessWidget {
  const _NoKeyBanner();

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          JotaGrid.margin,
          JotaGrid.gapS,
          JotaGrid.margin,
          0,
        ),
        padding: const EdgeInsets.all(JotaGrid.gapM),
        decoration: BoxDecoration(
          border: Border.all(color: c.inkMuted),
          borderRadius: BorderRadius.circular(JotaGrid.gapM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Not transcribing yet', style: t.label),
            const SizedBox(height: JotaGrid.gapS),
            Text(
              // Lead with the reassurance. The notes ARE safe; only the text is
              // missing, and that distinction is the whole anxiety here.
              'Your notes are saved and playable. Add a Google Cloud key in '
              'Settings to turn them into text.',
              style: t.prose.copyWith(color: c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
