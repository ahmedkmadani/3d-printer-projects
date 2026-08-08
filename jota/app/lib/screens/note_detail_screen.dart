// ============================================================================
//  Jota — note detail
//
//  The direct descendant of the device's NOTE VIEW screen (screens.cpp,
//  screenNoteView): `N-012` in the status label, `004/012` in the right slot,
//  the note's own time and duration on a meta line below the hairline, and the
//  transcript in sans underneath.
//
//  The device stops there because it has 200x200 pixels. The phone adds the two
//  things it can afford: playback, and a tag.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/note.dart';
import '../design/format.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/notes_controller.dart';
import '../state/services.dart';
import 'widgets/playback_bar.dart';

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

    final int pos = notes.positionOf(_note);
    final int total = notes.visible.length;

    return JotaScreen(
      // The note's OWN id is the label — this screen is about one note.
      label: _note.displayId,
      // The right slot holds position in the list, matching the device exactly.
      value: fmtRatio(pos, total),
      onBack: () => Navigator.of(context).pop(),
      child: ListView(
        padding: const EdgeInsets.only(top: JotaGrid.gapM),
        children: <Widget>[
          // The note's time and duration live in the BODY, not in the status
          // slot — up there they would masquerade as the live clock.
          JotaMetaLine(
            left: fmtClock(_note.recordedAt),
            right: _note.displayDuration,
          ),
          const SizedBox(height: JotaGrid.gapL),

          PlaybackBar(
            key: ValueKey<String>('${_note.deviceId}/${_note.noteId}'),
            audio: services.audio,
            deviceId: _note.deviceId,
            noteId: _note.noteId,
            durationSeconds: _note.secs,
          ),
          const SizedBox(height: JotaGrid.gapL),
          const JotaRule(),
          const SizedBox(height: JotaGrid.gapL),

          _TranscriptBlock(
            note: _note,
            transcribing: notes.isTranscribing(_note),
            onTranscribe: () => notes.transcribe(_note),
            onEdit: () => _editTranscript(context, notes),
          ),

          const SizedBox(height: JotaGrid.gapXL),
          const JotaRule(),
          const SizedBox(height: JotaGrid.gapM),

          _TagPicker(
            tags: notes.tagsInUse,
            selected: _note.tag,
            onSelect: (String? tag) => notes.setTag(_note, tag),
          ),

          const SizedBox(height: JotaGrid.gapXL),

          // Technical facts, in mono, aligned by the monospace grid alone.
          JotaKeyValue(name: 'ID', value: _note.displayId),
          JotaKeyValue(name: 'Recorded', value: fmtDate(_note.recordedAt)),
          JotaKeyValue(name: 'Size', value: fmtBytes(_note.bytes)),
          JotaKeyValue(name: 'CRC', value: _note.crc),
          if (_note.transcriptModel != null)
            JotaKeyValue(name: 'Model', value: _note.transcriptModel!),

          const SizedBox(height: JotaGrid.gapXL),
          JotaButton(
            label: 'Delete note',
            danger: true,
            height: JotaRows.heightCompact,
            onTap: () => _confirmDelete(context, notes),
          ),
          const SizedBox(height: JotaGrid.gapXL),

          if (_note.transcriptError != null)
            Text(
              _note.transcriptError!,
              style: t.reading.copyWith(color: c.signal),
            ),
        ],
      ),
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
              Text('TRANSCRIPT', style: context.type.label),
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
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('DELETE ${_note.displayId}', style: context.type.label),
          content: Text(
            'The device has already dropped its copy and there is no server. '
            'This cannot be undone.',
            style: context.type.prose,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('CANCEL', style: context.type.label),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'DELETE',
                style: context.type.label.copyWith(color: context.ink.signal),
              ),
            ),
          ],
        );
      },
    );

    if (yes == true && context.mounted) {
      await notes.delete(_note);
      if (context.mounted) Navigator.of(context).pop();
    }
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
            // device gives in screens.cpp.
            Text(note.transcript!, style: t.prose),
            const SizedBox(height: JotaGrid.gapM),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                note.transcriptState == TranscriptState.manual
                    ? 'EDITED BY HAND'
                    : 'HOLD TO EDIT',
                style: t.reading.copyWith(color: c.inkMuted, fontSize: 11),
              ),
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
              : 'NO TRANSCRIPT',
          style: t.reading.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: JotaGrid.gapM),
        Row(
          children: <Widget>[
            Expanded(
              child: JotaButton(
                label: 'Transcribe',
                primary: true,
                height: JotaRows.heightCompact,
                onTap: onTranscribe,
              ),
            ),
            const SizedBox(width: JotaRows.gap),
            Expanded(
              child: JotaButton(
                label: 'Type it',
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

class _TagPicker extends StatelessWidget {
  const _TagPicker({
    required this.tags,
    required this.selected,
    required this.onSelect,
  });

  final List<String> tags;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Text(
        'NO TAGS — ADD THEM IN THE TAG EDITOR',
        style: context.type.reading.copyWith(color: context.ink.inkMuted),
      );
    }
    return Wrap(
      spacing: JotaRows.gap,
      runSpacing: JotaRows.gap,
      children: <Widget>[
        for (final String tag in tags)
          IntrinsicWidth(
            child: JotaRow(
              label: tag,
              selected: selected == tag,
              height: JotaRows.heightCompact,
              onTap: () => onSelect(selected == tag ? null : tag),
            ),
          ),
      ],
    );
  }
}
