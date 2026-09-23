// ============================================================================
//  Jota — corrections export
//
//  Every note the user corrected by hand is a training pair: the audio, what
//  the model heard, and what was actually said. That is the data a Whisper
//  fine-tune for this voice and this dialect is made of, and it only exists
//  because the edit kept the model's words instead of overwriting them (see
//  Note.machineTranscript).
//
//  The export is one zip: a WAV per note (16 kHz mono, straight from the
//  archive's ADPCM) and manifest.jsonl, one line per note, in the shape the
//  usual fine-tuning scripts read without a converter.
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/audio_store.dart';
import '../data/note.dart';

/// `N-012.wav` — the id is unique per device and the export is per phone.
String correctionWavName(Note n) => '${n.deviceId}_${n.displayId}.wav';

/// One line of manifest.jsonl. `language` is the Settings hint at export
/// time, or null for auto — the fine-tune wants to know which it was.
String correctionManifestLine(Note n, {String? language}) {
  return jsonEncode(<String, Object?>{
    'audio': correctionWavName(n),
    'seconds': n.secs,
    'machine': n.machineTranscript,
    'text': n.transcript?.trim(),
    'model': n.transcriptModel,
    'language': language ?? 'auto',
    'recorded_at': n.recordedAt.toUtc().toIso8601String(),
  });
}

/// The zip's bytes, or null when none of the notes has a correction to give.
/// A note whose audio is missing is left out rather than failing the export.
Future<Uint8List?> buildCorrectionsZip(
  List<Note> notes,
  AudioStore audio, {
  String? language,
}) async {
  final Archive zip = Archive();
  final StringBuffer manifest = StringBuffer();
  int count = 0;

  for (final Note n in notes) {
    if (!n.isCorrected) continue;
    final Uint8List? wav = await audio.wavBytes(n.deviceId, n.noteId);
    if (wav == null) continue;
    zip.addFile(ArchiveFile(correctionWavName(n), wav.length, wav));
    manifest.writeln(correctionManifestLine(n, language: language));
    count++;
  }
  if (count == 0) return null;

  final List<int> m = utf8.encode(manifest.toString());
  zip.addFile(ArchiveFile('manifest.jsonl', m.length, m));
  final List<int>? bytes = ZipEncoder().encode(zip);
  return bytes == null ? null : Uint8List.fromList(bytes);
}
