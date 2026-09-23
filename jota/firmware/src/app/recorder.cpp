#include "app/recorder.h"

#include <Arduino.h>
#include <string.h>
#include <unistd.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_heap_caps.h"

#include "app/notes.h"
#include "audio/adpcm.h"
#include "hal/mic.h"
#include "util/crc32.h"

namespace jota {

// Mono samples per read: 64 ms at 16 kHz, 2 KB of PCM, well inside the
// 128 ms of DMA slack the mic driver keeps.
static const size_t CHUNK = 1024;

static void putLE32(uint8_t *p, uint32_t v) {
  p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24);
}
static void putLE16(uint8_t *p, uint16_t v) {
  p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8);
}

// Canonical 44-byte PCM header. Written as zeros first and patched once the
// length is known, the way every WAV recorder does it.
static void wavHeader(uint8_t *h, uint32_t dataBytes) {
  memcpy(h, "RIFF", 4);          putLE32(h + 4, 36 + dataBytes);
  memcpy(h + 8, "WAVEfmt ", 8);  putLE32(h + 16, 16);
  putLE16(h + 20, 1);            putLE16(h + 22, 1);          // PCM, mono
  putLE32(h + 24, MIC_SAMPLE_RATE);
  putLE32(h + 28, MIC_SAMPLE_RATE * 2);                       // byte rate
  putLE16(h + 32, 2);            putLE16(h + 34, 16);         // block align, bits
  memcpy(h + 36, "data", 4);     putLE32(h + 40, dataBytes);
}

void Recorder::begin(Mic *mic, bool sdOk) {
  mic_  = mic;
  sdOk_ = sdOk;
}

bool Recorder::start(uint16_t id) {
  if (state_ != Idle) return false;
  if (!sdOk_) {
    Serial.println("[rec] no card: not recording");
    return false;
  }
  if (!mic_ || !mic_->ready()) {
    Serial.println("[rec] no codec: not recording");
    return false;
  }
  result_    = {};
  result_.id = id;
  stopReq_   = false;
  state_     = Running;
  // Core 0, away from the Arduino loop (core 1) that paints the panel. SD and
  // I2S both block on DMA, so this task mostly sleeps.
  if (xTaskCreatePinnedToCore(taskEntry, "rec", 8192, this, 3, nullptr, 0) != pdPASS) {
    state_ = Idle;
    Serial.println("[rec] task failed");
    return false;
  }
  return true;
}

void Recorder::stop() {
  if (state_ != Running) return;
  stopReq_ = true;
  state_   = Stopping;
}

bool Recorder::takeResult(RecResult &out) {
  if (state_ != Done) return false;
  out      = result_;
  state_   = Idle;
  stopReq_ = false;
  return true;
}

void Recorder::taskEntry(void *arg) {
  static_cast<Recorder *>(arg)->run();
  vTaskDelete(nullptr);
}

void Recorder::run() {
  RecResult r = {};
  r.id        = result_.id;

  char wavPath[48], imaPath[48];
  notePath(r.id, "wav", wavPath, sizeof(wavPath));
  notePath(r.id, "ima", imaPath, sizeof(imaPath));

  int16_t *mono  = (int16_t *)heap_caps_malloc(CHUNK * sizeof(int16_t), MALLOC_CAP_8BIT);
  int16_t *carry = (int16_t *)heap_caps_malloc(ADPCM_BLOCK_SAMPLES * sizeof(int16_t), MALLOC_CAP_8BIT);
  uint8_t  blk[ADPCM_BLOCK_BYTES];
  size_t   carryN = 0;

  FILE *wav = nullptr, *ima = nullptr;
  bool  ok  = mono && carry && mic_->open();
  if (ok) {
    wav = fopen(wavPath, "wb");
    ima = fopen(imaPath, "wb");
    ok  = wav && ima;
    if (!ok) Serial.println("[rec] cannot open files on the card");
  }
  if (ok) {
    uint8_t hdr[44] = {0};
    ok = fwrite(hdr, 1, sizeof(hdr), wav) == sizeof(hdr);
  }

  uint32_t crc = 0, samples = 0, blocks = 0;
  while (ok && !stopReq_) {
    const size_t n = mic_->read(mono, CHUNK);
    if (n == 0) { Serial.println("[rec] mic read failed"); ok = false; break; }
    if (fwrite(mono, sizeof(int16_t), n, wav) != n) {
      Serial.println("[rec] card write failed");
      ok = false;
      break;
    }
    samples += n;

    // The same samples into the ADPCM copy, one full block at a time.
    size_t i = 0;
    while (i < n) {
      size_t take = ADPCM_BLOCK_SAMPLES - carryN;
      if (take > n - i) take = n - i;
      memcpy(carry + carryN, mono + i, take * sizeof(int16_t));
      carryN += take;
      i += take;
      if (carryN == ADPCM_BLOCK_SAMPLES) {
        adpcmEncodeBlock(carry, blk);
        if (fwrite(blk, 1, ADPCM_BLOCK_BYTES, ima) != ADPCM_BLOCK_BYTES) { ok = false; break; }
        crc = crc32Update(crc, blk, ADPCM_BLOCK_BYTES);
        blocks++;
        carryN = 0;
      }
    }
  }
  // Last partial block, padded with silence so every block is whole.
  if (ok && carryN > 0) {
    memset(carry + carryN, 0, (ADPCM_BLOCK_SAMPLES - carryN) * sizeof(int16_t));
    adpcmEncodeBlock(carry, blk);
    if (fwrite(blk, 1, ADPCM_BLOCK_BYTES, ima) == ADPCM_BLOCK_BYTES) {
      crc = crc32Update(crc, blk, ADPCM_BLOCK_BYTES);
      blocks++;
    } else {
      ok = false;
    }
  }

  mic_->close();

  if (wav) {
    if (ok) {
      uint8_t hdr[44];
      wavHeader(hdr, samples * 2);
      ok = fseek(wav, 0, SEEK_SET) == 0 && fwrite(hdr, 1, sizeof(hdr), wav) == sizeof(hdr);
    }
    fclose(wav);
  }
  if (ima) fclose(ima);

  ok = ok && samples > 0;
  if (!ok) {
    // Never leave a half-written note for the index to trip over.
    unlink(wavPath);
    unlink(imaPath);
  }

  if (mono) heap_caps_free(mono);
  if (carry) heap_caps_free(carry);

  r.samples = samples;
  r.secs    = (uint16_t)((samples + MIC_SAMPLE_RATE / 2) / MIC_SAMPLE_RATE);
  r.bytes   = blocks * (uint32_t)ADPCM_BLOCK_BYTES;
  r.crc     = crc;
  r.ok      = ok;
  Serial.printf("[rec] %s N-%03u: %lu samples, %u s, %lu B adpcm, crc %08lx\n",
                ok ? "saved" : "FAILED", (unsigned)r.id, (unsigned long)samples,
                (unsigned)r.secs, (unsigned long)r.bytes, (unsigned long)crc);

  result_ = r;
  state_  = Done;
}

}  // namespace jota
