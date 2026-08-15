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

enum class Screen : uint8_t {
  Splash,
  Guide,
  Ready,
  Recording,
  Saved,
  Menu,
  ChooseTag,
  Syncing,
  NoteView,
  Pair,
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

  // A screen change replaces the whole composition, and a partial update
  // cannot do that cleanly — the outgoing layout stays as visible residue.
  // So screen changes are FULL by default; pass full=false only when the
  // change is provably additive ink (see Ready -> Recording).
  void go(Screen s, uint32_t nowMs, bool full = true);

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
  Screen   s_          = Screen::Splash;
  bool     wasAuthed_  = false;  // edge-detects a phone connecting
  bool     dirty_      = true;
  bool     needsFull_  = true;
  bool     hasRegion_  = false;
  bool     justEntered_ = true;
  Rect     region_     = {0, 0, 0, 0};
  bool     powerOff_   = false;
  uint32_t enteredMs_  = 0;
  uint32_t lastTickMs_ = 0;
};

}  // namespace jota
