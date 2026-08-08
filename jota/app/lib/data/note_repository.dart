// ============================================================================
//  Jota — note repository
//
//  The only thing that touches SQL. Screens and the sync engine talk in Notes.
//  If this ever becomes drift, this file is the whole blast radius.
// ============================================================================
import 'package:sqflite/sqflite.dart';

import 'audio_store.dart';
import 'database.dart';
import 'note.dart';

class NoteRepository {
  NoteRepository(this._db, this._audio);

  final Database _db;
  final AudioStore _audio;

  // ---- reads --------------------------------------------------------------

  /// Newest first. The list screen's only query.
  Future<List<Note>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      orderBy: 'recorded_at DESC, note_id DESC',
    );
    return rows.map(Note.fromRow).toList();
  }

  Future<List<Note>> withTag(String tag) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      where: 'tag = ?',
      whereArgs: <Object?>[tag],
      orderBy: 'recorded_at DESC',
    );
    return rows.map(Note.fromRow).toList();
  }

  Future<Note?> byId(String deviceId, int noteId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      where: 'device_id = ? AND note_id = ?',
      whereArgs: <Object?>[deviceId, noteId],
      limit: 1,
    );
    return rows.isEmpty ? null : Note.fromRow(rows.first);
  }

  /// Which of the device's ids we already hold, so a sync can skip them
  /// entirely rather than re-downloading a note whose ack was lost.
  Future<Set<int>> knownIds(String deviceId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      columns: <String>['note_id'],
      where: 'device_id = ?',
      whereArgs: <Object?>[deviceId],
    );
    return rows.map((Map<String, Object?> r) => r['note_id']! as int).toSet();
  }

  /// The transcription queue: everything stored but not yet turned into text.
  /// Oldest first, so a backlog drains in the order it was recorded.
  Future<List<Note>> awaitingTranscription({int limit = 20}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      where: 'transcript_state IN (?, ?)',
      whereArgs: <Object?>[
        TranscriptState.pending.name,
        TranscriptState.failed.name,
      ],
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
    return rows.map(Note.fromRow).toList();
  }

  Future<int> count() async {
    final List<Map<String, Object?>> r = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${JotaDatabase.notes}',
    );
    return (r.first['n'] as int?) ?? 0;
  }

  /// Every tag actually in use locally. Merged with the device's list in the
  /// tag editor so a tag written on one side is visible on the other.
  Future<List<String>> tagsInUse() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT DISTINCT tag FROM ${JotaDatabase.notes} '
      "WHERE tag IS NOT NULL AND tag != '' ORDER BY tag ASC",
    );
    return rows
        .map((Map<String, Object?> r) => r['tag'] as String? ?? '')
        .where((String s) => s.isNotEmpty)
        .toList();
  }

  // ---- writes -------------------------------------------------------------

  /// Insert a freshly synced note.
  ///
  /// `ignore` on conflict, not `replace`: if the row somehow already exists we
  /// keep the transcript we have rather than blanking it. A duplicate here
  /// means an ack was lost and the device offered the note twice, which is a
  /// normal outcome of the resume protocol, not an error.
  Future<Note> insert(Note note) async {
    final int rowId = await _db.insert(
      JotaDatabase.notes,
      note.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (rowId == 0) {
      final Note? existing = await byId(note.deviceId, note.noteId);
      if (existing != null) return existing;
    }
    return note.copyWith(rowId: rowId);
  }

  Future<void> update(Note note) async {
    await _db.update(
      JotaDatabase.notes,
      note.toRow(),
      where: 'device_id = ? AND note_id = ?',
      whereArgs: <Object?>[note.deviceId, note.noteId],
    );
  }

  Future<void> setTag(Note note, String? tag) =>
      update(note.copyWith(tag: tag, clearTag: tag == null));

  Future<void> setTranscriptState(
    Note note,
    TranscriptState state, {
    String? error,
  }) {
    return update(
      note.copyWith(
        transcriptState: state,
        transcriptError: error,
        clearTranscriptError: error == null,
      ),
    );
  }

  Future<void> setTranscript(
    Note note,
    String text, {
    String? model,
    bool manual = false,
  }) {
    return update(
      note.copyWith(
        transcript: text,
        transcriptState: manual ? TranscriptState.manual : TranscriptState.done,
        transcriptModel: model,
        clearTranscriptError: true,
      ),
    );
  }

  /// Deletes the row AND the audio. There is no server copy and the device has
  /// already dropped its own, so this is permanent — the UI must confirm first.
  Future<void> delete(Note note) async {
    await _db.delete(
      JotaDatabase.notes,
      where: 'device_id = ? AND note_id = ?',
      whereArgs: <Object?>[note.deviceId, note.noteId],
    );
    await _audio.deleteNote(note.deviceId, note.noteId);
  }

  // ---- partial bookkeeping ------------------------------------------------
  // The bytes live in PartialStore; this is the metadata that says what they
  // are supposed to become.

  Future<void> rememberPartial({
    required String deviceId,
    required int noteId,
    required int expectedBytes,
    required String crc,
    required int secs,
    required int recordedAt,
  }) async {
    await _db.insert(
      JotaDatabase.partials,
      <String, Object?>{
        'device_id': deviceId,
        'note_id': noteId,
        'expected_bytes': expectedBytes,
        'crc': crc,
        'secs': secs,
        'recorded_at': recordedAt,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Bumped every time a note's transfer fails its CRC. A note that keeps
  /// failing is a hardware or firmware problem, and the UI should say so rather
  /// than looping forever.
  Future<int> bumpPartialAttempts(String deviceId, int noteId) async {
    await _db.rawUpdate(
      'UPDATE ${JotaDatabase.partials} SET attempts = attempts + 1 '
      'WHERE device_id = ? AND note_id = ?',
      <Object?>[deviceId, noteId],
    );
    final List<Map<String, Object?>> r = await _db.query(
      JotaDatabase.partials,
      columns: <String>['attempts'],
      where: 'device_id = ? AND note_id = ?',
      whereArgs: <Object?>[deviceId, noteId],
      limit: 1,
    );
    return r.isEmpty ? 0 : ((r.first['attempts'] as int?) ?? 0);
  }

  Future<void> forgetPartial(String deviceId, int noteId) async {
    await _db.delete(
      JotaDatabase.partials,
      where: 'device_id = ? AND note_id = ?',
      whereArgs: <Object?>[deviceId, noteId],
    );
  }

  /// Notes we have bytes for but never finished. Shown on the sync screen so a
  /// half-transferred note is visible rather than a silent 0 in the count.
  Future<List<int>> unfinishedNoteIds(String deviceId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.partials,
      columns: <String>['note_id'],
      where: 'device_id = ?',
      whereArgs: <Object?>[deviceId],
    );
    return rows.map((Map<String, Object?> r) => r['note_id']! as int).toList();
  }
}
