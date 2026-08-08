// ============================================================================
//  Jota — IMA ADPCM encoder
//
//  4:1 compression, used for the copy of a note sent over BLE. The raw WAV
//  stays on the SD card, so the archive is never compressed — only the copy
//  in flight, where 1.9 MB/min would take a minute to transfer and 480 KB/min
//  takes about sixteen seconds.
//
//  BLOCK-BASED, like IMA ADPCM in WAV: every block restarts the predictor and
//  carries it in a 4-byte header. Two reasons that matters here:
//    1. seeking is trivial — the phone can resume from any block boundary
//       after a dropped connection, with no state to reconstruct
//    2. a corrupted block cannot poison everything after it
// ============================================================================
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace jota {

// 256-byte blocks: 4-byte header + 252 data bytes = 504 samples. At 16 kHz
// that is ~31.5 ms per block and ~8 KB/s.
static const size_t ADPCM_BLOCK_BYTES   = 256;
static const size_t ADPCM_BLOCK_SAMPLES = (ADPCM_BLOCK_BYTES - 4) * 2;

struct AdpcmState {
  int16_t predictor;
  int8_t  index;
};

// Encode exactly ADPCM_BLOCK_SAMPLES samples into exactly ADPCM_BLOCK_BYTES
// bytes. `pcm` must hold ADPCM_BLOCK_SAMPLES 16-bit mono samples.
void adpcmEncodeBlock(const int16_t *pcm, uint8_t *out);

}  // namespace jota
