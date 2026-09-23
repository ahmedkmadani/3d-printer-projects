// ============================================================================
//  Jota — the two things you can do to a note from anywhere
//
//  Share and delete, in one place, so the swipe on the list and the buttons
//  on the note's own screen cannot drift apart in wording or behaviour.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/note.dart';
import '../../design/format.dart';
import '../../design/theme.dart';

/// Hand the transcript to the system share sheet as plain text. The words are
/// the note; the audio stays where it is.
Future<void> shareNote(BuildContext context, Note note) async {
  if (!note.hasTranscript) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Nothing to share until it is transcribed')),
      );
    return;
  }
  final String tag = note.tag == null ? '' : ' · ${note.tag}';
  await SharePlus.instance.share(
    ShareParams(
      text: note.transcript!.trim(),
      subject: 'Jota ${fmtNoteStamp(note.recordedAt)}$tag',
    ),
  );
}

/// Ask before deleting. There is no undo: the Jota let go of its copy at
/// sync, so the phone's is the only one.
Future<bool> confirmDeleteNote(BuildContext context) async {
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('Delete this note?', style: context.type.headline),
        content: Text(
          'Your Jota has already let go of its copy, so this can’t be undone.',
          style: context.type.prose,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: context.type.label),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: context.type.label.copyWith(color: context.ink.signal),
            ),
          ),
        ],
      );
    },
  );
  return yes == true;
}
