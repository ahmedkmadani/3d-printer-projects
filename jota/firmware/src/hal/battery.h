// ============================================================================
//  Jota — battery gauge
//
//  A LiPo's voltage is a poor but usable proxy for charge. Three things make
//  the difference between a number worth showing and a number that lies:
//
//    1. CALIBRATION. Raw ADC counts on an ESP32-S3 are off by a good few
//       percent, board to board. analogReadMilliVolts() applies the per-chip
//       eFuse calibration, so it is used instead of analogRead().
//    2. LOAD. An e-paper refresh pulls hard enough to sag the pack by a
//       hundred millivolts or more. A sample taken during one reads as a
//       flat battery, so sampling is slow, median-filtered and smoothed.
//    3. THE CURVE. 3.7 V nominal is not 50%. Volts map to percent through a
//       discharge table, not a straight line.
//
//  And if the sense pin is not configured, this reports UNKNOWN rather than a
//  plausible number. A wrong charge reading is worse than none: it is the one
//  figure a person makes a decision on before leaving the house.
// ============================================================================
#pragma once

#include <stdint.h>

namespace jota {

// ---------------------------------------------------------------------------
// GUESS: NOT YET VERIFIED against this board's schematic.
//
// The pin map in firmware/README.md was checked against Waveshare's own
// examples and lists NO battery-sense pin, so this is left off until the real
// one is known. Set it to the GPIO that carries the divided pack voltage and
// the whole gauge comes alive; leave it at -1 and every surface honestly says
// the charge is unknown.
//
// Check the board's schematic or wiki, then set BOTH of these.
// ---------------------------------------------------------------------------
static const int   BATTERY_ADC_PIN = -1;

// Pack voltage divided by this reaches the pin. A 2:1 divider (two equal
// resistors) is the usual arrangement and keeps a 4.2 V pack at 2.1 V, inside
// what the ADC can read on the 11 dB attenuation this uses.
static const float BATTERY_DIVIDER = 2.0f;

// Below this, the device says so rather than just showing a small number.
static const uint8_t BATTERY_LOW_PCT = 15;

class Battery {
 public:
  void begin();

  // Call from the main loop. Samples on its own slow cadence, and only when
  // told the panel is idle — see [busy].
  void loop(uint32_t nowMs, bool busy = false);

  // False when there is no sense pin, or before the first sample lands.
  bool known() const { return known_; }

  uint8_t  percent() const { return pct_; }
  uint16_t millivolts() const { return mv_; }

  bool low() const { return known_ && pct_ <= BATTERY_LOW_PCT; }

  // What the advertisement carries. 0xFF means "unknown", which is why the
  // percent itself is only ever 0..100.
  uint8_t advByte() const { return known_ ? pct_ : 0xFF; }

 private:
  uint16_t sampleMillivolts() const;

  bool     known_    = false;
  uint8_t  pct_      = 0;
  uint16_t mv_       = 0;
  uint32_t nextMs_   = 0;
  uint32_t emaMv_    = 0;   // smoothed, in millivolts
};

// Exposed for the host preview and for tests: the discharge curve, without
// any hardware behind it.
uint8_t batteryPercentForMillivolts(uint16_t mv);

}  // namespace jota
