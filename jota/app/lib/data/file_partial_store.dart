// ============================================================================
//  Jota — partial transfers on disk (the real PartialStore)
//
//  One file per (device, note), appended to as `data` notifications arrive.
//  On disk rather than in a list in memory so it survives the app being killed
//  mid-transfer, which on iOS is the normal way a background sync ends.
//
//  Files, not BLOB columns. A minute of speech is ~480 KB and a long note is
//  several MB; appending to a file is O(chunk) while rewriting a BLOB row is
//  O(note), which turns one long note into a quadratic write.
// ============================================================================
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../audio/adpcm.dart';
import '../audio/crc32.dart';
import 'partial_store.dart';

class FilePartialStore implements PartialStore {
  FilePartialStore(this._root);

  /// `<app support>/partials/`
  final Directory _root;

  static Future<FilePartialStore> open(Directory appSupport) async {
    final Directory d = Directory(p.join(appSupport.path, 'partials'));
    if (!await d.exists()) await d.create(recursive: true);
    return FilePartialStore(d);
  }

  static String _safe(String deviceId) =>
      deviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  File _fileFor(String deviceId, int noteId) =>
      File(p.join(_root.path, '${_safe(deviceId)}_$noteId.adpcm'));

  @override
  Future<int> receivedBytes(String deviceId, int noteId) async {
    final File f = _fileFor(deviceId, noteId);
    return await f.exists() ? f.length() : 0;
  }

  @override
  Future<int> resumeOffset(String deviceId, int noteId) async {
    final int held = await receivedBytes(deviceId, noteId);
    final int aligned = Adpcm.floorToBlock(held);
    if (aligned != held) {
      // Trim the ragged tail so the file length and the offset we are about to
      // request stay the same number.
      await truncate(deviceId, noteId, aligned);
    }
    return aligned;
  }

  @override
  Future<void> append(String deviceId, int noteId, List<int> chunk) async {
    // Opened in append mode per call so a crash between chunks loses at most
    // the chunk in flight.
    await _fileFor(deviceId, noteId)
        .writeAsBytes(chunk, mode: FileMode.append, flush: false);
  }

  @override
  Future<void> truncate(String deviceId, int noteId, int length) async {
    final File f = _fileFor(deviceId, noteId);
    if (!await f.exists()) return;
    final RandomAccessFile raf = await f.open(mode: FileMode.append);
    try {
      await raf.truncate(length);
    } finally {
      await raf.close();
    }
  }

  @override
  Future<int> crc32Of(String deviceId, int noteId) async {
    final File f = _fileFor(deviceId, noteId);
    if (!await f.exists()) return Crc32.compute(const <int>[]);
    final Crc32 crc = Crc32();
    await for (final List<int> chunk in f.openRead()) {
      crc.update(chunk);
    }
    return crc.value;
  }

  @override
  Future<Uint8List> readAll(String deviceId, int noteId) async {
    final File f = _fileFor(deviceId, noteId);
    if (!await f.exists()) return Uint8List(0);
    return f.readAsBytes();
  }

  @override
  Future<void> promote(String deviceId, int noteId, String destPath) async {
    final File f = _fileFor(deviceId, noteId);
    final Directory parent = Directory(p.dirname(destPath));
    if (!await parent.exists()) await parent.create(recursive: true);
    await f.rename(destPath);
  }

  @override
  Future<void> discard(String deviceId, int noteId) async {
    final File f = _fileFor(deviceId, noteId);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> retainOnly(String deviceId, Set<int> liveNoteIds) async {
    if (!await _root.exists()) return;
    final String prefix = '${_safe(deviceId)}_';
    await for (final FileSystemEntity e in _root.list()) {
      if (e is! File) continue;
      final String name = p.basename(e.path);
      if (!name.startsWith(prefix) || !name.endsWith('.adpcm')) continue;
      final int? id = int.tryParse(
        name.substring(prefix.length, name.length - '.adpcm'.length),
      );
      if (id != null && !liveNoteIds.contains(id)) {
        await e.delete();
      }
    }
  }

  @override
  Future<int> totalBytes() async {
    if (!await _root.exists()) return 0;
    int total = 0;
    await for (final FileSystemEntity e in _root.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }
}
