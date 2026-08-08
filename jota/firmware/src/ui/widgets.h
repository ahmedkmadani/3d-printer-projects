// ============================================================================
//  Jota — widget primitives
//
//  Every widget takes an `Adafruit_GFX&`, not the e-paper object. GxEPD2_BW
//  derives from Adafruit_GFX and GFXcanvas1 is an in-memory 1-bit canvas with
//  the same API, so one implementation serves both the device and the host
//  preview with no #ifdefs.
// ============================================================================
#pragma once

#include <Adafruit_GFX.h>

#include "ui/theme.h"

namespace jota {

// ---- Text --------------------------------------------------------------
// All four placement helpers correct for the glyph's left bearing, so an
// "x = MARGIN" label always has its INK edge at exactly MARGIN.

int16_t textWidth(Adafruit_GFX &g, const char *s);

void textLeft(Adafruit_GFX &g, const char *s, int16_t left, int16_t baseline);
void textRight(Adafruit_GFX &g, const char *s, int16_t right, int16_t baseline);
void textCentered(Adafruit_GFX &g, const char *s, int16_t cx, int16_t baseline);

// Centres the ink box on a point in BOTH axes — lets callers name a centre
// instead of back-computing a baseline.
void textCenteredAt(Adafruit_GFX &g, const char *s, int16_t cx, int16_t cy);

void textCenteredIn(Adafruit_GFX &g, const char *s, int16_t x, int16_t y,
                    int16_t w, int16_t h);

// Greedy word wrap. Returns the baseline of the last line drawn.
int16_t textWrapped(Adafruit_GFX &g, const char *s, int16_t x, int16_t baseline,
                    int16_t w, int16_t lineHeight, uint8_t maxLines);

// ---- Chrome ------------------------------------------------------------

void clear(Adafruit_GFX &g);

// Plain hairline divider.
void rule(Adafruit_GFX &g, int16_t x, int16_t y, int16_t w);

// Top strip: bold label left, reading right, hairline beneath. The right
// slot always holds the screen's one defining figure.
void statusBar(Adafruit_GFX &g, const char *left, const char *right);

// The big-figure pattern shared by splash and saved: display type, rule,
// caption — one helper so the two cannot drift apart.
void bigFigure(Adafruit_GFX &g, const GFXfont *bigFont, int16_t bigCap,
               const char *big, const char *caption);

// ---- Controls ----------------------------------------------------------

// One stadium row. `selected` inverts it: filled ink, knocked-out label.
void row(Adafruit_GFX &g, int16_t y, const char *label, bool selected);

// Vertical stack of rows, self-centring on CONTENT_MID. There is no y0 to
// get wrong — any row count is centred by construction.
void list(Adafruit_GFX &g, const char *const *items, uint8_t n, uint8_t sel);

// ---- Indicators --------------------------------------------------------

// Solid annulus. The outer edge is fixed by r; weight grows inward.
void ring(Adafruit_GFX &g, int16_t cx, int16_t cy, int16_t r, int16_t stroke);

// Rounded outline with an inset fill; frac in 0..1.
void progressBar(Adafruit_GFX &g, int16_t x, int16_t y, int16_t w, int16_t h,
                 float frac);

// `n` dots centred on cx; the first `active` are filled, the rest outlined.
void dots(Adafruit_GFX &g, int16_t cx, int16_t cy, uint8_t n, uint8_t active);

}  // namespace jota
