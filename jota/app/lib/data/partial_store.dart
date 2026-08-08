// ============================================================================
//  Jota — partial transfers (resume state)
//
//  THE reason a dropped connection costs nothing. From the contract:
//
//    "The app should keep partial data keyed by note id, and verify the CRC
//     over the whole note before sending ack."
//
//  So: one file per (device, note), appended to as `data` notifications
//  arrive, surviving app death because it is on disk rather than in a list in
//  memory. On the next connection the app looks at how many bytes it already
//  has and asks for the rest.
//
//  Partials are files, not BLOB columns. A minute of speech is ~480 KB and a
//  long note is several MB; appending to a file is O(chunk) while rewriting a
//  BLOB row is O(note), which turns a 5 MB note into a quadratic write.
// ============================================================================
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../audio/adpcm.dart';

/// What the app already holds for one note.
class PartialTransfer {
  const PartialTransfer({
    required this.deviceId,
    required this.noteId,
    required this.file,
    required this.received,
  });

  final String deviceId;
  final int noteId;
  final File file;

  /// Bytes on disk. This is the `offset` the next `fetch` will ask from, after
  /// being rounded down to a block boundary.
  final int received;

  bool get isEmpty => received == 0;
}

class PartialStore {
  PartialStore(this._root);

  /// `<app support>/partials/`
  final Directory _root;

  static Future<PartialStore> open(Directory appSupport) async {
    final Directory d = Directory(p.join(appSupport.path, 'partials'));
    if (!await d.exists()) await d.create(recursive: true);
    return PartialStore(d);
  }

  File _fileFor(String deviceId, int noteId) =>
      File(p.join(_root.path, '${_safe(deviceId)}_$noteId.adpcm'));

  /// Device ids are MAC addresses on Android and opaque UUIDs on iOS; both can
  /// contain characters that are legal in a path but awkward in one.
  static String _safe(String deviceId) =>
      deviceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

  /// How much of this note we already hold.
  Future<PartialTransfer> load(String deviceId, int noteId) async {
    final File f = _fileFor(deviceId, noteId);
    final int len = await f.exists() ? await f.length() : 0;
    return PartialTransfer(
      deviceId: deviceId,
      noteId: noteId,
      file: f,
      received: len,
    );
  }

  /// The byte offset to resume from.
  ///
  /// Rounded DOWN to a whole ADPCM block. Every 256-byte block carries the
  /// predictor and step index it needs in its own header, so a block boundary
  /// is the only offset at which the decoder can start cold — and the device
  /// can seek to it without reconstructing any state. Throwing away at most
  /// 255 bytes (about 31 ms of audio, which we will simply receive again) buys
  /// a guarantee that a resumed note decodes identically to an unbroken one.
  ///
  /// The example in the contract, `offset: 180224`, is 704 whole blocks — the
  /// firmware is doing the same arithmetic on its side.
  Future<int> resumeOffset(String deviceId, int noteId) async {
    final PartialTransfer t = await load(deviceId, noteId);
    final int aligned = Adpcm.floorToBlock(t.received);
    if (aligned != t.received) {
      // Trim the ragged tail so the file length and the offset we are about to
      // request stay the same number. If they diverge, the note silently gains
      // or loses bytes in the middle and only the CRC catches it.
      await truncate(deviceId, noteId, aligned);
    }
    return aligned;
  }

  /// Append a `data` chunk. Opened in append mode per call so a crash between
  /// chunks loses at most the chunk in flight.
  Future<void> append(String deviceId, int noteId, List<int> chunk) async {
    final File f = _fileFor(deviceId, noteId);
    await f.writeAsBytes(chunk, mode: FileMode.append, flush: false);
  }

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

  Future<Uint8List> readAll(String deviceId, int noteId) async {
    final File f = _fileFor(deviceId, noteId);
    if (!await f.exists()) return Uint8List(0);
    return f.readAsBytes();
  }

  /// Hand the completed file over to the archive. A rename rather than a copy,
  /// so a 5 MB note does not briefly exist twice.
  Future<File> promote(String deviceId, int noteId, String destPath) async {
    final File f = _fileFor(deviceId, noteId);
    final Directory parent = Directory(p.dirname(destPath));
    if (!await parent.exists()) await parent.create(recursive: true);
    return f.rename(destPath);
  }

  /// Called when a CRC check fails: the bytes we hold are not the note, and
  /// keeping them would make the next resume ask for the wrong offset.
  Future<void> discard(String deviceId, int noteId) async {
    final File f = _fileFor(deviceId, noteId);
    if (await f.exists()) await f.delete();
  }

  /// Housekeeping: drop partials for notes the device no longer lists. Without
  /// this, a note deleted on the device leaves its bytes on the phone forever.
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

  /// Total bytes parked in partials — surfaced in settings so "why is this app
  /// 40 MB" has an answer.
  Future<int> totalBytes() async {
    if (!await _root.exists()) return 0;
    int total = 0;
    await for (final FileSystemEntity e in _root.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }
}
