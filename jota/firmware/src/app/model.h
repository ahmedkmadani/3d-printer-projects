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

  // "HH:MM" shown in the status strip. Phase 1 drives this from millis();
  // phase 2 sources it from the PCF85063 RTC (I2C 47/48), set over NTP.
  const char *clock;

  // Recording
  uint16_t recSecs;

  // Phone link. Jota has no WiFi: the phone pulls notes over BLE and does the
  // transcription, so there are no credentials and no API key on the device.
  const char *pairCode;  // shown while pairing, nullptr otherwise
  // nav asks for a code; main mints one from the hardware RNG and fills
  // pairCode in. Kept apart so nav stays free of the radio.
  bool needPairCode;
  bool        paired;    // a phone holds the bond
  bool        authed;    // a phone is connected AND authenticated right now
  uint8_t     pending;   // notes recorded but not yet handed to the phone

  // A phone has asked to authenticate and been refused because it is not the
  // owner. Set by the link, cleared by the navigator when it puts PAIR up.
  //
  // This is what makes "possession outranks the bond" true rather than merely
  // written down: the code only exists while the PAIR screen is showing, and
  // once a device is owned it has no other reason to show it. Without this a
  // second phone can never present a code, because there is no code to read.
  bool pairAsked;

  // This device's own id, "7f3a91c4". Shown as JOTA-91C4 so two Jotas in the
  // same room are told apart by looking at them, not by guessing.
  const char *deviceId;

  // Charge, 0..100. `batteryKnown` is false when there is no sense pin wired
  // — the screens then show a dash rather than inventing a figure, because
  // this is the one number someone acts on before leaving the house.
  bool    batteryKnown;
  uint8_t batteryPct;

  // Where the cursor sits in the tag offer on SAVED.
  //
  // Tags are chosen AFTER a recording now, not armed before it. Arming was the
  // only gesture that fit two buttons while the list lived behind a menu — but
  // it meant deciding what a note was about before saying it, and a tag armed
  // and forgotten silently filed every later note under a heading chosen once.
  uint8_t tagSel;

  // The phone's tag list, as last written over BLE. Lives in the model so the
  // TAGS screen and the `tags` characteristic are reading the same bytes.
  TagList tags;

  // Currently viewed note
  NoteMeta note;
};

// Tags are NOT a fixed table — they are whatever the phone last wrote. See
// AppModel::tags and app/tags.h.

}  // namespace jota
