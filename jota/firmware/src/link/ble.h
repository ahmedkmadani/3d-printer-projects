// ============================================================================
//  Jota — BLE link
//
//  Implements the service documented in docs/ble-service.md. Jota is a
//  peripheral: it cannot contact the phone, it can only advertise. The
//  advertisement carries the pending-note count, so the phone can see whether
//  anything is waiting WITHOUT connecting — if it is zero the app never wakes
//  and neither side spends battery.
//
//  Transfers are pumped from loop(), never from a callback: a BLE callback
//  runs on the host stack's task and must return promptly.
// ============================================================================
#pragma once

#include <stdint.h>

#include "app/model.h"
#include "app/notes.h"

namespace jota {

class Link {
 public:
  void begin(NoteStore &store, AppModel &model);
  void loop(uint32_t nowMs);

  // Charge for the advertisement and for `status`, 0..100, or 0xFF when this
  // board has no battery-sense pin wired. Unknown is broadcast as unknown: a
  // fabricated percentage is the one figure a person actually acts on.
  void setBattery(uint8_t pct);

  // The code the phone must present. Shown on the e-paper — possession of the
  // device is the whole security model.
  // Mint a FRESH six digits and publish them. The code lives only in RAM and
  // only while an offer is open: it is what proves the phone can see this
  // panel, so a code that outlives the offer proves nothing.
  const char *newPairCode();
  void        clearPairCode();
  void        setPairCode(const char *code);

  bool connected() const;
  bool authed() const;

  // True once, after a phone's tag write has been applied to the model. The
  // panel is not repainted from here — the caller owns the display.
  bool takeTagsChanged();

  // Advertise fast for a while (after a recording, or when SYNC is pressed)
  // so the phone notices quickly, then fall back to the slow interval.
  void nudge(uint32_t nowMs);

  // Drop the stored owner and the current connection's authentication, so the
  // device is a stranger to every phone again. ERASE only.
  void forgetOwner();

  // True once, after the owner wrote a valid `erase` request. The wipe itself
  // happens in main's loop — the same path as the two-button gesture —
  // because a BLE callback may not spend seconds deleting files.
  bool takeEraseRequested();

  // Tell the phone the wipe it asked for is done, on the still-open
  // connection: a `status` notify of {"error":"erased"}.
  void confirmErased();

  /// Does a phone hold the bond? Read at boot so an already-owned device does
  /// not offer a pairing code to the room every time it is switched on.
  bool hasOwner() const;
};

}  // namespace jota
