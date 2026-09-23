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

// Verified against Waveshare's user_config.h for this board. Public because
// main.cpp arms the same two pins as deep-sleep wake sources.
static const uint8_t BTN_PIN_BOOT = 0;
static const uint8_t BTN_PIN_PWR  = 18;

enum class BtnEvent : uint8_t {
  None,
  BootShort,  // record / stop / confirm
  BootLong,   // same as BootShort everywhere — see nav.cpp
  PwrShort,   // next tag
  PwrLong,    // power off
  BothLong,   // erase everything (asks first)
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

  Btn  boot_{};
  Btn  pwr_{};
  bool bothFired_ = false;  // one BothLong per pair of presses

  // Returns 0 = nothing, 1 = short release, 2 = long threshold crossed.
  uint8_t update(Btn &b, uint32_t nowMs);
};

}  // namespace jota
