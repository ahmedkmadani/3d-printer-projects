// ============================================================================
//  Jota — note store (implementation)
// ============================================================================
#include "app/notes.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

#include "audio/adpcm.h"

namespace jota {

static const uint32_t SAMPLE_RATE = 16000;

// ---- CRC32 (IEEE, reflected) --------------------------------------------
// Table-less: 8 notes of a few seconds is well under a millisecond, and it
// saves 1 KB of RAM.
static uint32_t crc32Update(uint32_t crc, const uint8_t *buf, size_t n) {
  crc = ~crc;
  while (n--) {
    crc ^= *buf++;
    for (int k = 0; k < 8; ++k) {
      crc = (crc >> 1) ^ (0xEDB88320u & (uint32_t)(-(int32_t)(crc & 1)));
    }
  }
  return ~crc;
}

// ---- Synthetic PCM -------------------------------------------------------
// A warbling tone, distinct per note so you can tell them apart by ear after
// the phone decodes them. Deterministic in the absolute sample index, which
// is what lets any block be regenerated on demand for a resumed fetch.
static void fillPcm(uint16_t id, uint32_t firstSample, int16_t *pcm,
                    size_t n) {
  const float base = 220.0f + (float)(id % 5) * 110.0f;
  for (size_t i = 0; i < n; ++i) {
    const float t = (float)(firstSample + i) / (float)SAMPLE_RATE;
    const float f = base + 40.0f * sinf(2.0f * (float)M_PI * 0.7f * t);
    const float a = 0.55f + 0.35f * sinf(2.0f * (float)M_PI * 0.23f * t);
    pcm[i] = (int16_t)(a * 11000.0f * sinf(2.0f * (float)M_PI * f * t));
  }
}

static void buildBlock(uint16_t id, uint32_t blockIdx, uint8_t *out) {
  int16_t pcm[ADPCM_BLOCK_SAMPLES];
  fillPcm(id, blockIdx * ADPCM_BLOCK_SAMPLES, pcm, ADPCM_BLOCK_SAMPLES);
  adpcmEncodeBlock(pcm, out);
}

static uint32_t blocksFor(uint16_t secs) {
  const uint32_t samples = (uint32_t)secs * SAMPLE_RATE;
  return (samples + ADPCM_BLOCK_SAMPLES - 1) / ADPCM_BLOCK_SAMPLES;
}

// ---- Store ---------------------------------------------------------------

void NoteStore::begin() {
  // Short on purpose: long enough to exercise chunking and resume, short
  // enough that a full sync takes seconds while testing.
  static const uint16_t kSecs[] = {8, 5, 12};
  count_ = (uint8_t)(sizeof(kSecs) / sizeof(kSecs[0]));

  for (uint8_t i = 0; i < count_; ++i) {
    NoteRec &r = notes_[i];
    r.id     = (uint16_t)(12 + i);
    r.secs   = kSecs[i];
    r.bytes  = blocksFor(r.secs) * (uint32_t)ADPCM_BLOCK_BYTES;
    r.time   = 0;
    r.synced = false;

    // CRC over exactly the bytes the phone will receive, so its check and
    // ours are over the same thing.
    uint32_t crc = 0;
    uint8_t  blk[ADPCM_BLOCK_BYTES];
    const uint32_t nblocks = r.bytes / ADPCM_BLOCK_BYTES;
    for (uint32_t b = 0; b < nblocks; ++b) {
      buildBlock(r.id, b, blk);
      crc = crc32Update(crc, blk, ADPCM_BLOCK_BYTES);
    }
    r.crc = crc;
  }
}

uint8_t NoteStore::pending() const {
  uint8_t n = 0;
  for (uint8_t i = 0; i < count_; ++i)
    if (!notes_[i].synced) n++;
  return n;
}

size_t NoteStore::indexJson(char *out, size_t n) const {
  size_t w = 0;
  w += (size_t)snprintf(out + w, n - w, "[");
  bool first = true;
  for (uint8_t i = 0; i < count_ && w < n; ++i) {
    const NoteRec &r = notes_[i];
    if (r.synced) continue;
    w += (size_t)snprintf(out + w, n - w,
                          "%s{\"id\":%u,\"secs\":%u,\"bytes\":%lu,"
                          "\"crc\":\"%08lx\",\"time\":%lu,\"tag\":\"%s\"}",
                          first ? "" : ",", (unsigned)r.id, (unsigned)r.secs,
                          (unsigned long)r.bytes, (unsigned long)r.crc,
                          (unsigned long)r.time, r.tag);
    first = false;
  }
  if (w < n) w += (size_t)snprintf(out + w, n - w, "]");
  return w;
}

size_t NoteStore::read(uint16_t id, uint32_t offset, uint8_t *out, size_t len) {
  const NoteRec *r = nullptr;
  for (uint8_t i = 0; i < count_; ++i)
    if (notes_[i].id == id) r = &notes_[i];
  if (!r || offset >= r->bytes) return 0;

  if (offset + len > r->bytes) len = r->bytes - offset;

  // Regenerate whole blocks and copy the requested slice out of them, so an
  // arbitrary (unaligned) resume offset still works.
  size_t   done = 0;
  uint8_t  blk[ADPCM_BLOCK_BYTES];
  while (done < len) {
    const uint32_t pos    = offset + done;
    const uint32_t bIdx   = pos / ADPCM_BLOCK_BYTES;
    const uint32_t inBlk  = pos % ADPCM_BLOCK_BYTES;
    size_t         take   = ADPCM_BLOCK_BYTES - inBlk;
    if (take > len - done) take = len - done;

    buildBlock(id, bIdx, blk);
    memcpy(out + done, blk + inBlk, take);
    done += take;
  }
  return done;
}

bool NoteStore::ack(uint16_t id, uint32_t crc) {
  for (uint8_t i = 0; i < count_; ++i) {
    if (notes_[i].id != id) continue;
    if (notes_[i].crc != crc) return false;  // truncated or corrupted
    notes_[i].synced = true;
    return true;
  }
  return false;
}

void NoteStore::setClock(uint32_t unixSeconds) {
  for (uint8_t i = 0; i < count_; ++i)
    if (notes_[i].time == 0) notes_[i].time = unixSeconds;
}

}  // namespace jota
