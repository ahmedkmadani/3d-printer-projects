// ============================================================================
//  Jota — local database
//
//  sqflite, not drift. Justification, since the brief asks for one:
//
//    - The schema is two tables and about a dozen columns. Drift's value is
//      compile-checked queries and typed joins, and there are no joins here.
//    - Drift needs build_runner. That is a codegen step in CI, a .g.dart file
//      in review diffs, and a version of the generator that has to agree with
//      the version of the SDK. For two tables that is a poor trade.
//    - The audio never goes in the database — it is a file, and the row holds a
//      path. That removes the one thing sqflite is genuinely awkward about
//      (large BLOBs) and leaves it doing what it is good at.
//
//  If the schema grows joins or a second writer, drift is the right move and
//  the repository interface above this file is what makes that swap cheap.
// ============================================================================
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

abstract final class JotaDatabase {
  static const String fileName = 'jota.db';
  static const int version = 2;

  static const String notes = 'notes';
  static const String partials = 'partials';

  static Future<Database> open() async {
    final String dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, fileName),
      version: version,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int v) async {
        await _createV1(db);
      },
      onUpgrade: (Database db, int from, int to) async {
        // Forward, step by step, never drop and recreate — these rows are the
        // only copy of the user's transcripts.
        if (from < 2) {
          // v2: keep the model's words when the user corrects them.
          await db.execute(
            'ALTER TABLE $notes ADD COLUMN machine_transcript TEXT',
          );
        }
      },
    );
  }

  static Future<void> _createV1(Database db) async {
    // A note's identity is (device, note id), not the device's id alone: the
    // device numbers from 1 and a factory reset starts over, so a bare note_id
    // primary key would let a second device overwrite the first one's archive.
    await db.execute('''
      CREATE TABLE $notes (
        row_id           INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id        TEXT    NOT NULL,
        note_id          INTEGER NOT NULL,
        recorded_at      INTEGER NOT NULL,
        secs             INTEGER NOT NULL DEFAULT 0,
        bytes            INTEGER NOT NULL DEFAULT 0,
        crc              TEXT    NOT NULL DEFAULT '',
        adpcm_path       TEXT    NOT NULL,
        tag              TEXT,
        transcript       TEXT,
        transcript_state TEXT    NOT NULL DEFAULT 'pending',
        transcript_error TEXT,
        transcript_model TEXT,
        machine_transcript TEXT,
        synced_at        INTEGER NOT NULL,
        UNIQUE (device_id, note_id)
      )
    ''');

    // The list is ordered by recording time, newest first, always.
    await db.execute(
      'CREATE INDEX idx_notes_recorded ON $notes (recorded_at DESC)',
    );
    // The transcription queue scans for work by state.
    await db.execute(
      'CREATE INDEX idx_notes_state ON $notes (transcript_state)',
    );

    // Metadata for in-flight transfers. The BYTES live in a file (see
    // PartialStore); this table remembers what they are supposed to add up to,
    // so a resume can be validated without asking the device again.
    await db.execute('''
      CREATE TABLE $partials (
        device_id      TEXT    NOT NULL,
        note_id        INTEGER NOT NULL,
        expected_bytes INTEGER NOT NULL,
        crc            TEXT    NOT NULL,
        secs           INTEGER NOT NULL DEFAULT 0,
        recorded_at    INTEGER NOT NULL DEFAULT 0,
        updated_at     INTEGER NOT NULL,
        attempts       INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (device_id, note_id)
      )
    ''');
  }
}
