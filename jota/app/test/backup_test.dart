// ============================================================================
//  Jota — backup file
//
//  The backup is the only copy of the archive that can leave the phone, so
//  its shape is pinned here: every field a note has that is worth keeping,
//  and nothing that is not (no paths, no CRCs, no audio).
// ============================================================================
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jota/data/note.dart';
import 'package:jota/export/backup.dart';

void main() {
  test('backup carries the words, the tag and the stamp of every note', () {
    final Note a = Note(
      deviceId: 'dev-1',
      noteId: 12,
      recordedAt: DateTime.utc(2026, 9, 23, 18, 31),
      secs: 47,
      bytes: 1000,
      crc: 'deadbeef',
      adpcmPath: '/nowhere/0012.ima',
      tag: 'WORK',
      transcript: 'call the dentist',
      transcriptState: TranscriptState.done,
      transcriptModel: 'whisper-small',
      syncedAt: DateTime.utc(2026, 9, 23, 18, 40),
    );
    final Note b = Note(
      deviceId: 'dev-1',
      noteId: 13,
      recordedAt: DateTime.utc(2026, 9, 23, 18, 55),
      secs: 4,
      bytes: 100,
      crc: '00000000',
      adpcmPath: '/nowhere/0013.ima',
      syncedAt: DateTime.utc(2026, 9, 23, 19, 0),
    );

    final String json =
        notesBackupJson(<Note>[b, a], now: DateTime.utc(2026, 9, 23, 20));
    final Map<String, Object?> doc = jsonDecode(json) as Map<String, Object?>;

    expect(doc['app'], 'jota');
    expect(doc['format'], 1);
    expect(doc['exported_at'], '2026-09-23T20:00:00.000Z');

    final List<Object?> notes = doc['notes'] as List<Object?>;
    expect(notes.length, 2);

    final Map<String, Object?> first = notes[0] as Map<String, Object?>;
    expect(first['id'], 'N-013');
    expect(first['tag'], isNull);
    expect(first['transcript'], isNull);
    expect(first['transcript_state'], 'pending');

    final Map<String, Object?> second = notes[1] as Map<String, Object?>;
    expect(second['device_id'], 'dev-1');
    expect(second['note_id'], 12);
    expect(second['recorded_at'], '2026-09-23T18:31:00.000Z');
    expect(second['seconds'], 47);
    expect(second['tag'], 'WORK');
    expect(second['transcript'], 'call the dentist');
    expect(second['transcript_state'], 'done');
    expect(second['transcript_model'], 'whisper-small');

    // Nothing that only makes sense on this phone.
    expect(second.containsKey('adpcm_path'), isFalse);
    expect(second.containsKey('crc'), isFalse);
  });
}
