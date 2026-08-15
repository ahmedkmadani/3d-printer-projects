// ============================================================================
//  Jota — design tokens
//
//  Design language: quiet, technical, minimal. Monospace for everything
//  structural so figures read as measurements; sans is reserved for prose.
//  No bezel, no ornament — type and whitespace carry it. Selection is shown
//  by inversion, and the only shapes are stadiums and circles.
//
//  Single source of truth. Screens name POSITIONS FROM THIS FILE, never their
//  own magic numbers.
// ============================================================================
#pragma once

#include <Adafruit_GFX.h>

namespace jota {

// ---- Palette -----------------------------------------------------------
// 1-bit only. These match GxEPD2's GxEPD_BLACK / GxEPD_WHITE, so identical
// draw code produces identical output on the panel and the host canvas.
static const uint16_t INK = 0x0000;  // black
static const uint16_t BG  = 0xFFFF;  // white

// ---- Canvas ------------------------------------------------------------
static const int16_t SCREEN_W  = 200;
static const int16_t SCREEN_H  = 200;
static const int16_t SAFE      = 4;   // lid crop safety — keep ink inside
static const int16_t MARGIN    = 14;  // left / right
static const int16_t CONTENT_W = SCREEN_W - 2 * MARGIN;  // 172
static const int16_t CENTER_X  = SCREEN_W / 2;           // 100

// ---- Vertical grid -----------------------------------------------------
// Base unit 4px. Every block centre and rule snaps to it; block heights fall
// where the fonts fall. CONTENT_MID is the single origin every centred
// screen is built around.
static const int16_t STATUS_BASELINE = 22;   // cap top lands at 12
static const int16_t STATUS_RULE_Y   = 28;
static const int16_t CONTENT_TOP     = 30;
static const int16_t CONTENT_BOTTOM  = 186;  // exclusive; last usable row 185
static const int16_t CONTENT_MID     = 108;  // (30 + 186) / 2
static const int16_t CONTENT_H       = CONTENT_BOTTOM - CONTENT_TOP;  // 156

static const int16_t GAP_S = 6;
static const int16_t GAP_M = 12;
static const int16_t GAP_L = 20;

// ---- Rows --------------------------------------------------------------
// One list component. Radius is always h/2, so every row is a stadium.
// 6 rows is the hard capacity: 6*22 + 5*5 = 157 > CONTENT_H by 1px.
static const int16_t ROW_H       = 22;
static const int16_t ROW_GAP     = 5;
static const uint8_t ROWS_MAX    = 5;

// ---- Circle ------------------------------------------------------------
// Drawn as a filled disc knocked out by a background disc, so the ring is
// solid at any weight rather than a stack of aliased outlines. The outer
// edge NEVER moves between idle and recording — only the annulus thickens
// inward, which keeps the transition additive and safe for partial refresh.
static const int16_t CIRCLE_CY            = CONTENT_MID;
static const int16_t CIRCLE_R             = 52;
static const int16_t CIRCLE_STROKE        = 3;
static const int16_t CIRCLE_STROKE_ACTIVE = 8;
static const int16_t DOT_R                = 4;

// ---- Indicators --------------------------------------------------------
static const int16_t PROGRESS_H = 10;
static const int16_t PROGRESS_Y = CONTENT_MID - PROGRESS_H / 2;

// ---- Battery -----------------------------------------------------------
// A stadium with a proportional fill — the same shape as a row and the same
// primitive as the progress bar, so the gauge introduces no new vocabulary.
// It sits below the ring (whose bottom edge is CIRCLE_CY + CIRCLE_R = 160)
// with the figure beneath it, and the last baseline lands at 185, inside
// CONTENT_BOTTOM.
//
// It is drawn identically on READY and RECORDING. That is not decoration: the
// Ready -> Recording transition is the one partial refresh in the product, and
// it is only safe because it is purely ADDITIVE ink. A gauge on one screen and
// not the other would leave the old one as residue.
// Gauge and figure sit on ONE line, not stacked: stacked, the pair had to
// start 4px under the ring to fit, which read as touching it.
static const int16_t GAUGE_W        = 30;
static const int16_t GAUGE_H        = 8;
static const int16_t GAUGE_GAP      = 7;
static const int16_t GAUGE_BASELINE = 178;         // 8px clear of the ring
static const int16_t GAUGE_Y        = GAUGE_BASELINE - 10;  // centred on the cap

// ---- Live regions ------------------------------------------------------
// Areas that change on their own while a screen is displayed. Refreshing
// only these keeps the panel quiet: a region update is both faster and
// visibly cleaner than pushing all 200x200 pixels for five digits.
static const int16_t TIMER_X = 48, TIMER_Y = 92, TIMER_W = 104, TIMER_H = 28;

// ---- Prose -------------------------------------------------------------
static const int16_t META_BASELINE   = 46;  // note time / duration line
static const int16_t PROSE_LEADING   = 18;
static const int16_t PROSE_TOP       = 66;  // first baseline
static const uint8_t PROSE_MAX_LINES = 6;   // last baseline 156 < CONTENT_BOTTOM

// ---- Cap heights -------------------------------------------------------
// Measured from the rendered panel output. Baselines are COMPUTED from these
// rather than guessed: a line of cap height c centred on cy has its baseline
// at cy + c/2.
static const int16_t CAP_LABEL    = 11;  // FreeMono(Bold) 9pt
static const int16_t CAP_FIGURE   = 15;  // FreeMonoBold 12pt
static const int16_t CAP_DISPLAY  = 23;  // FreeMonoBold 18pt
static const int16_t CAP_PROSE    = 13;  // FreeSans 9pt
static const int16_t CAP_WORDMARK = 28;  // FreeMonoBold 24pt

// ---- Fonts -------------------------------------------------------------
// Named for their JOB, not their metrics — naming them monoLarge/monoHuge is
// what let the same datum end up at two different sizes on adjacent screens.
// Four text roles plus one brand asset.
namespace font {
const GFXfont *label();     // FreeMonoBold9  — status label, row labels
const GFXfont *reading();   // FreeMono9      — status value, metadata
const GFXfont *figure();    // FreeMonoBold12 — the one live number on a screen
const GFXfont *display();   // FreeMonoBold18 — terminal confirmation only
const GFXfont *prose();     // FreeSans9      — transcripts only
const GFXfont *wordmark();  // FreeMonoBold24 — splash + off frame, not a style
}  // namespace font

}  // namespace jota
