// ============================================================================
//  Jota — audio on disk (the real AudioStore)
//
//  archive/  in the app-support directory: ADPCM, permanent, backed up.
//  wav/      in the cache directory: decoded PCM, disposable, and correctly
//            placed where the OS is allowed to reclaim it under pressure.
// ============================================================================
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../audio/adpcm.dart';
import '../audio/wav.dart';
import 'audio_store.dart';

class FileAudioStore implements AudioStore {
  FileAudioStore._(this._archive, this._cache);

  final Directory _archive;
  final Directory _cache;

  static Future<FileAudioStore> open({
    required Directory appSupport,
    required Directory cacheDir,
  }) async {
    final Directory a = Directory(p.join(appSupport.path, 'archive'));
    final Directory c = Directory(p.join(cacheDir.path, 'wav'));
    if (!await a.exists()) await a.create(recursive: true);
    if (!await c.exists()) await c.create(recursive: true);
    return FileAudioStore._(a, c);
  }

  /// Device ids are MAC addresses on Android and opaque UUIDs on iOS; both can
  /// contain characters that are legal in a path but awkward in one.
  static String _safe(String deviceId) =>
      deviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  @override
  String archivePathFor(String deviceId, int noteId) =>
      p.join(_archive.path, '${_safe(deviceId)}_$noteId.adpcm');

  String _wavPathFor(String deviceId, int noteId) =>
      p.join(_cache.path, '${_safe(deviceId)}_$noteId.wav');

  Future<File?> _ensureWavFile(String deviceId, int noteId) async {
    final File wav = File(_wavPathFor(deviceId, noteId));
    // A 44-byte file is a header with no samples — treat it as absent rather
    // than handing a player something that will fail to open.
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

  @override
  Future<String?> ensureWavPath(String deviceId, int noteId) async {
    final File? f = await _ensureWavFile(deviceId, noteId);
    return f?.path;
  }

  @override
  Future<Uint8List?> wavBytes(String deviceId, int noteId) async {
    // The decode is cached rather than done in memory for the one request: the
    // user is very likely to hit play on the note they just transcribed.
    final File? f = await _ensureWavFile(deviceId, noteId);
    return f?.readAsBytes();
  }

  @override
  Future<bool> hasArchive(String deviceId, int noteId) =>
      File(archivePathFor(deviceId, noteId)).exists();

  @override
  Future<void> deleteNote(String deviceId, int noteId) async {
    final File a = File(archivePathFor(deviceId, noteId));
    final File w = File(_wavPathFor(deviceId, noteId));
    if (await a.exists()) await a.delete();
    if (await w.exists()) await w.delete();
  }

  @override
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

  @override
  Future<int> archiveBytes() => _sizeOf(_archive);

  @override
  Future<int> cacheBytes() => _sizeOf(_cache);

  static Future<int> _sizeOf(Directory d) async {
    if (!await d.exists()) return 0;
    int total = 0;
    await for (final FileSystemEntity e in d.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }
}
