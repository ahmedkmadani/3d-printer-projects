// A swipe hides the note at once and deletes it a few seconds later —
// unless it is called back. The phone holds the only copy.
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/data/note.dart';
import 'package:jota/preview/fake_transcriber.dart';
import 'package:jota/preview/in_memory_stores.dart';
import 'package:jota/state/notes_controller.dart';
import 'package:jota/transcribe/transcription_queue.dart';

Note _note(int id) => Note(
      deviceId: 'dev-1',
      noteId: id,
      recordedAt: DateTime.utc(2026, 9, 23, 18, id),
      secs: 5,
      bytes: 100,
      crc: 'deadbeef',
      adpcmPath: '/nowhere/$id.ima',
      transcript: 'note $id',
      transcriptState: TranscriptState.done,
      syncedAt: DateTime.utc(2026, 9, 23, 19),
    );

void main() {
  late InMemoryNoteRepository repo;
  late NotesController notes;

  setUp(() async {
    final InMemoryAudioStore audio = InMemoryAudioStore();
    repo = InMemoryNoteRepository(audio);
    final InMemorySettingsStore settings = InMemorySettingsStore();
    await repo.insert(_note(1));
    await repo.insert(_note(2));
    notes = NotesController(
      repository: repo,
      transcription: TranscriptionQueue(
        notes: repo,
        audio: audio,
        settings: settings,
        transcriber: () => FakeTranscriber(settings),
      ),
    );
    await notes.refresh();
  });

  tearDown(() => notes.dispose());

  test('a scheduled delete hides the note at once and can be undone', () async {
    final Note n = notes.notes.first;
    notes.scheduleDelete(n, delay: const Duration(seconds: 30));
    expect(notes.visible.map((Note x) => x.noteId), isNot(contains(n.noteId)));
    expect(await repo.count(), 2, reason: 'nothing deleted yet');

    expect(notes.undoDelete(n), isTrue);
    expect(notes.visible.map((Note x) => x.noteId), contains(n.noteId));
    expect(notes.undoDelete(n), isFalse, reason: 'nothing left to undo');
  });

  test('a scheduled delete that is not undone goes through', () async {
    final Note n = notes.notes.first;
    notes.scheduleDelete(n, delay: const Duration(milliseconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await repo.count(), 1);
    expect(notes.notes.map((Note x) => x.noteId), isNot(contains(n.noteId)));
  });
}
