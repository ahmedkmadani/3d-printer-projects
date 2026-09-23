// ============================================================================
//  Jota — note store (implementation)
// ============================================================================
#include "app/notes.h"

#include <Arduino.h>
#include <string.h>
#include <unistd.h>

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
  Serial.printf("[notes] %u indexed, %u pending, last id %u\n",
                (unsigned)count_, (unsigned)pending(), (unsigned)lastId_);
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
  r.time   = 0;
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
  char path[48];
  for (uint8_t i = 0; i < count_; ++i) {
    notePath(notes_[i].id, "wav", path, sizeof(path));
    unlink(path);
    notePath(notes_[i].id, "ima", path, sizeof(path));
    unlink(path);
  }
  count_ = 0;
  // lastId_ survives on purpose: see the header.
  save();
}

}  // namespace jota
