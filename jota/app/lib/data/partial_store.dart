// ============================================================================
//  Jota — partial transfers (resume state) interface
//
//  THE reason a dropped connection costs nothing. From the contract:
//
//    "The app should keep partial data keyed by note id, and verify the CRC
//     over the whole note before sending ack."
//
//  So: bytes accumulated per (device, note), surviving app death, so that on the
//  next connection the app can say "I have M bytes, send me the rest" instead of
//  starting a 480 KB transfer again.
//
//  Like AudioStore, this interface never mentions `File` — including
//  [crc32Of], which belongs here precisely because the store owns the bytes and
//  can checksum them without ever materialising the whole note in memory.
//  The real one is FilePartialStore.
// ============================================================================
import 'dart:typed_data';

abstract class PartialStore {
  /// How many bytes of this note we already hold.
  Future<int> receivedBytes(String deviceId, int noteId);

  /// The byte offset the next `fetch` should ask from.
  ///
  /// Rounded DOWN to a whole 256-byte ADPCM block. Every block carries the
  /// predictor and step index it needs in its own header, so a block boundary is
  /// the only offset at which a decoder can start cold — and it is what the
  /// firmware seeks to. Implementations must also trim any ragged tail, so that
  /// the bytes held and the offset requested are the same number; if they
  /// diverge, the note silently gains or loses bytes in the middle and only the
  /// CRC catches it.
  ///
  /// Throwing away at most 255 bytes (~31 ms, which we simply receive again)
  /// buys the guarantee that a resumed note decodes identically to an unbroken
  /// one. The contract's own example offset, 180224, is 704 whole blocks.
  Future<int> resumeOffset(String deviceId, int noteId);

  /// Append a `data` notification's payload, in arrival order.
  Future<void> append(String deviceId, int noteId, List<int> chunk);

  Future<void> truncate(String deviceId, int noteId, int length);

  /// CRC32 over everything held for this note. Streamed by the implementation —
  /// a long note is several MB and there is no reason to hold it in memory just
  /// to checksum it.
  Future<int> crc32Of(String deviceId, int noteId);

  Future<Uint8List> readAll(String deviceId, int noteId);

  /// Hand the completed bytes to the archive. A move, not a copy, so a 5 MB note
  /// does not briefly exist twice.
  Future<void> promote(String deviceId, int noteId, String destPath);

  /// Called when a CRC check fails: the bytes we hold are not the note, and
  /// keeping them would make the next resume ask for the wrong offset.
  Future<void> discard(String deviceId, int noteId);

  /// Housekeeping: drop partials for notes the device no longer lists. Without
  /// this, a note deleted on the device leaves its bytes on the phone forever.
  Future<void> retainOnly(String deviceId, Set<int> liveNoteIds);

  /// Total bytes parked in partials — surfaced in settings so "why is this app
  /// 40 MB" has an answer.
  Future<int> totalBytes();
}
