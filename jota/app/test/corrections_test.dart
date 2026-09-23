// ============================================================================
//  Jota — corrections export
//
//  A hand edit must keep the model's words, or there is nothing to export;
//  and the manifest line must carry both, plus the audio name the WAV is
//  stored under, or the fine-tune script has nothing to pair.
// ============================================================================
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jota/data/note.dart';
import 'package:jota/export/corrections.dart';
import 'package:jota/preview/in_memory_stores.dart';

Note _note() => Note(
      deviceId: 'dev-1',
      noteId: 12,
      recordedAt: DateTime.utc(2026, 9, 23, 18, 31),
      secs: 18,
      bytes: 1000,
      crc: 'deadbeef',
      adpcmPath: '/nowhere/0012.ima',
      syncedAt: DateTime.utc(2026, 9, 23, 18, 40),
    );

void main() {
  test('a hand edit keeps what the model said, once', () async {
    final InMemoryNoteRepository repo =
        InMemoryNoteRepository(InMemoryAudioStore());
    final Note stored = await repo.insert(_note());

    await repo.setTranscript(stored, 'the model herd this', model: 'whisper');
    Note n = (await repo.byId('dev-1', 12))!;
    expect(n.machineTranscript, 'the model herd this');
    expect(n.isCorrected, isFalse);

    await repo.setTranscript(n, 'the model heard this', manual: true);
    n = (await repo.byId('dev-1', 12))!;
    expect(n.transcript, 'the model heard this');
    expect(n.machineTranscript, 'the model herd this');
    expect(n.isCorrected, isTrue);

    // A second edit is the user's own; the "before" stays the model's.
    await repo.setTranscript(n, 'the model heard this!', manual: true);
    n = (await repo.byId('dev-1', 12))!;
    expect(n.machineTranscript, 'the model herd this');

    // A re-run replaces it, so the next correction pairs with the new model.
    await repo.setTranscript(n, 'the model heard that', model: 'whisper-2');
    n = (await repo.byId('dev-1', 12))!;
    expect(n.machineTranscript, 'the model heard that');
    expect(n.isCorrected, isFalse);
  });

  test('a manifest line pairs the audio with both texts', () {
    final Note n = _note().copyWith(
      transcript: 'what was meant',
      transcriptState: TranscriptState.manual,
      transcriptModel: 'whisper-small',
      machineTranscript: 'what was herd',
    );
    final Map<String, Object?> line =
        jsonDecode(correctionManifestLine(n, language: 'ar'))
            as Map<String, Object?>;
    expect(line['audio'], 'dev-1_N-012.wav');
    expect(line['machine'], 'what was herd');
    expect(line['text'], 'what was meant');
    expect(line['model'], 'whisper-small');
    expect(line['language'], 'ar');
    expect(line['seconds'], 18);
    expect(line['recorded_at'], '2026-09-23T18:31:00.000Z');
  });
}
