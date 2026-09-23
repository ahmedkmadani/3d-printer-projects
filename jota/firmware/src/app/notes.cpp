// ============================================================================
//  Jota — note store (implementation)
// ============================================================================
#include "app/notes.h"

#include <Arduino.h>
#include <dirent.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "audio/adpcm.h"
#include "util/clock.h"
#include "util/crc32.h"

namespace jota {

static const char *const INDEX_PATH = "/sdcard/jota/index.txt";
static const char *const INDEX_TMP  = "/sdcard/jota/index.tmp";

void notePath(uint16_t id, const char *ext, char *out, size_t n) {
  snprintf(out, n, "%s/%04u.%s", NOTES_DIR, (unsigned)id, ext);
}

// ---- Index file ----------------------------------------------------------
// Line 1:  "jota 1 <lastId>"
// Then:    "<id> <secs> <bytes> <crc hex> <time> <synced> <tag or ->"

void NoteStore::load() {
  count_  = 0;
  lastId_ = 0;
  FILE *f = fopen(INDEX_PATH, "r");
  if (!f) return;

  char line[160];
  if (fgets(line, sizeof(line), f)) {
    unsigned v = 0, last = 0;
    if (sscanf(line, "jota %u %u", &v, &last) == 2) lastId_ = (uint16_t)last;
  }
  while (count_ < MAX_NOTES && fgets(line, sizeof(line), f)) {
    unsigned id, secs, synced;
    unsigned long bytes, crc, time;
    char tag[TAG_LEN_MAX + 1] = {0};
    const int got = sscanf(line, "%u %u %lu %lx %lu %u %15s", &id, &secs, &bytes,
                           &crc, &time, &synced, tag);
    if (got < 6) continue;
    NoteRec &r = notes_[count_++];
    r.id     = (uint16_t)id;
    r.secs   = (uint16_t)secs;
    r.bytes  = (uint32_t)bytes;
    r.crc    = (uint32_t)crc;
    r.time   = (uint32_t)time;
    r.synced = synced != 0;
    if (got == 7 && strcmp(tag, "-") != 0) {
      strncpy(r.tag, tag, TAG_LEN_MAX);
      r.tag[TAG_LEN_MAX] = 0;
    } else {
      r.tag[0] = 0;
    }
    if (r.id > lastId_) lastId_ = r.id;
  }
  fclose(f);
}

void NoteStore::save() const {
  if (!sd_) return;
  FILE *f = fopen(INDEX_TMP, "w");
  if (!f) {
    Serial.println("[notes] cannot write index");
    return;
  }
  fprintf(f, "jota 1 %u\n", (unsigned)lastId_);
  for (uint8_t i = 0; i < count_; ++i) {
    const NoteRec &r = notes_[i];
    fprintf(f, "%u %u %lu %08lx %lu %u %s\n", (unsigned)r.id, (unsigned)r.secs,
            (unsigned long)r.bytes, (unsigned long)r.crc, (unsigned long)r.time,
            r.synced ? 1u : 0u, r.tag[0] ? r.tag : "-");
  }
  fclose(f);
  // Replace, not overwrite in place: a power cut mid-write leaves the old
  // index intact rather than a truncated one.
  unlink(INDEX_PATH);
  if (rename(INDEX_TMP, INDEX_PATH) != 0) Serial.println("[notes] index rename failed");
}

// ---- Store ---------------------------------------------------------------

void NoteStore::begin(bool sdMounted) {
  sd_ = sdMounted;
  closeReader();
  if (!sd_) {
    count_ = 0;
    Serial.println("[notes] no card: nothing to record onto");
    return;
  }
  load();
  const uint8_t recovered = recoverOrphans();
  Serial.printf("[notes] %u indexed, %u pending, last id %u%s\n",
                (unsigned)count_, (unsigned)pending(), (unsigned)lastId_,
                recovered ? " (after recovery)" : "");
}

NoteRec *NoteStore::find(uint16_t id) {
  for (uint8_t i = 0; i < count_; ++i)
    if (notes_[i].id == id) return &notes_[i];
  return nullptr;
}

uint8_t NoteStore::pending() const {
  uint8_t n = 0;
  for (uint8_t i = 0; i < count_; ++i)
    if (!notes_[i].synced) n++;
  return n;
}

bool NoteStore::add(uint16_t id, uint16_t secs, uint32_t bytes, uint32_t crc,
                    const char *tag) {
  if (!sd_) return false;
  if (count_ >= MAX_NOTES) {
    // Drop the oldest note the phone already holds. Its files stay on the
    // card; only the index forgets it.
    uint8_t victim = MAX_NOTES;
    for (uint8_t i = 0; i < count_; ++i)
      if (notes_[i].synced) { victim = i; break; }
    if (victim == MAX_NOTES) {
      Serial.println("[notes] index full of unsynced notes; sync before recording more");
      return false;
    }
    memmove(&notes_[victim], &notes_[victim + 1],
            (size_t)(count_ - victim - 1) * sizeof(NoteRec));
    count_--;
  }
  NoteRec &r = notes_[count_++];
  memset(&r, 0, sizeof(r));
  r.id     = id;
  r.secs   = secs;
  r.bytes  = bytes;
  r.crc    = crc;
  r.time   = clockNow();  // 0 until the phone has set the clock; see setClock
  r.synced = false;
  if (tag) {
    strncpy(r.tag, tag, TAG_LEN_MAX);
    r.tag[TAG_LEN_MAX] = 0;
  }
  if (id > lastId_) lastId_ = id;
  save();
  return true;
}

bool NoteStore::setTag(uint16_t id, const char *tag) {
  NoteRec *r = find(id);
  if (!r) return false;
  char next[TAG_LEN_MAX + 1] = {0};
  if (tag) {
    strncpy(next, tag, TAG_LEN_MAX);
    next[TAG_LEN_MAX] = 0;
  }
  if (strcmp(next, r->tag) == 0) return true;  // nothing to write
  strcpy(r->tag, next);
  save();
  return true;
}

size_t NoteStore::indexJson(char *out, size_t n) const {
  if (n < 3) return 0;
  size_t w = 0;
  out[w++] = '[';
  bool first = true;
  for (uint8_t i = 0; i < count_; ++i) {
    const NoteRec &r = notes_[i];
    if (r.synced) continue;
    char item[128];
    const int len = snprintf(item, sizeof(item),
                             "%s{\"id\":%u,\"secs\":%u,\"bytes\":%lu,"
                             "\"crc\":\"%08lx\",\"time\":%lu,\"tag\":\"%s\"}",
                             first ? "" : ",", (unsigned)r.id, (unsigned)r.secs,
                             (unsigned long)r.bytes, (unsigned long)r.crc,
                             (unsigned long)r.time, r.tag);
    if (len < 0) break;
    // Leave room for the closing bracket and the terminator: a cut-off
    // entry is worse than a missing one, because the phone cannot parse it.
    if (w + (size_t)len + 2 > n) break;
    memcpy(out + w, item, (size_t)len);
    w += (size_t)len;
    first = false;
  }
  out[w++] = ']';
  out[w]   = 0;
  return w;
}

void NoteStore::closeReader() {
  if (rd_) fclose(rd_);
  rd_   = nullptr;
  rdId_ = 0;
}

size_t NoteStore::read(uint16_t id, uint32_t offset, uint8_t *out, size_t len) {
  const NoteRec *r = find(id);
  if (!r || offset >= r->bytes) return 0;
  if (offset + len > r->bytes) len = r->bytes - offset;

  if (rd_ && rdId_ != id) closeReader();
  if (!rd_) {
    char path[48];
    notePath(id, "ima", path, sizeof(path));
    rd_ = fopen(path, "rb");
    if (!rd_) {
      Serial.printf("[notes] %s missing\n", path);
      return 0;
    }
    rdId_ = id;
  }
  if (fseek(rd_, (long)offset, SEEK_SET) != 0) return 0;
  return fread(out, 1, len, rd_);
}

bool NoteStore::ack(uint16_t id, uint32_t crc) {
  NoteRec *r = find(id);
  if (!r) return false;
  if (r->crc != crc) return false;  // truncated or corrupted
  if (r->synced) return true;
  r->synced = true;
  if (rdId_ == id) closeReader();
  save();
  return true;
}

void NoteStore::setClock(uint32_t unixSeconds) {
  bool changed = false;
  for (uint8_t i = 0; i < count_; ++i) {
    if (notes_[i].time == 0) {
      notes_[i].time = unixSeconds;
      changed        = true;
    }
  }
  if (changed) save();
}

void NoteStore::eraseAll() {
  closeReader();
  count_ = 0;
  // Sweep the directory rather than the index: an orphan the index never
  // met is still a recording, and ERASE promises there are none left.
  DIR *d = opendir(NOTES_DIR);
  if (d) {
    struct dirent *e;
    char path[64];
    while ((e = readdir(d)) != nullptr) {
      const size_t n = strlen(e->d_name);
      if (n < 5) continue;
      const char *ext = e->d_name + n - 4;
      if (strcasecmp(ext, ".wav") != 0 && strcasecmp(ext, ".ima") != 0) continue;
      snprintf(path, sizeof(path), "%s/%s", NOTES_DIR, e->d_name);
      unlink(path);
    }
    closedir(d);
  }
  // lastId_ survives on purpose: see the header.
  save();
}

// ---- Orphans -------------------------------------------------------------

// Rebuild NNNN.ima from NNNN.wav and index the note. The WAV is the master:
// the recorder syncs it to the card every few seconds while recording, so a
// power cut leaves a valid file with a zero-length header, and the ADPCM copy
// is cheaper to remake than to trust.
static void putLE32(uint8_t *p, uint32_t v) {
  p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24);
}

static bool rebuildFromWav(uint16_t id, uint32_t *secsOut, uint32_t *bytesOut,
                           uint32_t *crcOut) {
  char wavPath[48], imaPath[48];
  notePath(id, "wav", wavPath, sizeof(wavPath));
  notePath(id, "ima", imaPath, sizeof(imaPath));

  struct stat st;
  if (stat(wavPath, &st) != 0 || st.st_size < 44) return false;
  const uint32_t dataBytes = (uint32_t)(st.st_size - 44) & ~1u;
  const uint32_t samples   = dataBytes / 2;

  FILE *wav = fopen(wavPath, "r+b");
  if (!wav) return false;

  // Patch the header from the file's real length. The recorder writes it
  // only at a clean stop, so an orphan's says zero.
  uint8_t h[44];
  memcpy(h, "RIFF", 4);           putLE32(h + 4, 36 + dataBytes);
  memcpy(h + 8, "WAVEfmt ", 8);   putLE32(h + 16, 16);
  h[20] = 1; h[21] = 0; h[22] = 1; h[23] = 0;
  putLE32(h + 24, 16000);         putLE32(h + 28, 32000);
  h[32] = 2; h[33] = 0; h[34] = 16; h[35] = 0;
  memcpy(h + 36, "data", 4);      putLE32(h + 40, dataBytes);
  bool ok = fseek(wav, 0, SEEK_SET) == 0 && fwrite(h, 1, 44, wav) == 44;

  FILE *ima = ok ? fopen(imaPath, "wb") : nullptr;
  ok = ok && ima;

  uint32_t crc = 0, blocks = 0;
  if (ok) {
    int16_t pcm[ADPCM_BLOCK_SAMPLES];
    uint8_t blk[ADPCM_BLOCK_BYTES];
    uint32_t done = 0;
    while (ok && done < samples) {
      uint32_t take = samples - done;
      if (take > ADPCM_BLOCK_SAMPLES) take = ADPCM_BLOCK_SAMPLES;
      if (fread(pcm, sizeof(int16_t), take, wav) != take) { ok = false; break; }
      if (take < ADPCM_BLOCK_SAMPLES)
        memset(pcm + take, 0, (ADPCM_BLOCK_SAMPLES - take) * sizeof(int16_t));
      adpcmEncodeBlock(pcm, blk);
      if (fwrite(blk, 1, ADPCM_BLOCK_BYTES, ima) != ADPCM_BLOCK_BYTES) { ok = false; break; }
      crc = crc32Update(crc, blk, ADPCM_BLOCK_BYTES);
      blocks++;
      done += take;
    }
  }
  if (ima) fclose(ima);
  fclose(wav);
  if (!ok) {
    unlink(imaPath);
    return false;
  }
  *secsOut  = (samples + 8000) / 16000;
  *bytesOut = blocks * (uint32_t)ADPCM_BLOCK_BYTES;
  *crcOut   = crc;
  return true;
}

uint8_t NoteStore::recoverOrphans() {
  if (!sd_) return 0;
  DIR *d = opendir(NOTES_DIR);
  if (!d) return 0;

  uint8_t recovered = 0;
  struct dirent *e;
  while ((e = readdir(d)) != nullptr) {
    unsigned id = 0;
    char ext[8] = {0};
    if (sscanf(e->d_name, "%4u.%7s", &id, ext) != 2) continue;
    if (strcasecmp(ext, "wav") != 0 || id == 0 || id > 0xFFFF) continue;
    if (find((uint16_t)id)) continue;  // indexed: not an orphan

    char path[48];
    notePath((uint16_t)id, "wav", path, sizeof(path));
    struct stat st;
    if (stat(path, &st) != 0) continue;
    if (st.st_size < 44 + 2 * 8000) {
      // Under half a second: the power went before anything was said. Not
      // worth keeping to be rediscovered on every boot.
      unlink(path);
      notePath((uint16_t)id, "ima", path, sizeof(path));
      unlink(path);
      Serial.printf("[notes] dropped %s: too short to be a note\n", e->d_name);
      continue;
    }

    uint32_t secs = 0, bytes = 0, crc = 0;
    if (!rebuildFromWav((uint16_t)id, &secs, &bytes, &crc)) {
      // Could not read or re-encode it. The WAV is someone's words, so it
      // stays on the card for the next boot, or for a card reader.
      Serial.printf("[notes] could not recover %s; left on card\n", e->d_name);
      continue;
    }
    if (add((uint16_t)id, (uint16_t)secs, bytes, crc, nullptr)) {
      recovered++;
      Serial.printf("[notes] recovered N-%03u: %lu s, %lu B adpcm\n", id,
                    (unsigned long)secs, (unsigned long)bytes);
    }
  }
  closedir(d);
  return recovered;
}

}  // namespace jota
