// ============================================================================
//  Jota — button HAL
//
//  The board has exactly two buttons: BOOT (GPIO0) and PWR (GPIO18). Because
//  firmware holds the power latch (GPIO17), PWR is fully software-interpreted
//  and a long press is ours to define.
// ============================================================================
#pragma once

#include <stdint.h>

namespace jota {

enum class BtnEvent : uint8_t {
  None,
  BootShort,  // select / confirm / record
  BootLong,   // back
  PwrShort,   // next item
  PwrLong,    // power off
};

class Buttons {
 public:
  void begin();

  // Call every loop with millis(). Returns at most one event per call:
  // a long press fires the moment the threshold is crossed (so it feels
  // immediate), and the matching release is then swallowed.
  BtnEvent poll(uint32_t nowMs);

 private:
  struct Btn {
    uint8_t  pin;
    bool     down;       // debounced state
    bool     raw;        // last raw sample
    uint32_t changedMs;  // when raw last changed
    uint32_t downMs;     // when the debounced press began
    bool     longFired;
  };

  Btn boot_{};
  Btn pwr_{};

  // Returns 0 = nothing, 1 = short release, 2 = long threshold crossed.
  uint8_t update(Btn &b, uint32_t nowMs);
};

}  // namespace jota
