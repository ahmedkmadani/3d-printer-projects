// ============================================================================
//  Jota — RIFF/WAVE writer
//
//  Whisper will not take a bare ADPCM stream, and neither will just_audio. Both
//  want a container. So the phone decodes ADPCM to linear PCM (lib/audio/
//  adpcm.dart) and wraps it here as the most boring WAV possible: 16-bit
//  signed, mono, 16 kHz, no extension chunks.
//
//  Deliberately NOT an IMA-ADPCM WAV. That would be a smaller file and a
//  legal container, but format 0x11 support is patchy in exactly the two places
//  it needs to work — a speech-to-text endpoint and a mobile audio player.
//  Linear PCM is four times the bytes and zero times the risk, and the file is
//  a cache artefact anyway: the ADPCM the device sent stays the archive copy.
// ============================================================================
import 'dart:typed_data';

abstract final class Wav {
  static const int _headerBytes = 44;
  static const int _formatPcm = 1;
  static const int _bitsPerSample = 16;

  /// Wrap signed 16-bit mono samples in a canonical 44-byte RIFF header.
  static Uint8List encodePcm16(
    Int16List samples, {
    required int sampleRate,
    int channels = 1,
  }) {
    final int dataBytes = samples.length * 2;
    final Uint8List out = Uint8List(_headerBytes + dataBytes);
    final ByteData bd = ByteData.view(out.buffer);

    final int byteRate = sampleRate * channels * (_bitsPerSample ~/ 8);
    final int blockAlign = channels * (_bitsPerSample ~/ 8);

    // ---- RIFF chunk ------------------------------------------------------
    _ascii(out, 0, 'RIFF');
    bd.setUint32(4, 36 + dataBytes, Endian.little); // size of everything after
    _ascii(out, 8, 'WAVE');

    // ---- fmt subchunk ----------------------------------------------------
    _ascii(out, 12, 'fmt ');
    bd.setUint32(16, 16, Endian.little); // PCM fmt chunk is 16 bytes
    bd.setUint16(20, _formatPcm, Endian.little);
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, _bitsPerSample, Endian.little);

    // ---- data subchunk ---------------------------------------------------
    _ascii(out, 36, 'data');
    bd.setUint32(40, dataBytes, Endian.little);

    // Samples are little-endian on both target platforms, but write them
    // explicitly rather than blitting the Int16List's buffer — the host's
    // endianness is not the file format's business.
    int off = _headerBytes;
    for (int i = 0; i < samples.length; i++) {
      bd.setInt16(off, samples[i], Endian.little);
      off += 2;
    }

    return out;
  }

  static void _ascii(Uint8List out, int offset, String tag) {
    for (int i = 0; i < tag.length; i++) {
      out[offset + i] = tag.codeUnitAt(i);
    }
  }
}
