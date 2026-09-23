// ============================================================================
//  Jota — the real NoteRepository
//
//  The only thing in the app that touches SQL. sqflite rather than drift; the
//  reasoning is in database.dart and in the README.
// ============================================================================
import 'package:sqflite/sqflite.dart';

import 'audio_store.dart';
import 'database.dart';
import 'note.dart';
import 'note_repository.dart';

class SqfliteNoteRepository implements NoteRepository {
  SqfliteNoteRepository(this._db, this._audio);

  final Database _db;
  final AudioStore _audio;

  // ---- reads --------------------------------------------------------------

  @override
  Future<List<Note>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      orderBy: 'recorded_at DESC, note_id DESC',
    );
    return rows.map(Note.fromRow).toList();
  }

  @override
  Future<List<Note>> withTag(String tag) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      where: 'tag = ?',
      whereArgs: <Object?>[tag],
      orderBy: 'recorded_at DESC',
    );
    return rows.map(Note.fromRow).toList();
  }

  @override
  Future<Note?> byId(String deviceId, int noteId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      where: 'device_id = ? AND note_id = ?',
      whereArgs: <Object?>[deviceId, noteId],
      limit: 1,
    );
    return rows.isEmpty ? null : Note.fromRow(rows.first);
  }

  @override
  Future<Set<int>> knownIds(String deviceId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      columns: <String>['note_id'],
      where: 'device_id = ?',
      whereArgs: <Object?>[deviceId],
    );
    return rows.map((Map<String, Object?> r) => r['note_id']! as int).toSet();
  }

  @override
  Future<List<Note>> awaitingTranscription({int limit = 20}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.notes,
      // `running` too: a note the previous process died under stays marked
      // running forever otherwise, showing "Transcribing…" with nothing
      // transcribing. The queue skips the ones it really has in flight.
      where: 'transcript_state IN (?, ?, ?)',
      whereArgs: <Object?>[
        TranscriptState.pending.name,
        TranscriptState.failed.name,
        TranscriptState.running.name,
      ],
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
    return rows.map(Note.fromRow).toList();
  }

  @override
  Future<int> count() async {
    final List<Map<String, Object?>> r = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${JotaDatabase.notes}',
    );
    return (r.first['n'] as int?) ?? 0;
  }

  @override
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

  @override
  Future<Note> insert(Note note) async {
    // `ignore` on conflict, not `replace`: if the row already exists we keep the
    // transcript we have rather than blanking it.
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

  @override
  Future<void> update(Note note) async {
    await _db.update(
      JotaDatabase.notes,
      note.toRow(),
      where: 'device_id = ? AND note_id = ?',
      whereArgs: <Object?>[note.deviceId, note.noteId],
    );
  }

  @override
  Future<void> setTag(Note note, String? tag) =>
      update(note.copyWith(tag: tag, clearTag: tag == null));

  @override
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

  @override
  Future<void> setTranscript(
    Note note,
    String text, {
    String? model,
    bool manual = false,
  }) {
    // A hand edit keeps what the model said (once — the first edit's
    // "before" is the model's, later edits are the user's own). A model
    // result replaces it, so a re-run pairs with the next correction.
    final String? machine = manual
        ? (note.machineTranscript ??
            (note.transcriptState == TranscriptState.done
                ? note.transcript
                : null))
        : text;
    return update(
      note.copyWith(
        transcript: text,
        transcriptState: manual ? TranscriptState.manual : TranscriptState.done,
        transcriptModel: model,
        machineTranscript: machine,
        clearTranscriptError: true,
      ),
    );
  }

  @override
  Future<void> delete(Note note) async {
    await _db.delete(
      JotaDatabase.notes,
      where: 'device_id = ? AND note_id = ?',
      whereArgs: <Object?>[note.deviceId, note.noteId],
    );
    await _audio.deleteNote(note.deviceId, note.noteId);
  }

  // ---- partial bookkeeping ------------------------------------------------

  @override
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

  @override
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

  @override
  Future<void> forgetPartial(String deviceId, int noteId) async {
    await _db.delete(
      JotaDatabase.partials,
      where: 'device_id = ? AND note_id = ?',
      whereArgs: <Object?>[deviceId, noteId],
    );
  }

  @override
  Future<List<int>> unfinishedNoteIds(String deviceId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      JotaDatabase.partials,
      columns: <String>['note_id'],
      where: 'device_id = ?',
      whereArgs: <Object?>[deviceId],
    );
    return rows.map((Map<String, Object?> r) => r['note_id']! as int).toList();
  }

  @override
  Future<void> close() => _db.close();
}
