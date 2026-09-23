// ============================================================================
//  Jota — recorder
//
//  Mic to card, on its own task, so the panel keeps counting and BLE keeps
//  answering while a note is being spoken. The main loop starts it when the
//  RECORDING screen goes up, stops it when that screen comes down, and
//  collects the result whenever the task is done.
//
//  Two files are written at once from the same samples:
//    NNNN.wav  raw 16 kHz mono PCM — the archive
//    NNNN.ima  IMA ADPCM in 256-byte blocks — what the phone receives
//  so a note is servable the moment it is saved, with no second pass over
//  the card, and the CRC the phone will check is known before the note is
//  indexed.
// ============================================================================
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace jota {

class Mic;

struct RecResult {
  uint16_t id;
  uint16_t secs;     // rounded to the nearest second
  uint32_t samples;
  uint32_t bytes;    // size of the ADPCM copy
  uint32_t crc;      // CRC32 over the ADPCM copy
  bool     ok;       // false: nothing usable was written (files removed)
};

class Recorder {
 public:
  void begin(Mic *mic, bool sdOk);

  // Spawn the capture task for note `id`. False when it cannot start: no
  // card, no codec, or a recording already in flight.
  bool start(uint16_t id);
  void stop();

  bool running() const { return state_ == Running; }
  bool busy() const { return state_ != Idle; }

  // True exactly once per recording, when the task has finished and closed
  // its files. Hands back the result and returns the recorder to idle.
  bool takeResult(RecResult &out);

 private:
  enum State : uint8_t { Idle, Running, Stopping, Done };

  static void taskEntry(void *arg);
  void        run();

  Mic           *mic_     = nullptr;
  bool           sdOk_    = false;
  volatile State state_   = Idle;
  volatile bool  stopReq_ = false;
  RecResult      result_  = {};
};

}  // namespace jota
