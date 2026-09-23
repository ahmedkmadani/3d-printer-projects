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
//
//  Finding a note: one search stadium and, when tags are in use, one row of
//  tag pills under the title. Both only appear once there is something to
//  search — an empty archive gets no controls to operate on nothing.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import 'widgets/note_actions.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen>
    with WidgetsBindingObserver {
  /// Rows this screen has already shown. A row not in here is new — it just
  /// arrived from a sync — and gets the entry motion; a row scrolled back into
  /// view does not, because nothing happened to it.
  final Set<String> _seen = <String>{};

  /// Rows swiped away but not yet gone from the repository. Filtered out of
  /// the list the moment the swipe completes, so the dismissed widget leaves
  /// the tree in the same frame Flutter expects it to.
  final Set<String> _removed = <String>{};

  static String _keyOf(Note n) => '${n.deviceId}/${n.noteId}';

  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = context.read<NotesController>().query;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A scan on open is what makes "put it on the desk and it syncs" true
      // while the app is in the foreground.
      //
      // No timeout, deliberately. The default 15 seconds meant the app knew
      // where the Jota was for a quarter of a minute after this tab opened and
      // never again — so the chip said NOT IN RANGE while the device sat next
      // to it, and only a trip away from this tab and back would fix it.
      // Presence is a live fact; it has to be watched, not sampled once.
      context.read<DeviceController>().startScan(timeout: null);
      context.read<NotesController>().drainTranscriptions();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<DeviceController>().startScan(timeout: null);
      context.read<NotesController>().drainTranscriptions();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilter(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.ink.bg,
      builder: (_) => const _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NotesController notes = context.watch<NotesController>();
    final DeviceController device = context.watch<DeviceController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final List<Note> all = notes.visible;
    _removed.removeWhere(
      (String k) => !all.any((Note n) => _keyOf(n) == k),
    );
    final List<Note> visible =
        all.where((Note n) => !_removed.contains(_keyOf(n))).toList();

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
                // No "pull down to sync" line: everyone pulls a list to
                // refresh, and the pull still works.
                Text('Notes', style: t.headline),
                if (notes.count > 0) ...<Widget>[
                  const SizedBox(height: JotaGrid.gapL),
                  // Search, and beside it the one button that opens the
                  // filter sheet — order and tag — the way a shop does it.
                  // The button inverts while a filter is on, so the list
                  // never looks short without saying why.
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: JotaSearchField(
                          controller: _search,
                          hint: 'Search notes',
                          onChanged: notes.setQuery,
                        ),
                      ),
                      const SizedBox(width: JotaRows.gap),
                      _FilterButton(
                        active: notes.tagFilter != null || !notes.newestFirst,
                        onTap: () => _openFilter(context),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: JotaGrid.gapL),
                const JotaRule(),
              ],
            ),
          ),
          // No "add a key" banner: it turned every empty morning into a nag
          // about configuration. Where the key matters is Settings, and it
          // says so there — see the "what leaves your phone" card.
          Expanded(
            child: notes.loading
                ? const SizedBox.shrink()
                : visible.isEmpty
                    ? notes.filtering
                        ? _NoMatch(
                            onClear: () {
                              _search.clear();
                              notes.clearFilters();
                            },
                          )
                        : _EmptyArchive(hasDevice: device.hasPairedDevice)
                    : RefreshIndicator(
                        color: c.ink,
                        backgroundColor: c.bg,
                        onRefresh: () => device.syncNow().then((_) {}),
                        child: ListView.separated(
                          // Scrolling the results is reading them; the
                          // keyboard should get out of the way.
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.only(bottom: JotaGrid.gapL),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: JotaGrid.margin,
                            ),
                            child: JotaRule(),
                          ),
                          itemBuilder: (BuildContext context, int i) {
                            final Note note = visible[i];
                            final String k = _keyOf(note);
                            final bool fresh = _seen.add(k);
                            // Swipe right: share. Swipe left: delete, after
                            // asking. The row slides out and the list closes
                            // the gap — that motion IS the confirmation that
                            // it went.
                            return Dismissible(
                              key: ValueKey<String>(k),
                              direction: DismissDirection.horizontal,
                              dismissThresholds: const <DismissDirection,
                                  double>{
                                DismissDirection.startToEnd: 0.35,
                                DismissDirection.endToStart: 0.35,
                              },
                              background: const _SwipeHint(
                                label: 'SHARE',
                                alignment: Alignment.centerLeft,
                              ),
                              secondaryBackground: const _SwipeHint(
                                label: 'DELETE',
                                alignment: Alignment.centerRight,
                                danger: true,
                              ),
                              confirmDismiss: (DismissDirection d) async {
                                if (d == DismissDirection.startToEnd) {
                                  await shareNote(context, note);
                                  return false; // the row stays
                                }
                                return confirmDeleteNote(context);
                              },
                              onDismissed: (_) {
                                setState(() => _removed.add(k));
                                notes.delete(note);
                              },
                              child: _Appear(
                                animate: fresh,
                                child: _NoteRow(
                                  note: note,
                                  transcribing: notes.isTranscribing(note),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          NoteDetailScreen(note: note),
                                    ),
                                  ),
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
///   notes waiting      2 NEW  — the device is holding something for you
///   otherwise          empty
///
/// No SYNC word while a sync runs: the pull-to-refresh spinner is already
/// saying so, and the same news twice on one screen is chrome. The archive
/// count used to sit here when nothing was pending and is gone for the same
/// reason: a number that never changes is not news. The count is not
/// zero-padded because it is read as words — "two new" — not as a measurement.
String? _pendingLabel(DeviceController device) {
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

    return JotaPressable(
      onTap: onTap,
      scale: 0.985,
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
                  style: t.meta.copyWith(color: c.inkMuted),
                ),
                const SizedBox(width: JotaGrid.gapM),
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
            // The words cross-fade in when the transcript lands, so you
            // notice they were not there a second ago.
            AnimatedSwitcher(
              duration: JotaMotion.normal,
              switchInCurve: JotaMotion.curve,
              child: KeyedSubtree(
                key: ValueKey<String>(
                  transcribing ? 'running' : note.preview,
                ),
                child: NoteText(
                  transcribing ? 'Transcribing…' : note.preview,
                  style: t.prose.copyWith(
                    color: note.hasTranscript ? c.ink : c.inkMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                  MaterialPageRoute<void>(
                    builder: (_) => const ConnectScreen(),
                  ),
                ),
              ),
            ),
    );
  }
}

/// The filter button: a circle the height of the search stadium, with the
/// sliders glyph. Outlined at rest; inverted while a filter is on, which is
/// what "chosen" looks like everywhere in the product.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return Semantics(
      button: true,
      label: 'Filter',
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: JotaMotion.fast,
          curve: JotaMotion.curve,
          width: JotaRows.heightCompact,
          height: JotaRows.heightCompact,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? c.ink : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? c.ink : c.rule,
              width: JotaGrid.hairline,
            ),
          ),
          child: Icon(
            LucideIcons.slidersHorizontal,
            size: 16,
            color: active ? c.onInk : c.ink,
          ),
        ),
      ),
    );
  }
}

/// The filter sheet. Two questions — which way round, and which tag — each
/// as stadium rows with the chosen one inverted. Choices apply as they are
/// tapped, so the list behind the sheet is already right when it closes.
/// "Clear" in the corner puts everything back; "Done" just closes.
class _FilterSheet extends StatelessWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context) {
    final NotesController notes = context.watch<NotesController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final bool anything = notes.tagFilter != null || !notes.newestFirst;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Filter', style: t.sheetTitle),
                ),
                if (anything)
                  GestureDetector(
                    onTap: () {
                      notes.setTagFilter(null);
                      notes.setNewestFirst(true);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'Clear',
                      style: t.prose.copyWith(color: c.inkMuted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: JotaGrid.gapL),
            const _SheetLabel('ORDER'),
            const SizedBox(height: JotaGrid.gapM),
            Row(
              children: <Widget>[
                Expanded(
                  child: JotaRow(
                    label: 'Newest first',
                    selected: notes.newestFirst,
                    height: JotaRows.heightCompact,
                    onTap: () => notes.setNewestFirst(true),
                  ),
                ),
                const SizedBox(width: JotaRows.gap),
                Expanded(
                  child: JotaRow(
                    label: 'Oldest first',
                    selected: !notes.newestFirst,
                    height: JotaRows.heightCompact,
                    onTap: () => notes.setNewestFirst(false),
                  ),
                ),
              ],
            ),
            if (notes.tagsInUse.isNotEmpty) ...<Widget>[
              const SizedBox(height: JotaGrid.gapL),
              const _SheetLabel('TAG'),
              const SizedBox(height: JotaGrid.gapM),
              Wrap(
                spacing: JotaRows.gap,
                runSpacing: JotaRows.gap,
                children: <Widget>[
                  JotaTagChoice(
                    label: 'All',
                    selected: notes.tagFilter == null,
                    onTap: () => notes.setTagFilter(null),
                  ),
                  for (final String tag in notes.tagsInUse)
                    JotaTagChoice(
                      label: tag,
                      selected: notes.tagFilter == tag,
                      onTap: () => notes.setTagFilter(tag),
                    ),
                ],
              ),
            ],
            const SizedBox(height: JotaGrid.gapL),
            JotaButton(
              label: 'Done',
              primary: true,
              upcase: false,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section label inside the sheet: mono, small, spaced — a card label,
/// never the start of a sentence.
class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.type.cardLabel.copyWith(color: context.ink.inkMuted),
    );
  }
}

/// A search or a tag that nothing matches. Says so, and offers the way back.
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return JotaEmpty(
      message: 'No notes match',
      action: SizedBox(
        width: 160,
        child: JotaButton(
          label: 'Show all',
          upcase: false,
          height: JotaRows.heightCompact,
          onTap: onClear,
        ),
      ),
    );
  }
}

/// What a swipe uncovers: one word, in the label face, on the field colour.
/// Not a coloured slab — the design's only colour is the signal, and it is
/// spent on the destructive word alone.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.label,
    required this.alignment,
    this.danger = false,
  });

  final String label;
  final Alignment alignment;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return Container(
      color: c.field,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: JotaGrid.margin),
      child: Text(
        label,
        style: context.type.label.copyWith(
          color: danger ? c.signal : c.inkMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// A row that has just arrived fades in and settles down by a few pixels.
/// Once. Rows that were already there render as they always did.
class _Appear extends StatefulWidget {
  const _Appear({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: JotaMotion.normal,
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation a =
        CurvedAnimation(parent: _c, curve: JotaMotion.curve);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.08),
          end: Offset.zero,
        ).animate(a),
        child: widget.child,
      ),
    );
  }
}
