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

  @override
  void initState() {
    super.initState();
    // The list is a synchronous prefs read — no loading state needed.
    _tags = List<String>.of(context.read<Services>().settings.tags);
  }

  Future<void> _edit(int index) async {
    final String? value = await promptForTag(context, initial: _tags[index]);
    if (value == null || !mounted) return;
    // Renaming a tag onto one that already exists would leave two identical
    // rows — the add path forbids duplicates, so the edit path must too. Leave
    // the list unchanged rather than create the collision.
    if (value.isNotEmpty && value != _tags[index] && _tags.contains(value)) {
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
    setState(() => _tags.add(value));
    await saveTags(context, _tags);
  }

  @override
  Widget build(BuildContext context) {
    return JotaScreen(
      label: 'Tags',
      upcase: false,
      onBack: widget.embedded ? null : () => Navigator.of(context).pop(),
      child: TagList(
        tags: _tags,
        onEdit: _edit,
        onAdd: _tags.length < kMaxTags ? _add : null,
      ),
    );
  }
}

/// Persist the tag list app-side, and — best effort, silent — push it to the
/// device when one is connected. It also gets pushed on the next sync. Shared by
/// the Tags tab and the first-run tag step.
Future<void> saveTags(BuildContext context, List<String> tags) async {
  final Services s = context.read<Services>();
  final DeviceController device = context.read<DeviceController>();
  await s.settings.setTags(tags);
  if (device.hasPairedDevice) {
    unawaited(device.writeDeviceTags(tags));
  }
}

/// The tag-entry bottom sheet. Returns the trimmed uppercase tag, `''` to remove
/// (edit mode only), or null if dismissed. Shared by the Tags tab and setup.
Future<String?> promptForTag(BuildContext context, {String initial = ''}) {
  final TextEditingController controller = TextEditingController(text: initial);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.ink.bg,
    builder: (BuildContext sheetContext) {
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
              onSubmitted: (String v) =>
                  Navigator.of(sheetContext).pop(v.trim()),
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
    },
  ).whenComplete(controller.dispose);
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
