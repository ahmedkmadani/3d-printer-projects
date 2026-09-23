// ============================================================================
//  Jota — backup
//
//  The archive lives on this phone and nowhere else: no server, and the Jota
//  let go of its copy at sync. A phone lost is every note lost. This is the
//  cheapest insurance that exists — one JSON file, handed to the share sheet,
//  which the user can put wherever they keep things.
//
//  Words only. The audio is the ADPCM archive and would make the file a
//  hundred times larger; the transcript is what anyone comes back for.
// ============================================================================
import 'dart:convert';

import '../data/note.dart';

/// One object per note, newest first as given. Dates are ISO-8601 in UTC so
/// the file reads the same on any machine that opens it.
String notesBackupJson(List<Note> notes, {DateTime? now}) {
  final Map<String, Object?> doc = <String, Object?>{
    'app': 'jota',
    'format': 1,
    'exported_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'notes': <Map<String, Object?>>[
      for (final Note n in notes)
        <String, Object?>{
          'device_id': n.deviceId,
          'note_id': n.noteId,
          'id': n.displayId,
          'recorded_at': n.recordedAt.toUtc().toIso8601String(),
          'seconds': n.secs,
          'tag': n.tag,
          'transcript': n.transcript,
          'transcript_state': n.transcriptState.name,
          'transcript_model': n.transcriptModel,
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(doc);
}
