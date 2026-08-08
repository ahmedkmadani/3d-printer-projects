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

  // The code the phone must present. Shown on the e-paper — possession of the
  // device is the whole security model.
  void setPairCode(const char *code);

  bool connected() const;
  bool authed() const;

  // Advertise fast for a while (after a recording, or when SYNC is pressed)
  // so the phone notices quickly, then fall back to the slow interval.
  void nudge(uint32_t nowMs);
};

}  // namespace jota
