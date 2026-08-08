// ============================================================================
//  Jota — IMA ADPCM decoder
//
//  The exact inverse of firmware/src/audio/adpcm.cpp. Read that file before
//  touching this one: the two must stay in step or every note comes back as
//  noise, and nothing in the protocol would tell you.
//
//  Block layout, from adpcm.h:
//
//    256-byte block = 4-byte header + 252 data bytes
//      header[0..1]  predictor, int16 little-endian  — ALSO sample 0
//      header[2]     step index (the encoder always writes 0)
//      header[3]     reserved, 0
//    252 data bytes = 504 nibbles, LOW NIBBLE FIRST, decoding samples 1..503.
//    The final nibble is padding, so a block is exactly 504 samples.
//
//  Every block restarts the predictor and carries it in its header. That is
//  what makes resume-from-offset possible at all: the phone can start decoding
//  at any 256-byte boundary with no state to reconstruct, which is why
//  SyncEngine truncates a partial download down to a block boundary before
//  asking the device to continue.
//
//  16 kHz mono, so one block is ~31.5 ms and the stream is ~8 KB/s — the
//  "480 KB/min" the BLE contract quotes.
// ============================================================================
import 'dart:typed_data';

abstract final class Adpcm {
  /// adpcm.h ADPCM_BLOCK_BYTES.
  static const int blockBytes = 256;

  /// adpcm.h ADPCM_BLOCK_SAMPLES = (256 - 4) * 2.
  static const int blockSamples = (blockBytes - 4) * 2; // 504

  static const int headerBytes = 4;

  /// The device records at 16 kHz mono. Not carried in the protocol — it is a
  /// property of the hardware, asserted here in one place.
  static const int sampleRate = 16000;
  static const int channels = 1;

  static const List<int> _indexTable = <int>[
    -1, -1, -1, -1, 2, 4, 6, 8, //
    -1, -1, -1, -1, 2, 4, 6, 8,
  ];

  static const List<int> _stepTable = <int>[
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17, //
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767,
  ];

  static int _clamp16(int v) {
    if (v > 32767) return 32767;
    if (v < -32768) return -32768;
    return v;
  }

  /// How many PCM samples `byteLength` of ADPCM will decode to. Lets the WAV
  /// header be written before the decode runs, so the output buffer is
  /// allocated exactly once.
  static int samplesForBytes(int byteLength) {
    final int whole = byteLength ~/ blockBytes;
    final int rest = byteLength % blockBytes;
    int n = whole * blockSamples;
    if (rest > headerBytes) {
      // A trailing partial block still yields 1 (the header) + 2 per data byte.
      n += 1 + (rest - headerBytes) * 2;
    } else if (rest == headerBytes) {
      n += 1;
    }
    return n;
  }

  /// Decode a whole ADPCM stream to signed 16-bit mono PCM.
  ///
  /// A partial final block is decoded as far as it goes rather than discarded:
  /// a note whose length is not a multiple of 256 is normal (the recording
  /// simply stopped mid-block) and dropping it would clip the last 31 ms off
  /// every note.
  static Int16List decode(Uint8List adpcm) {
    final Int16List out = Int16List(samplesForBytes(adpcm.length));
    int o = 0;

    for (int base = 0; base < adpcm.length; base += blockBytes) {
      final int end =
          (base + blockBytes) < adpcm.length ? base + blockBytes : adpcm.length;
      if (end - base < headerBytes) break; // not even a header; stop cleanly

      // ---- header: the decoder's cold-start state -------------------------
      int predictor = adpcm[base] | (adpcm[base + 1] << 8);
      if (predictor > 32767) predictor -= 65536; // int16 little-endian
      int index = adpcm[base + 2];
      if (index < 0) index = 0;
      if (index > 88) index = 88;

      // header carries sample 0 verbatim
      if (o < out.length) out[o++] = predictor;

      // ---- data nibbles ---------------------------------------------------
      // `si` mirrors the encoder's counter: it starts at 1 because sample 0
      // came from the header, and the encoder stops emitting once it reaches
      // blockSamples, leaving the last nibble as padding.
      int si = 1;
      for (int i = base + headerBytes; i < end; i++) {
        final int b = adpcm[i];

        // low nibble first — encoder writes `lo | (hi << 4)`
        if (si < blockSamples && o < out.length) {
          final int r = _step(predictor, index, b & 0x0F);
          predictor = r >> 8;
          index = r & 0xFF;
          out[o++] = predictor;
        }
        si++;

        if (si < blockSamples && o < out.length) {
          final int r = _step(predictor, index, (b >> 4) & 0x0F);
          predictor = r >> 8;
          index = r & 0xFF;
          out[o++] = predictor;
        }
        si++;
      }
    }

    // A truncated stream can decode to fewer samples than the estimate when a
    // partial block runs out of nibbles. Hand back only what is real.
    return o == out.length ? out : Int16List.sublistView(out, 0, o);
  }

  /// One 4-bit code. Returns predictor and index packed into a single int so
  /// the hot loop allocates nothing — `predictor << 8 | index`, with the
  /// predictor sign-extended by the caller's `>> 8`.
  ///
  /// This is exactly the reconstruction firmware/src/audio/adpcm.cpp mirrors
  /// inside its encoder; if you change one, change both.
  static int _step(int predictor, int index, int code) {
    final int step = _stepTable[index];

    int diff = step >> 3;
    if ((code & 4) != 0) diff += step;
    if ((code & 2) != 0) diff += step >> 1;
    if ((code & 1) != 0) diff += step >> 2;

    final int p =
        _clamp16((code & 8) != 0 ? predictor - diff : predictor + diff);

    int i = index + _indexTable[code];
    if (i < 0) i = 0;
    if (i > 88) i = 88;

    // Pack. `p` may be negative; the caller's arithmetic shift restores it.
    return (p << 8) | i;
  }

  /// Round a byte count down to a whole number of blocks.
  ///
  /// Used before a resume: `fetch {"id":N,"offset":M}` should land on a block
  /// boundary so the device seeks to a self-describing header and the decoder
  /// never sees a block whose head it missed. Discarding at most 255 bytes is
  /// cheap insurance.
  static int floorToBlock(int byteLength) =>
      (byteLength ~/ blockBytes) * blockBytes;

  /// Duration in seconds of an ADPCM payload of this size.
  static double secondsForBytes(int byteLength) =>
      samplesForBytes(byteLength) / sampleRate;
}
