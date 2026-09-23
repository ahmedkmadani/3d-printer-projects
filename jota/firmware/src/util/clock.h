// ============================================================================
//  Jota — wall clock
//
//  Jota has no network, so the phone is its only time source: it writes Unix
//  seconds over BLE on every connect. That is pushed into the system clock,
//  which the ESP32-S3 keeps running on its RTC timer through deep sleep — so
//  once set it stays set until a real power-off, and a note recorded at 09:12
//  is stamped 09:12 rather than "whenever the phone next connected".
// ============================================================================
#pragma once

#include <stdint.h>
#include <sys/time.h>
#include <time.h>

namespace jota {

static const uint32_t CLOCK_SANE_AFTER = 1600000000UL;  // 2020-09-13

inline void clockSet(uint32_t unixSeconds) {
  struct timeval tv = {(time_t)unixSeconds, 0};
  settimeofday(&tv, nullptr);
}

// Unix seconds, or 0 while nobody has set the clock since the last power-off.
inline uint32_t clockNow() {
  const time_t t = time(nullptr);
  return (t > (time_t)CLOCK_SANE_AFTER) ? (uint32_t)t : 0;
}

}  // namespace jota
