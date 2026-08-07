// ============================================================================
//  Jota — screens
//
//  Each function is a PURE draw: it takes a canvas and the view model and
//  paints one full screen. No SD, no WiFi, no delay(), no refresh calls —
//  the navigator owns all of that. This is what lets the host preview tool
//  render byte-identical output to the panel.
// ============================================================================
#pragma once

#include <Adafruit_GFX.h>

#include "app/model.h"

namespace jota {

void screenSplash(Adafruit_GFX &g);
void screenGuide(Adafruit_GFX &g);
void screenReady(Adafruit_GFX &g, const AppModel &m);
void screenRecording(Adafruit_GFX &g, const AppModel &m);
void screenSaved(Adafruit_GFX &g, const AppModel &m);
void screenMenu(Adafruit_GFX &g, const AppModel &m);
void screenChooseTag(Adafruit_GFX &g, const AppModel &m);
void screenSyncing(Adafruit_GFX &g, const AppModel &m);
void screenNoteView(Adafruit_GFX &g, const AppModel &m);

// The resting frame. E-paper holds its last image indefinitely, so this is
// what the object looks like sitting on a shelf — it is part of the product,
// not a shutdown detail.
void screenOff(Adafruit_GFX &g);

}  // namespace jota
