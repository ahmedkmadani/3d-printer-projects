// ============================================================================
//  Jota — screen navigator
//
//  Owns which screen is showing, how it is entered, and whether the next
//  paint needs a full or partial refresh. Deliberately free of Arduino calls
//  (time arrives as a parameter) so the flow can be exercised off-device.
// ============================================================================
#pragma once

#include <stdint.h>

#include <Adafruit_GFX.h>

#include "app/model.h"
#include "hal/buttons.h"

namespace jota {

// FIVE screens. There were ten.
//
// The six that went were all the device trying to be a small, bad phone:
// MENU existed only to reach them; NOTES/NOTE VIEW showed a transcript the
// device by design never has; SYNCING was a destination for something that
// happens by itself and cannot be started from here anyway; CHOOSE TAG became
// a step on SAVED, where you already know what you just said; SPLASH and GUIDE
// were shown on every single boot to a person who owns one of these.
//
// What is left is a capture instrument. The phone is the library.
enum class Screen : uint8_t {
  Ready,
  Recording,
  Saved,  // and, for ten seconds, the tag picker
  Pair,   // shows itself when no phone owns this device
  Erase,  // both buttons, twice
};

// Dispatch to the matching screen function.
void renderScreen(Adafruit_GFX &g, Screen s, const AppModel &m);

// A sub-area of the panel to refresh on its own.
struct Rect {
  int16_t x, y, w, h;
};

class Nav {
 public:
  void begin(uint32_t nowMs);

  void handle(BtnEvent e, AppModel &m, uint32_t nowMs);
  void tick(uint32_t nowMs, AppModel &m);

  Screen screen() const { return s_; }
  bool   dirty() const { return dirty_; }
  bool   needsFull() const { return needsFull_; }
  bool   powerOff() const { return powerOff_; }

  // Set when the user answered the ERASE question with a second both-button
  // hold. Nav owns no storage and no radio — main.cpp does the wiping — which
  // is what keeps every screen renderable on the host preview.
  bool   wipeRequested() const { return wipeRequested_; }
  void   clearWipeRequest() { wipeRequested_ = false; }
  void   clearDirty() { dirty_ = false; }

  // When set, only this rectangle needs pushing to the panel.
  bool        hasRegion() const { return hasRegion_; }
  const Rect &region() const { return region_; }

  // Repaint without changing screen or restarting its timers.
  void markDirty(bool full = false) {
    dirty_      = true;
    needsFull_  = full;
    hasRegion_  = false;
  }

  // Repaint only `r` — used when a single element changed and the rest of
  // the screen is provably identical.
  void markDirtyRegion(const Rect &r) {
    dirty_     = true;
    needsFull_ = false;
    hasRegion_ = true;
    region_    = r;
  }

  // REFRESH POLICY. Screen changes go out as a whole-screen PARTIAL refresh:
  // instant, no black-white flash. Ghosting is paid off by the de-ghosting
  // full refresh main.cpp schedules on the next quiet screen, and by the
  // full refresh every wake (begin()). This is how Pala Note's panel feels
  // "lit": one full clear at boot, partials for everything after.
  //
  // It used to be FULL by default, on the observation that a partial left
  // the outgoing layout as residue. Two things changed: RECORDING is now the
  // panel inverted, so both of its transitions change every pixel, and the
  // rest of the screens share one layout grid, so what carries over between
  // them is mostly identical ink. If real hardware still shows residue, flip
  // this ONE constant back and every go() is full again.
  static const bool kScreenChangeFull = false;
  void go(Screen s, uint32_t nowMs, bool full = kScreenChangeFull);

  // Called once the panel has finished showing the current screen. Timed
  // screens measure their dwell from here, not from when go() was called: a
  // full refresh blocks for ~2s, which would otherwise consume most or all
  // of a 1.8s confirmation before it was ever visible.
  void paintDone(uint32_t nowMs) {
    if (!justEntered_) return;
    justEntered_ = false;
    enteredMs_   = nowMs;
    lastTickMs_  = nowMs;
  }

 private:
  Screen   s_          = Screen::Ready;
  bool     wasAuthed_  = false;  // edge-detects a phone connecting
  bool     dirty_      = true;
  bool     needsFull_  = true;
  bool     hasRegion_  = false;
  bool     justEntered_ = true;
  Rect     region_     = {0, 0, 0, 0};
  bool     powerOff_   = false;
  bool     wipeRequested_ = false;
  uint32_t enteredMs_  = 0;
  uint32_t lastTickMs_ = 0;
};

}  // namespace jota
