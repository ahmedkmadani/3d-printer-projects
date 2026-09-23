// ============================================================================
//  Jota — note store
//
//  Owns the notes waiting to be handed to the phone, and serves their audio
//  by byte range so a dropped BLE connection resumes instead of restarting.
//
//  Everything lives on the microSD card under /sdcard/jota:
//    NNNN.wav   the raw 16 kHz mono recording — the archive, never sent
//    NNNN.ima   the IMA ADPCM copy the phone receives, 256-byte blocks
//    index.txt  one line per note: id, secs, bytes, crc, time, synced, tag
//
//  The recorder writes the two audio files; this store only indexes, serves
//  and deletes them. Ids never repeat, even across ERASE: the phone keys its
//  notes by them, and a reused id would land on top of an old note.
// ============================================================================
#pragma once

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "app/tags.h"

namespace jota {

static const char *const NOTES_DIR = "/sdcard/jota";

// "/sdcard/jota/0012.wav" — shared with the recorder so both agree on names.
void notePath(uint16_t id, const char *ext, char *out, size_t n);

struct NoteRec {
  uint16_t id;
  uint16_t secs;
  uint32_t bytes;  // size of the ADPCM copy the phone receives
  uint32_t crc;    // CRC32 over those bytes
  uint32_t time;   // unix seconds, 0 until the phone has set the clock
  bool     synced;

  // The tag chosen on SAVED after this note was recorded, or "" for none.
  // Travels to the phone in `index`.
  char tag[TAG_LEN_MAX + 1];
};

class NoteStore {
 public:
  // Load the index. With no card mounted the store is empty and add() fails,
  // so a recording with nowhere to go is reported rather than pretended.
  void begin(bool sdMounted);
  bool available() const { return sd_; }

  uint8_t        pending() const;
  uint8_t        count() const { return count_; }
  const NoteRec *at(uint8_t i) const { return i < count_ ? &notes_[i] : nullptr; }

  // Ids are handed out here, before the recording starts, so the files on
  // the card carry the number the panel shows.
  uint16_t nextId() const { return (uint16_t)(lastId_ + 1); }
  uint16_t lastId() const { return lastId_; }

  // Index a finished recording. The files must already be on the card.
  bool add(uint16_t id, uint16_t secs, uint32_t bytes, uint32_t crc,
           const char *tag);
  bool setTag(uint16_t id, const char *tag);

  // JSON array of the notes still waiting, as many as fit in `n` bytes —
  // always well-formed, possibly not complete. Returns bytes written.
  size_t indexJson(char *out, size_t n) const;

  // Serve up to `len` bytes of note `id` starting at `offset`. Returns the
  // number written, or 0 for an unknown id or an out-of-range offset.
  size_t read(uint16_t id, uint32_t offset, uint8_t *out, size_t len);

  // Mark synced, but ONLY if the CRC matches — a truncated transfer must
  // never be mistaken for a complete one.
  bool ack(uint16_t id, uint32_t crc);

  // The phone is the only clock source; stamp any notes recorded before it
  // first connected.
  void setClock(uint32_t unixSeconds);

  // Destroy every note, files included. ERASE is the only caller.
  void eraseAll();

 private:
  static const uint8_t MAX_NOTES = 32;
  NoteRec              notes_[MAX_NOTES];
  uint8_t              count_  = 0;
  bool                 sd_     = false;
  uint16_t             lastId_ = 0;

  // The file the phone is currently pulling, kept open across chunks: BLE
  // asks for 244 bytes at a time and an fopen per chunk is most of the cost.
  FILE    *rd_   = nullptr;
  uint16_t rdId_ = 0;

  NoteRec *find(uint16_t id);
  void     load();
  void     save() const;
  void     closeReader();
};

}  // namespace jota
