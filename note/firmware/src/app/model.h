// ============================================================================
//  Jota — view model
//
//  Everything a screen is allowed to know. Screens receive this struct and
//  draw it; they never read hardware. That keeps them pure enough to render
//  on the host preview, and stops phase-2 features (SD, WiFi, audio) from
//  leaking into layout code.
// ============================================================================
#pragma once

#include <stdint.h>

namespace jota {

struct NoteMeta {
  uint16_t    id;    // 12  -> "N-012"
  const char *time;  // "14:32"
  const char *text;  // transcript, or nullptr while untranscribed
  uint16_t    secs;  // duration
};

struct AppModel {
  // Library
  uint16_t noteCount;
  uint16_t noteIndex;  // 1-based position of the note being viewed

  // "HH:MM" shown in the status strip. Phase 1 drives this from millis();
  // phase 2 sources it from the PCF85063 RTC (I2C 47/48), set over NTP.
  const char *clock;

  // Recording
  uint16_t recSecs;

  // Sync
  uint8_t syncDone;
  uint8_t syncTotal;

  // Provisioning / network
  const char *pairCode;  // shown while pairing, nullptr otherwise
  const char *ssid;      // connected network, nullptr if none
  bool        wifiUp;

  // Selection indices
  uint8_t menuSel;
  uint8_t tagSel;

  // Currently viewed note
  NoteMeta note;
};

// Fixed label tables. `extern` so the firmware and the preview tool draw from
// the same list.
extern const char *const MENU_ITEMS[];
extern const uint8_t     MENU_COUNT;

extern const char *const TAG_ITEMS[];
extern const uint8_t     TAG_COUNT;

}  // namespace jota
