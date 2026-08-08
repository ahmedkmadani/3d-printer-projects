// ============================================================================
//  Jota — note repository interface
//
//  The archive lives on the phone. Screens and the sync engine talk in Notes and
//  never in rows, which is what lets the storage underneath be sqflite (see
//  SqfliteNoteRepository), an in-memory map (see lib/preview/), or drift later,
//  without a single caller changing.
// ============================================================================
import 'note.dart';

abstract class NoteRepository {
  // ---- reads --------------------------------------------------------------

  /// Newest first. The list screen's only query.
  Future<List<Note>> all();

  Future<List<Note>> withTag(String tag);

  Future<Note?> byId(String deviceId, int noteId);

  /// Which of the device's ids we already hold, so a sync can skip them rather
  /// than re-downloading a note whose ack was lost on the way out.
  Future<Set<int>> knownIds(String deviceId);

  /// The transcription queue: everything stored but not yet turned into text,
  /// oldest first, so a backlog drains in the order it was recorded.
  Future<List<Note>> awaitingTranscription({int limit});

  Future<int> count();

  /// Every tag actually in use locally. Merged with the device's list in the
  /// tag editor, so a tag written on one side is visible on the other.
  Future<List<String>> tagsInUse();

  // ---- writes -------------------------------------------------------------

  /// Insert a freshly synced note.
  ///
  /// Must be idempotent on (deviceId, noteId) and must NOT clobber an existing
  /// transcript: a duplicate here means an ack was lost and the device offered
  /// the note twice, which is a normal outcome of the resume protocol.
  Future<Note> insert(Note note);

  Future<void> update(Note note);

  Future<void> setTag(Note note, String? tag);

  Future<void> setTranscriptState(
    Note note,
    TranscriptState state, {
    String? error,
  });

  Future<void> setTranscript(
    Note note,
    String text, {
    String? model,
    bool manual,
  });

  /// Deletes the row AND the audio. There is no server copy and the device has
  /// already dropped its own, so this is permanent — callers must confirm first.
  Future<void> delete(Note note);

  // ---- partial bookkeeping ------------------------------------------------
  // The bytes live in a PartialStore; this is the metadata saying what they are
  // supposed to add up to.

  Future<void> rememberPartial({
    required String deviceId,
    required int noteId,
    required int expectedBytes,
    required String crc,
    required int secs,
    required int recordedAt,
  });

  /// Bumped every time a note's transfer fails its CRC. A note that keeps
  /// failing is a hardware or firmware problem, and the UI should say so rather
  /// than looping forever.
  Future<int> bumpPartialAttempts(String deviceId, int noteId);

  Future<void> forgetPartial(String deviceId, int noteId);

  /// Notes we hold bytes for but never finished.
  Future<List<int>> unfinishedNoteIds(String deviceId);

  /// Release whatever the implementation is holding open.
  Future<void> close();
}
