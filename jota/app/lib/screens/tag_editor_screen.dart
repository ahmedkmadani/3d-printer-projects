// ============================================================================
//  Jota — tags
//
//  App-first. Your tags live on the phone and are editable any time, with or
//  without the device. Every change is saved instantly; when a Jota is
//  connected, the same list is pushed to it so the e-paper agrees.
//
//  Max 8 tags, 12 characters each — the device's limits, shown rather than
//  enforced silently.
//
//  Drawn against the Jota Design Lock: a serif title, the one line that says
//  what dragging does, a hairline, then flat rows — grip, name, note count —
//  with the cut line across them. The rows were stadiums, which read as "pick
//  one of these"; nothing here is selected, it is a list you sort.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../ble/jota_protocol.dart';
import '../data/note.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/notes_controller.dart';
import '../state/services.dart';

class TagEditorScreen extends StatefulWidget {
  const TagEditorScreen({super.key, this.embedded = false});

  /// True when shown as a tab inside the home shell — no back chevron.
  final bool embedded;

  @override
  State<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends State<TagEditorScreen> {
  List<String> _tags = <String>[];
  bool _readingDevice = false;

  @override
  void initState() {
    super.initState();
    // The list is a synchronous prefs read — no loading state needed.
    _tags = List<String>.of(context.read<Services>().settings.tags);
    // The device round trip is not: it runs after the first frame, so the
    // stored list is already on screen while it happens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _adoptDeviceTags());
  }

  /// A Jota that has been used before already has tags on it. Nothing ever read
  /// them, so a phone with an empty list sat next to a device with five and the
  /// two never met.
  ///
  /// The phone owns the list, so the device's copy is adopted only when the
  /// phone has none of its own — a first pairing, or a reinstall. After that,
  /// app-first means app-first: the phone's list wins and gets pushed.
  Future<void> _adoptDeviceTags() async {
    if (!mounted || _tags.isNotEmpty) return;
    final DeviceController device = context.read<DeviceController>();
    if (!device.hasPairedDevice) return;

    setState(() => _readingDevice = true);
    final List<String>? fromDevice = await device.readDeviceTags();
    if (!mounted) return;

    // Re-check: the user may have added one while the radio was busy, and
    // their typing outranks anything we went looking for.
    final bool adopt =
        fromDevice != null && fromDevice.isNotEmpty && _tags.isEmpty;
    setState(() {
      _readingDevice = false;
      if (adopt) _tags = List<String>.of(fromDevice);
    });
    if (adopt) await context.read<Services>().settings.setTags(_tags);
  }

  Future<void> _edit(int index) async {
    final String? value = await promptForTag(context, initial: _tags[index]);
    if (value == null || !mounted) return;
    // Renaming a tag onto one that already exists would leave two identical
    // rows. Say why nothing happened rather than silently discarding the edit.
    if (value.isNotEmpty && value != _tags[index] && _tags.contains(value)) {
      _say(context, '$value is already a tag');
      return;
    }
    setState(() {
      if (value.isEmpty) {
        _tags.removeAt(index);
      } else {
        _tags[index] = value;
      }
    });
    await saveTags(context, _tags);
  }

  Future<void> _add() async {
    // The ceiling is the device's, so it is explained rather than enforced by a
    // button that has quietly gone grey.
    if (_tags.length >= kMaxTags) {
      _say(context, '$kMaxTags is the most your Jota holds');
      return;
    }
    final String? value = await promptForTag(context);
    if (value == null || value.isEmpty || !mounted) return;
    // The edit path has always refused duplicates; this one never did, so the
    // same tag could be added twice and the list would show it twice.
    if (_tags.contains(value)) {
      _say(context, '$value is already a tag');
      return;
    }
    setState(() => _tags.add(value));
    await saveTags(context, _tags);
  }

  /// Reordering is not decoration: the top [kDeviceTagSlots] are the ones Jota
  /// offers after a recording, so a drag changes what the device will show and
  /// has to be pushed like any other edit.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    // onReorderItem (not the deprecated onReorder) already reports newIndex
    // relative to the list AFTER the item is lifted out, so there is no
    // off-by-one to correct here.
    setState(() => _tags.insert(newIndex, _tags.removeAt(oldIndex)));
    await saveTags(context, _tags);
  }

  /// Most-used first. The top five are the ones the Jota offers after a
  /// recording, so "sort by use" really means "put the tags I reach for on
  /// the device". One tap, then drag to fine-tune. Stable, so tags with the
  /// same count keep their order.
  Future<void> _sortByUse() async {
    final Map<String, int> counts =
        _counts(context.read<NotesController>().notes);
    final List<String> sorted = List<String>.of(_tags)
      ..sort((String a, String b) => (counts[b] ?? 0) - (counts[a] ?? 0));
    if (_listEquals(sorted, _tags)) {
      _say(context, 'Already in order of use');
      return;
    }
    setState(() => _tags = sorted);
    await saveTags(context, _tags);
  }

  /// Swipe left. No dialog: the row is gone, the snackbar offers it back.
  /// Notes that carried the tag keep it as a label; only the list of choices
  /// changes.
  Future<void> _remove(int index) async {
    final String tag = _tags[index];
    setState(() => _tags.removeAt(index));
    // The offer to undo goes up BEFORE the save: the save's push to the
    // device can fail at once when the Jota is asleep, and its own message
    // would otherwise land on top of this one.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$tag removed'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              if (!mounted || _tags.contains(tag)) return;
              setState(
                () => _tags.insert(index.clamp(0, _tags.length), tag),
              );
              saveTags(context, _tags);
            },
          ),
        ),
      );
    await saveTags(context, _tags);
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// How many notes carry each tag. The count is the reason to keep a tag or
  /// drag it above the cut, so it is on the row rather than a screen away.
  Map<String, int> _counts(List<Note> notes) {
    final Map<String, int> counts = <String, int>{};
    for (final Note n in notes) {
      final String? tag = n.tag?.toUpperCase();
      if (tag == null || tag.isEmpty) continue;
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    final NotesController notes = context.watch<NotesController>();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The design's top strip: where you are, in the muted mono, with
            // the back affordance beside it. No rule under it — the screen's
            // one hairline belongs under the title.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                JotaGrid.margin,
                JotaGrid.gapS,
                JotaGrid.margin,
                0,
              ),
              child: SizedBox(
                height: JotaGrid.statusHeight,
                child: Row(
                  children: <Widget>[
                    if (!widget.embedded)
                      _BackChevron(onTap: () => Navigator.of(context).pop()),
                    const Spacer(),
                    Text(
                      'SETTINGS · TAGS',
                      style: t.cardLabel.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _tags.isEmpty && _readingDevice
                  ? Center(child: Text('Reading Jota…', style: t.label))
                  : TagList(
                      tags: _tags,
                      counts: _counts(notes.notes),
                      header: _TagsHeader(
                        onSortByUse: _tags.length > 1 ? _sortByUse : null,
                      ),
                      onEdit: _edit,
                      onReorder: _reorder,
                      onRemove: _remove,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                JotaGrid.margin,
                JotaGrid.gapM,
                JotaGrid.margin,
                JotaGrid.gapM,
              ),
              child: JotaButton(
                label: 'Add tag',
                upcase: false,
                onTap: _add,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The title block, above the list and scrolling with it: what this screen is,
/// and the one sentence that says the order is the setting.
class _TagsHeader extends StatelessWidget {
  const _TagsHeader({this.onSortByUse});

  /// Null hides the action: one tag has no order to sort.
  final VoidCallback? onSortByUse;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: Text('Tags', style: t.headline)),
            if (onSortByUse != null)
              // The same quiet text link as "Edit tags" on the note's tag
              // sheet: an action, not a mode, so it is not a stadium.
              GestureDetector(
                onTap: onSortByUse,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Sort by use',
                    style: t.prose.copyWith(color: c.inkMuted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: JotaGrid.gapS),
        Text(
          'Drag to reorder, swipe left to remove. '
          'Only the top five fit on the device.',
          style: t.prose.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: JotaGrid.gapM),
        const JotaRule(),
      ],
    );
  }
}

/// The back affordance, matching the one [JotaStatusBar] draws — these screens
/// build their own top strip because the design has no rule under it.
class _BackChevron extends StatelessWidget {
  const _BackChevron({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: JotaGrid.gapM),
          child: Icon(LucideIcons.arrowLeft, size: 18, color: context.ink.ink),
        ),
      ),
    );
  }
}

/// One-line feedback. The tag screens have no room for an error region and no
/// need for one — nothing here fails in a way you must act on.
void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Persist the tag list app-side, and — best effort, silent — push it to the
/// device when one is connected. It also gets pushed on the next sync. Shared by
/// the Tags tab and the first-run tag step.
Future<void> saveTags(BuildContext context, List<String> tags) async {
  final Services s = context.read<Services>();
  final DeviceController device = context.read<DeviceController>();
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  await s.settings.setTags(tags);
  if (!device.hasPairedDevice) return;

  // The phone is the source of truth, so the edit is already saved and the UI
  // must never wait on a radio for it. The push runs on its own — but it is no
  // longer silent when it fails: a write that lands nowhere used to be
  // indistinguishable from one that worked.
  unawaited(
    device.writeDeviceTags(tags).then((bool ok) {
      if (ok || !messenger.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saved here — Jota gets them at the next sync'),
        ),
      );
    }),
  );
}

/// The tag-entry bottom sheet. Returns the trimmed uppercase tag, `''` to remove
/// (edit mode only), or null if dismissed. Shared by the Tags tab and setup.
///
/// The controller belongs to [_TagSheet] rather than to this function. It used
/// to be disposed in a `whenComplete` on the sheet's future — but that future
/// completes when the route is POPPED, while the sheet keeps rebuilding through
/// its slide-out animation. Every dismissal therefore rebuilt a TextField whose
/// controller was already dead, and Flutter threw "A TextEditingController was
/// used after being disposed" over the top of the app.
Future<String?> promptForTag(BuildContext context, {String initial = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.ink.bg,
    builder: (BuildContext sheetContext) => _TagSheet(initial: initial),
  );
}

class _TagSheet extends StatefulWidget {
  const _TagSheet({required this.initial});

  final String initial;

  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  late final TextEditingController controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext sheetContext) {
    final String initial = widget.initial;
    return Padding(
      padding: EdgeInsets.only(
        left: JotaGrid.margin,
        right: JotaGrid.margin,
        top: JotaGrid.gapL,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + JotaGrid.gapL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Tag', style: context.type.label),
          const SizedBox(height: JotaGrid.gapM),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: context.type.label.copyWith(fontSize: 16),
            inputFormatters: <TextInputFormatter>[
              LengthLimitingTextInputFormatter(kMaxTagLength),
              // Tags appear on the device in its uppercase mono face, so
              // uppercase here: what you type is what shows on the e-paper.
              TextInputFormatter.withFunction(
                (TextEditingValue _, TextEditingValue next) =>
                    next.copyWith(text: next.text.toUpperCase()),
              ),
            ],
            decoration: const InputDecoration(hintText: 'WORK'),
            onSubmitted: (String v) => Navigator.of(sheetContext).pop(v.trim()),
          ),
          const SizedBox(height: JotaGrid.gapM),
          Row(
            children: <Widget>[
              if (initial.isNotEmpty) ...<Widget>[
                Expanded(
                  child: JotaButton(
                    label: 'Remove',
                    danger: true,
                    upcase: false,
                    height: JotaRows.heightCompact,
                    onTap: () => Navigator.of(sheetContext).pop(''),
                  ),
                ),
                const SizedBox(width: JotaRows.gap),
              ],
              Expanded(
                child: JotaButton(
                  label: 'Done',
                  primary: true,
                  upcase: false,
                  height: JotaRows.heightCompact,
                  onTap: () =>
                      Navigator.of(sheetContext).pop(controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The editable tag list — a row per tag, under [header].
///
/// Drag to reorder when [onReorder] is given, and the order is not cosmetic:
/// the top [kDeviceTagSlots] are the ones Jota will offer you after a
/// recording. A line across the list says where that cut falls, so the rule is
/// visible instead of documented — reordering IS the setting, and there is no
/// second switch to fall out of step with it. Everything under the line is
/// dimmed, which is the same statement made twice: those are not on the device.
///
/// The "add" affordance is NOT here. It is a button pinned to the bottom of the
/// screen, where the design puts it, so it stays reachable while the list
/// scrolls.
class TagList extends StatelessWidget {
  const TagList({
    super.key,
    required this.tags,
    required this.onEdit,
    this.counts = const <String, int>{},
    this.header,
    this.onReorder,
    this.onRemove,
    this.padding = const EdgeInsets.symmetric(horizontal: JotaGrid.margin),
  });

  final List<String> tags;
  final ValueChanged<int> onEdit;

  /// Notes per tag, keyed by the uppercase tag. A tag nothing carries yet shows
  /// a zero rather than a blank — an empty slot on the row would read as a
  /// missing figure, not as none.
  final Map<String, int> counts;

  /// Scrolls with the list, so the title leaves the screen as the rows arrive.
  final Widget? header;

  /// (oldIndex, newIndex) in the caller's own list. Null means a plain,
  /// non-draggable list — which is what the first-run step wants, since there
  /// is no device to send anything to yet.
  final void Function(int oldIndex, int newIndex)? onReorder;

  /// Swipe left to remove. Null means the rows do not swipe — the first-run
  /// step has nothing to remove yet.
  final ValueChanged<int>? onRemove;
  final EdgeInsets padding;

  Widget _row(BuildContext context, int i, {required bool belowCut}) {
    final Widget row = _TagRow(
      name: tags[i],
      count: counts[tags[i]] ?? 0,
      // The grip is the drag affordance and the row itself is the edit one, so
      // a press on the left edge sorts and a tap anywhere else renames.
      //
      // Drawn from dots rather than an icon-set glyph. The design sheet shows
      // `⠿`, which is a braille character none of the bundled Plex faces
      // carries — on the phone it would render as a tofu box. Six circles are
      // the same mark, in the product's own vocabulary, and need no font.
      //
      // When the list cannot be sorted there is nothing to grip, so the slot is
      // simply empty: the pencil that used to sit there was decoration for an
      // affordance the whole row already provides.
      handle: onReorder == null
          ? const SizedBox(width: 16)
          : ReorderableDragStartListener(
              index: i,
              child: const _GripDots(),
            ),
      onTap: () => onEdit(i),
    );
    final Widget dimmed = belowCut ? Opacity(opacity: 0.45, child: row) : row;
    if (onRemove == null) return dimmed;
    // The same gesture as a note in the archive: the row slides out and the
    // list closes the gap. One word uncovered, in the signal colour, because
    // it is the destructive one.
    return Dismissible(
      key: ValueKey<String>('remove-${tags[i]}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.endToStart: 0.35,
      },
      background: const _RemoveHint(),
      onDismissed: (_) => onRemove!(i),
      child: dimmed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showCut = tags.length > kDeviceTagSlots;

    if (onReorder == null) {
      return ListView(
        padding: padding,
        children: <Widget>[
          if (header != null) header!,
          for (int i = 0; i < tags.length; i++) ...<Widget>[
            _row(context, i, belowCut: showCut && i >= kDeviceTagSlots),
            if (showCut && i == kDeviceTagSlots - 1) const _DeviceCutLine(),
          ],
        ],
      );
    }

    return ReorderableListView.builder(
      padding: padding,
      header: header,
      buildDefaultDragHandles: false,
      itemCount: tags.length,
      onReorderItem: onReorder!,
      // The cut line is a footer of the row above it rather than its own list
      // item: ReorderableListView requires every child to be reorderable and
      // keyed, and a divider that could be dragged is nonsense.
      itemBuilder: (BuildContext context, int i) {
        return Column(
          key: ValueKey<String>('tag-${tags[i]}-$i'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _row(context, i, belowCut: showCut && i >= kDeviceTagSlots),
            if (showCut && i == kDeviceTagSlots - 1) const _DeviceCutLine(),
          ],
        );
      },
    );
  }
}

/// What a swipe uncovers: REMOVE, right-aligned, on the field colour.
class _RemoveHint extends StatelessWidget {
  const _RemoveHint();

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return Container(
      color: c.field,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: JotaGrid.gapM),
      child: Text(
        'REMOVE',
        style: context.type.label.copyWith(
          color: c.signal,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Grip, name, count, hairline. Flat like the settings rows: nothing in this
/// list is selected, so nothing here is a stadium.
/// Two columns of three dots — the drag handle, in circles, which is the only
/// mark vocabulary this product has.
class _GripDots extends StatelessWidget {
  const _GripDots();

  @override
  Widget build(BuildContext context) {
    final Color c = context.ink.inkMuted;
    Widget dot() => Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    Widget column() => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: <Widget>[dot(), dot(), dot()],
        );
    return SizedBox(
      width: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 3,
        children: <Widget>[column(), column()],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.name,
    required this.count,
    required this.handle,
    required this.onTap,
  });

  final String name;
  final int count;
  final Widget handle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                children: <Widget>[
                  IconTheme(
                    data: IconThemeData(color: c.inkMuted, size: 16),
                    child: handle,
                  ),
                  const SizedBox(width: JotaGrid.gapM),
                  Expanded(
                    child: Text(
                      name,
                      style: t.prose,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: JotaGrid.gapM),
                  Text('$count', style: t.meta.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            const JotaRule(),
          ],
        ),
      ),
    );
  }
}

/// "Everything above this goes to Jota." A hairline with a label in it, in the
/// muted ink — this is information, not a warning, so it never takes the
/// accent.
class _DeviceCutLine extends StatelessWidget {
  const _DeviceCutLine();

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    return Padding(
      padding: const EdgeInsets.only(top: JotaGrid.gapM, bottom: JotaGrid.gapS),
      child: Row(
        children: <Widget>[
          Expanded(child: Container(height: JotaGrid.hairline, color: c.rule)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: JotaGrid.gapM),
            child: Text(
              'ON JOTA ↑',
              // Mono: it is a label on a rule, the same voice as every other
              // piece of chrome on this screen.
              style: t.cardLabel.copyWith(color: c.inkMuted),
            ),
          ),
          Expanded(child: Container(height: JotaGrid.hairline, color: c.rule)),
        ],
      ),
    );
  }
}
