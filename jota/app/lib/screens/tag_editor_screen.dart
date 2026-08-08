// ============================================================================
//  Jota — tag editor
//
//  The device's TAGS screen is five stadium rows with one inverted. This is the
//  same list, editable, plus the two limits from the contract made visible
//  rather than enforced silently: max 8 tags, 12 characters each.
//
//  Reads `tags` on open, writes the WHOLE list back on save — the
//  characteristic replaces rather than merges, so a partial write would delete
//  whatever it omitted.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ble/jota_protocol.dart';
import '../design/format.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/notes_controller.dart';

class TagEditorScreen extends StatefulWidget {
  const TagEditorScreen({super.key});

  @override
  State<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends State<TagEditorScreen> {
  List<String> _tags = <String>[];
  bool _loading = true;
  bool _saving = false;
  bool _fromDevice = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final DeviceController device = context.read<DeviceController>();
    final NotesController notes = context.read<NotesController>();

    final List<String>? fromDevice = await device.readDeviceTags();
    if (!mounted) return;

    setState(() {
      // The device is the source of truth when it is reachable. When it is not,
      // fall back to the tags already in use locally so the screen is still
      // useful out of range.
      _tags = fromDevice ?? notes.tagsInUse;
      _fromDevice = fromDevice != null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final bool ok =
        await context.read<DeviceController>().writeDeviceTags(_tags);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? null : 'Could not reach the device. Tags not saved.';
    });
    if (ok && mounted) Navigator.of(context).pop();
  }

  void _edit(int index) async {
    final String? value = await _promptForTag(initial: _tags[index]);
    if (value == null) return;
    setState(() {
      if (value.isEmpty) {
        _tags.removeAt(index);
      } else {
        _tags[index] = value;
      }
    });
  }

  void _add() async {
    final String? value = await _promptForTag();
    if (value == null || value.isEmpty) return;
    setState(() => _tags.add(value));
  }

  Future<String?> _promptForTag({String initial = ''}) {
    final TextEditingController controller =
        TextEditingController(text: initial);

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
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + JotaGrid.gapL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('TAG', style: context.type.label),
                  Text(
                    'MAX $kMaxTagLength',
                    style: context.type.reading
                        .copyWith(color: context.ink.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: JotaGrid.gapM),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: context.type.label.copyWith(fontSize: 16),
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(kMaxTagLength),
                  // Tags are shown in the device's `label` face, which is
                  // uppercase mono. Uppercase here so what you type is what
                  // appears on the e-paper.
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
                      height: JotaRows.heightCompact,
                      onTap: () => Navigator.of(sheetContext)
                          .pop(controller.text.trim()),
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

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return JotaScreen(
      label: 'TAGS',
      // The right slot holds the one defining figure: how full the list is.
      value: fmtRatio(_tags.length, kMaxTags),
      onBack: () => Navigator.of(context).pop(),
      footer: JotaButton(
        label: 'Save to device',
        primary: true,
        busy: _saving,
        onTap: _loading ? null : _save,
      ),
      child: _loading
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(top: JotaGrid.gapL),
              children: <Widget>[
                Text(
                  _fromDevice ? 'FROM DEVICE' : 'LOCAL ONLY — DEVICE NOT FOUND',
                  style: t.reading.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: JotaGrid.gapL),
                for (int i = 0; i < _tags.length; i++) ...<Widget>[
                  JotaRow(
                    label: _tags[i],
                    leading: Text(
                      fmtCount(i + 1),
                      style: t.reading.copyWith(color: c.inkMuted),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _edit(i),
                  ),
                  const SizedBox(height: JotaRows.gap),
                ],
                if (_tags.length < kMaxTags)
                  JotaRow(
                    label: 'ADD TAG',
                    onTap: _add,
                    trailing: const Icon(Icons.add),
                  )
                else
                  Text(
                    'THE DEVICE HOLDS $kMaxTags TAGS',
                    style: t.reading.copyWith(color: c.inkMuted),
                  ),
                const SizedBox(height: JotaGrid.gapXL),
                Text(
                  'Jota shows five rows at a time and stores up to $kMaxTags '
                  'tags of $kMaxTagLength characters. Saving replaces the whole '
                  'list on the device.',
                  style: t.prose.copyWith(color: c.inkMuted, fontSize: 14),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: JotaGrid.gapM),
                  Text(_error!, style: t.reading.copyWith(color: c.signal)),
                ],
              ],
            ),
    );
  }
}
