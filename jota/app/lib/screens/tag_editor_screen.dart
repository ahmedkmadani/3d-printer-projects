// ============================================================================
//  Jota — tags
//
//  App-first. Your tags live on the phone and are editable any time, with or
//  without the device. Every change is saved instantly; when a Jota is
//  connected, the same list is pushed to it so the e-paper agrees.
//
//  Max 8 tags, 12 characters each — the device's limits, shown rather than
//  enforced silently.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../ble/jota_protocol.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    return JotaScreen(
      label: 'Tags',
      upcase: false,
      onBack: widget.embedded ? null : () => Navigator.of(context).pop(),
      child: _tags.isEmpty && _readingDevice
          ? Center(
              child: Text('Reading Jota…', style: context.type.label),
            )
          : TagList(
              tags: _tags,
              onEdit: _edit,
              onAdd: _tags.length < kMaxTags ? _add : null,
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

/// The editable tag list — a row per tag plus an "Add a tag" row (when [onAdd]
/// is non-null). Shared by the Tags tab and the first-run tag-setup step.
class TagList extends StatelessWidget {
  const TagList({
    super.key,
    required this.tags,
    required this.onEdit,
    required this.onAdd,
    this.padding = const EdgeInsets.only(top: JotaGrid.gapL),
  });

  final List<String> tags;
  final ValueChanged<int> onEdit;
  final VoidCallback? onAdd;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: <Widget>[
        for (int i = 0; i < tags.length; i++) ...<Widget>[
          JotaRow(
            label: tags[i],
            trailing: const Icon(LucideIcons.pencil),
            onTap: () => onEdit(i),
          ),
          const SizedBox(height: JotaRows.gap),
        ],
        if (onAdd != null)
          JotaRow(
            label: 'Add a tag',
            onTap: onAdd,
            trailing: const Icon(LucideIcons.plus),
          ),
      ],
    );
  }
}
