// ============================================================================
//  Jota — audio storage interface
//
//  Two tiers, and the distinction matters:
//
//    archive   the ADPCM exactly as the device sent it. This is the note. It is
//              what `crc` checksums, it is 4x smaller than PCM, and it cannot be
//              regenerated — the device deletes its copy once acked.
//
//    cache     decoded 16-bit PCM WAV. Derived, disposable, four times the size.
//              Whisper needs a real container and no player will take a bare
//              ADPCM stream, so both go through here.
//
//  Deleting the cache costs a few milliseconds of CPU. Deleting the archive
//  loses the recording.
//
//  Nothing in this interface mentions `File`. That is deliberate: it keeps
//  dart:io out of the contract, so a store backed by a map in memory is as
//  legitimate an implementation as one backed by a directory (see
//  lib/preview/). The real one is FileAudioStore.
// ============================================================================
import 'dart:typed_data';

abstract class AudioStore {
  /// Where a note's ADPCM belongs. Handed to [PartialStore.promote] so a
  /// completed download is moved straight into the archive rather than copied.
  String archivePathFor(String deviceId, int noteId);

  /// Decode a note to a playable WAV and return a path to it, reusing the
  /// cached file when it is already there.
  ///
  /// Null when the archive is missing — which should not happen, but a missing
  /// file is a UI state, not a crash.
  Future<String?> ensureWavPath(String deviceId, int noteId);

  /// The decoded WAV bytes, for the transcription upload.
  Future<Uint8List?> wavBytes(String deviceId, int noteId);

  Future<bool> hasArchive(String deviceId, int noteId);

  Future<void> deleteNote(String deviceId, int noteId);

  /// Drop every decoded WAV. Safe at any time; they rebuild on demand.
  /// Returns the bytes freed.
  Future<int> clearCache();

  Future<int> archiveBytes();

  Future<int> cacheBytes();
}
