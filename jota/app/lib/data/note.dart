// ============================================================================
//  Jota — the note
//
//  The archive lives on the phone. The device is a capture tool with a spool of
//  tape; once a note is acked it is the app's, and the app is the only place
//  the transcript ever exists (there is no server, and the device has no idea
//  what was said).
// ============================================================================
import '../design/format.dart';

/// Where a note is in the transcription pipeline.
///
/// Kept explicit rather than inferred from `transcript == null`, because
/// "nobody has tried yet", "we tried and the key was wrong" and "we tried and
/// there was no speech in it" need different things from the UI.
enum TranscriptState {
  /// Audio is stored, no attempt made. The default after a sync.
  pending,

  /// A request is in flight.
  running,

  /// We have text.
  done,

  /// The attempt failed. `transcriptError` says why; the user can retry.
  failed,

  /// The user typed the text themselves, or edited what Whisper returned.
  manual;

  static TranscriptState fromName(String? s) {
    for (final TranscriptState v in TranscriptState.values) {
      if (v.name == s) return v;
    }
    return TranscriptState.pending;
  }
}

class Note {
  const Note({
    this.rowId,
    required this.deviceId,
    required this.noteId,
    required this.recordedAt,
    required this.secs,
    required this.bytes,
    required this.crc,
    required this.adpcmPath,
    this.tag,
    this.transcript,
    this.transcriptState = TranscriptState.pending,
    this.transcriptError,
    this.transcriptModel,
    this.machineTranscript,
    required this.syncedAt,
  });

  /// Local primary key. Null before the first insert.
  final int? rowId;

  /// Which device this came from. Part of the note's identity because the
  /// device's own ids restart from 1 after a factory reset — without this, a
  /// second Jota would silently overwrite the first one's archive.
  final String deviceId;

  /// The device's id for this note. `12` renders as `N-012` everywhere.
  final int noteId;

  final DateTime recordedAt;

  /// Duration in seconds, as reported by the index.
  final int secs;

  /// Length of the ADPCM payload. Also the completeness test during transfer.
  final int bytes;

  /// CRC32 of the ADPCM, eight lowercase hex digits, as the device reported it.
  final String crc;

  /// Path to the ADPCM file on disk. THIS is the archive copy: it is exactly
  /// what came over the wire and exactly what `crc` checksums. The playable WAV
  /// is a derived cache that can be deleted at any time.
  final String adpcmPath;

  final String? tag;
  final String? transcript;
  final TranscriptState transcriptState;
  final String? transcriptError;

  /// Which backend produced the transcript. Recorded so a later re-run with a
  /// better model is a visible change rather than a mystery.
  final String? transcriptModel;

  /// What the model said before the user corrected it. Null until the first
  /// hand edit. Kept because the pair (what it heard, what was meant) is the
  /// training data for a better model — the corrections export is built on
  /// it — and an edit that overwrote it would throw that away.
  final String? machineTranscript;

  final DateTime syncedAt;

  /// Edited by hand, and the model's own words are still here to compare.
  bool get isCorrected =>
      transcriptState == TranscriptState.manual &&
      machineTranscript != null &&
      hasTranscript;

  /// `N-012`
  String get displayId => fmtNoteId(noteId);

  /// `00:47`
  String get displayDuration => fmtDuration(secs);

  bool get hasTranscript => transcript != null && transcript!.trim().isNotEmpty;

  /// First line of the transcript, for the list. Falls back to the state so a
  /// row is never blank.
  String get preview {
    if (hasTranscript) {
      return transcript!.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
    switch (transcriptState) {
      case TranscriptState.running:
        return 'Transcribing…';
      case TranscriptState.failed:
        return 'Transcription failed';
      case TranscriptState.pending:
      case TranscriptState.done:
      case TranscriptState.manual:
        return 'No transcript';
    }
  }

  Note copyWith({
    int? rowId,
    String? tag,
    bool clearTag = false,
    String? transcript,
    TranscriptState? transcriptState,
    String? transcriptError,
    bool clearTranscriptError = false,
    String? transcriptModel,
    String? machineTranscript,
  }) {
    return Note(
      rowId: rowId ?? this.rowId,
      deviceId: deviceId,
      noteId: noteId,
      recordedAt: recordedAt,
      secs: secs,
      bytes: bytes,
      crc: crc,
      adpcmPath: adpcmPath,
      tag: clearTag ? null : (tag ?? this.tag),
      transcript: transcript ?? this.transcript,
      transcriptState: transcriptState ?? this.transcriptState,
      transcriptError: clearTranscriptError
          ? null
          : (transcriptError ?? this.transcriptError),
      transcriptModel: transcriptModel ?? this.transcriptModel,
      machineTranscript: machineTranscript ?? this.machineTranscript,
      syncedAt: syncedAt,
    );
  }

  Map<String, Object?> toRow() {
    return <String, Object?>{
      if (rowId != null) 'row_id': rowId,
      'device_id': deviceId,
      'note_id': noteId,
      'recorded_at': recordedAt.millisecondsSinceEpoch ~/ 1000,
      'secs': secs,
      'bytes': bytes,
      'crc': crc,
      'adpcm_path': adpcmPath,
      'tag': tag,
      'transcript': transcript,
      'transcript_state': transcriptState.name,
      'transcript_error': transcriptError,
      'transcript_model': transcriptModel,
      'machine_transcript': machineTranscript,
      'synced_at': syncedAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  static Note fromRow(Map<String, Object?> r) {
    return Note(
      rowId: r['row_id'] as int?,
      deviceId: r['device_id'] as String? ?? '',
      noteId: r['note_id'] as int? ?? 0,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        ((r['recorded_at'] as int?) ?? 0) * 1000,
      ),
      secs: r['secs'] as int? ?? 0,
      bytes: r['bytes'] as int? ?? 0,
      crc: r['crc'] as String? ?? '',
      adpcmPath: r['adpcm_path'] as String? ?? '',
      tag: r['tag'] as String?,
      transcript: r['transcript'] as String?,
      transcriptState:
          TranscriptState.fromName(r['transcript_state'] as String?),
      transcriptError: r['transcript_error'] as String?,
      transcriptModel: r['transcript_model'] as String?,
      machineTranscript: r['machine_transcript'] as String?,
      syncedAt: DateTime.fromMillisecondsSinceEpoch(
        ((r['synced_at'] as int?) ?? 0) * 1000,
      ),
    );
  }
}
