// ============================================================================
//  Jota — IMA ADPCM encoder (implementation)
// ============================================================================
#include "audio/adpcm.h"

namespace jota {

static const int8_t kIndexTable[16] = {-1, -1, -1, -1, 2,  4,  6,  8,
                                       -1, -1, -1, -1, 2,  4,  6,  8};

static const int16_t kStepTable[89] = {
    7,     8,     9,     10,    11,    12,    13,    14,    16,    17,
    19,    21,    23,    25,    28,    31,    34,    37,    41,    45,
    50,    55,    60,    66,    73,    80,    88,    97,    107,   118,
    130,   143,   157,   173,   190,   209,   230,   253,   279,   307,
    337,   371,   408,   449,   494,   544,   598,   658,   724,   796,
    876,   963,   1060,  1166,  1282,  1411,  1552,  1707,  1878,  2066,
    2272,  2499,  2749,  3024,  3327,  3660,  4026,  4428,  4871,  5358,
    5894,  6484,  7132,  7845,  8630,  9493,  10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767};

static inline int16_t clamp16(int32_t v) {
  if (v > 32767) return 32767;
  if (v < -32768) return -32768;
  return (int16_t)v;
}

// One 4-bit code. Also advances the predictor exactly as a decoder will, so
// encoder and decoder stay in step.
static uint8_t encodeSample(AdpcmState &s, int16_t sample) {
  const int32_t step = kStepTable[s.index];
  int32_t       diff = (int32_t)sample - s.predictor;

  uint8_t code = 0;
  if (diff < 0) {
    code = 8;
    diff = -diff;
  }

  int32_t t = step;
  if (diff >= t) {
    code |= 4;
    diff -= t;
  }
  t >>= 1;
  if (diff >= t) {
    code |= 2;
    diff -= t;
  }
  t >>= 1;
  if (diff >= t) code |= 1;

  // Mirror the decoder's reconstruction.
  int32_t diffq = step >> 3;
  if (code & 4) diffq += step;
  if (code & 2) diffq += step >> 1;
  if (code & 1) diffq += step >> 2;

  s.predictor = clamp16((code & 8) ? s.predictor - diffq : s.predictor + diffq);

  s.index = (int8_t)(s.index + kIndexTable[code]);
  if (s.index < 0) s.index = 0;
  if (s.index > 88) s.index = 88;

  return code;
}

// Pick a starting step index that already suits this block's signal level.
//
// Starting every block at index 0 (step 7, the smallest) makes the predictor
// climb from nothing 32 times a second, and the climb is audible as a chirp
// at each block boundary. Since the header carries the index, choosing a
// better one costs nothing on the wire and needs no decoder change.
static int8_t pickStartIndex(const int16_t *pcm) {
  const size_t look = 32;
  int32_t      acc  = 0;
  for (size_t i = 1; i < look && i < ADPCM_BLOCK_SAMPLES; ++i) {
    int32_t d = (int32_t)pcm[i] - pcm[i - 1];
    acc += (d < 0) ? -d : d;
  }
  const int32_t mean = acc / (int32_t)(look - 1);

  int8_t best = 0;
  for (int8_t i = 0; i < 89; ++i) {
    if (kStepTable[i] > mean) break;
    best = i;
  }
  return best;
}

void adpcmEncodeBlock(const int16_t *pcm, uint8_t *out) {
  AdpcmState s;
  // The block header is the state a decoder needs to start here cold — which
  // is what makes resume-from-offset possible.
  s.predictor = pcm[0];
  s.index     = pickStartIndex(pcm);

  out[0] = (uint8_t)(s.predictor & 0xFF);
  out[1] = (uint8_t)((s.predictor >> 8) & 0xFF);
  out[2] = (uint8_t)s.index;
  out[3] = 0;

  // Sample 0 is carried by the header, so data starts at sample 1 and the
  // last nibble of the block is padding.
  size_t si = 1;
  for (size_t i = 4; i < ADPCM_BLOCK_BYTES; ++i) {
    const uint8_t lo =
        (si < ADPCM_BLOCK_SAMPLES) ? encodeSample(s, pcm[si]) : 0;
    si++;
    const uint8_t hi =
        (si < ADPCM_BLOCK_SAMPLES) ? encodeSample(s, pcm[si]) : 0;
    si++;
    out[i] = (uint8_t)(lo | (hi << 4));
  }
}

}  // namespace jota
