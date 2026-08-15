// ============================================================================
//  Jota — note store
//
//  Owns the notes waiting to be handed to the phone, and serves their audio
//  by byte range so a dropped BLE connection resumes instead of restarting.
//
//  PHASE 2 STUB: the audio is SYNTHESISED, not recorded. The ADPCM encoder is
//  real and is the one the microphone will use; only the PCM source is fake.
//  That means the phone app can be built and tested end to end — connect,
//  pair, index, fetch, resume, ack — before the mic, codec or SD card exist.
//  Swapping the source for the recorder does not change the protocol.
// ============================================================================
#pragma once

#include <stddef.h>
#include <stdint.h>

#include "app/tags.h"

namespace jota {

struct NoteRec {
  uint16_t id;
  uint16_t secs;
  uint32_t bytes;  // size of the ADPCM copy the phone receives
  uint32_t crc;    // CRC32 over those bytes
  uint32_t time;   // unix seconds, 0 until the phone has set the clock
  bool     synced;

  // The tag armed on the TAGS screen when this note was recorded, or "" for
  // none. Travels to the phone in `index`, which is what makes tagging on the
  // device worth anything at all — before this, a tag chosen on the panel went
  // nowhere and was attached to nothing.
  char tag[TAG_LEN_MAX + 1];
};

class NoteStore {
 public:
  void begin();

  uint8_t       pending() const;
  uint8_t       count() const { return count_; }
  const NoteRec *at(uint8_t i) const { return i < count_ ? &notes_[i] : nullptr; }

  // JSON array of the notes still waiting. Returns bytes written.
  size_t indexJson(char *out, size_t n) const;

  // Serve up to `len` bytes of note `id` starting at `offset`. Returns the
  // number written, or 0 for an unknown id or an out-of-range offset.
  // Offsets need not be block-aligned; the store handles the seek.
  size_t read(uint16_t id, uint32_t offset, uint8_t *out, size_t len);

  // Mark synced, but ONLY if the CRC matches — a truncated transfer must
  // never be mistaken for a complete one.
  bool ack(uint16_t id, uint32_t crc);

  // The phone is the only clock source; stamp any notes recorded before it
  // first connected.
  void setClock(uint32_t unixSeconds);

  // Destroy every note. ERASE is the only caller: nothing else on this device
  // may delete a recording, because there is no undo and no second copy until
  // the phone has taken one.
  void eraseAll();

 private:
  static const uint8_t MAX_NOTES = 8;
  NoteRec              notes_[MAX_NOTES];
  uint8_t              count_ = 0;
};

}  // namespace jota
