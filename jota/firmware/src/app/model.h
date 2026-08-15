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

#include "app/tags.h"

namespace jota {

struct NoteMeta {
  uint16_t    id;    // 12  -> "N-012"
  const char *time;  // "14:32"
  const char *text;  // transcript, or nullptr while untranscribed
  uint16_t    secs;  // duration
  const char *tag;   // armed tag at the moment it was recorded, or nullptr
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

  // Phone link. Jota has no WiFi: the phone pulls notes over BLE and does the
  // transcription, so there are no credentials and no API key on the device.
  const char *pairCode;  // shown while pairing, nullptr otherwise
  bool        paired;    // a phone holds the bond
  bool        authed;    // a phone is connected AND authenticated right now
  uint8_t     pending;   // notes recorded but not yet handed to the phone

  // This device's own id, "7f3a91c4". Shown as JOTA-91C4 so two Jotas in the
  // same room are told apart by looking at them, not by guessing.
  const char *deviceId;

  // Charge, 0..100. `batteryKnown` is false when there is no sense pin wired
  // — the screens then show a dash rather than inventing a figure, because
  // this is the one number someone acts on before leaving the house.
  bool    batteryKnown;
  uint8_t batteryPct;

  // Selection indices
  uint8_t menuSel;
  uint8_t tagSel;   // where the cursor is on the TAGS screen

  // The tag ARMED for the next recording, as an index into `tags`, or
  // TAG_NONE. Pre-selection is the only tagging interaction that fits two
  // buttons: choosing after the fact would put a third decision in the middle
  // of press-speak-press, which is the whole speed of the product.
  uint8_t tagArmed;

  // The phone's tag list, as last written over BLE. Lives in the model so the
  // TAGS screen and the `tags` characteristic are reading the same bytes.
  TagList tags;

  // Currently viewed note
  NoteMeta note;
};

// Fixed label tables. `extern` so the firmware and the preview tool draw from
// the same list.
extern const char *const MENU_ITEMS[];
extern const uint8_t     MENU_COUNT;

// Tags are NOT a fixed table — they are whatever the phone last wrote. See
// AppModel::tags and app/tags.h.

}  // namespace jota
