// ============================================================================
//  Jota — audio on disk
//
//  Two tiers, and the distinction matters:
//
//    archive/  the ADPCM exactly as the device sent it. This is the note. It is
//              what `crc` checksums, it is 4x smaller than PCM, and it is never
//              regenerated because it cannot be — the device deletes its copy
//              once acked.
//
//    cache/    decoded 16-bit PCM WAV. Derived, disposable, and four times the
//              size. Whisper needs a real container and just_audio will not
//              play a bare ADPCM stream, so both go through here.
//
//  Deleting the cache costs a few milliseconds of CPU. Deleting the archive
//  loses the recording.
// ============================================================================
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../audio/adpcm.dart';
import '../audio/wav.dart';

class AudioStore {
  AudioStore._(this._archive, this._cache);

  final Directory _archive;
  final Directory _cache;

  static Future<AudioStore> open({
    required Directory appSupport,
    required Directory cacheDir,
  }) async {
    final Directory a = Directory(p.join(appSupport.path, 'archive'));
    final Directory c = Directory(p.join(cacheDir.path, 'wav'));
    if (!await a.exists()) await a.create(recursive: true);
    if (!await c.exists()) await c.create(recursive: true);
    return AudioStore._(a, c);
  }

  static String _safe(String deviceId) =>
      deviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  /// Where a note's ADPCM belongs. Handed to PartialStore.promote so the
  /// completed download is renamed straight into the archive.
  String archivePathFor(String deviceId, int noteId) =>
      p.join(_archive.path, '${_safe(deviceId)}_$noteId.adpcm');

  String _wavPathFor(String deviceId, int noteId) =>
      p.join(_cache.path, '${_safe(deviceId)}_$noteId.wav');

  /// Decode a note to a playable/uploadable WAV, reusing the cached file if it
  /// is already there.
  ///
  /// Returns null if the archive file is missing — which should not happen, but
  /// a missing file is a UI state, not a crash.
  Future<File?> ensureWav(String deviceId, int noteId) async {
    final File wav = File(_wavPathFor(deviceId, noteId));
    if (await wav.exists() && await wav.length() > 44) return wav;

    final File adpcm = File(archivePathFor(deviceId, noteId));
    if (!await adpcm.exists()) return null;

    final Uint8List raw = await adpcm.readAsBytes();
    final Uint8List bytes = Wav.encodePcm16(
      Adpcm.decode(raw),
      sampleRate: Adpcm.sampleRate,
      channels: Adpcm.channels,
    );
    await wav.writeAsBytes(bytes, flush: true);
    return wav;
  }

  /// The WAV bytes, for the transcription upload. Same decode, without leaving
  /// a file behind for a one-shot request... except we do leave it, because the
  /// user is very likely to hit play on the note they just transcribed.
  Future<Uint8List?> wavBytes(String deviceId, int noteId) async {
    final File? f = await ensureWav(deviceId, noteId);
    return f?.readAsBytes();
  }

  Future<bool> hasArchive(String deviceId, int noteId) =>
      File(archivePathFor(deviceId, noteId)).exists();

  Future<void> deleteNote(String deviceId, int noteId) async {
    final File a = File(archivePathFor(deviceId, noteId));
    final File w = File(_wavPathFor(deviceId, noteId));
    if (await a.exists()) await a.delete();
    if (await w.exists()) await w.delete();
  }

  /// Drop every decoded WAV. Safe at any time; they rebuild on demand.
  Future<int> clearCache() async {
    int freed = 0;
    if (!await _cache.exists()) return 0;
    await for (final FileSystemEntity e in _cache.list()) {
      if (e is File) {
        freed += await e.length();
        await e.delete();
      }
    }
    return freed;
  }

  Future<int> archiveBytes() async {
    if (!await _archive.exists()) return 0;
    int total = 0;
    await for (final FileSystemEntity e in _archive.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<int> cacheBytes() async {
    if (!await _cache.exists()) return 0;
    int total = 0;
    await for (final FileSystemEntity e in _cache.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }
}
