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
// Three, not five. The list now sits BELOW the head rule, which leaves 102 px
// — and four rows need 103. Five used to "fit" only by centring on the whole
// screen, which put the top row straight through the word Saved.
static const uint8_t ROWS_MAX    = 3;

// ---- Circle ------------------------------------------------------------
// Drawn as a filled disc knocked out by a background disc, so the ring is
// solid at any weight rather than a stack of aliased outlines. The outer
// edge NEVER moves between idle and recording — only the annulus thickens
// inward, which keeps the transition additive and safe for partial refresh.
// ---- The idle mark -----------------------------------------------------
// Just the word. The ring is gone: a circle around the name said nothing the
// name did not, and once RECORDING drew a second ring inside the first the
// screen was three shapes carrying one idea.
//
// RECORDING keeps the word exactly where it is and ADDS a filled dot above it
// and a timer below. That is the whole difference, and it matters mechanically
// as much as visually: the transition is then purely additive ink, which is
// what lets it go out as a partial refresh and land instantly instead of after
// a two-second full repaint.
// The app's Home rhythm, in panel pixels: headline, its rule, one figure with
// a unit beneath, then the state at the foot. Same order the phone uses.
static const int16_t HEAD_BASELINE   = 52;
static const int16_t HEAD_RULE_Y     = 66;

// Air between the head rule and whatever sits under it. A heading with content
// jammed against it reads as one object, not two.
static const int16_t LIST_CLEARANCE  = 18;
static const int16_t FIGURE_BASELINE = 122;
static const int16_t UNIT_BASELINE   = 146;
static const int16_t FOOT_RULE_Y     = CONTENT_BOTTOM - 26;
static const int16_t FOOT_BASELINE   = CONTENT_BOTTOM - 6;

static const int16_t WORDMARK_CY          = 104;  // ink centre of "Jota"
static const int16_t REC_DOT_CY           = 62;   // the record dot, above it
static const int16_t REC_DOT_R            = 9;

static const int16_t CIRCLE_CY            = 94;
static const int16_t CIRCLE_R             = 46;
static const int16_t CIRCLE_STROKE        = 3;

// Recording is the SAME ring with a second one drawn inside it. Not a thicker
// annulus, and not a filled dot: two concentric circles keep the whole device
// on one motif, and — critically — adding a ring inside the first is purely
// ADDITIVE ink. The wordmark, the status line and the gauge all stay exactly
// where they were, which is what lets Ready -> Recording be a partial refresh
// and appear instantly instead of after a two-second full repaint.
// Sized so the wordmark clears it: FreeMonoBold12 puts "Jota" at ~56px, and
// the inner ring's clear width at r=34 is 62. The word does not shrink to fit
// the ring; the ring was drawn around the word.
static const int16_t CIRCLE_INNER_R       = 34;
static const int16_t DOT_R                = 4;

// ---- RECORDING is the panel inverted ------------------------------------
// Black panel, white type, same layout as READY. Selection is shown by
// inversion everywhere else in the product, and while recording the whole
// device is the selected thing. On e-paper an inverted panel also reads as
// the device switching ON, which a dot and a timer on a white screen never
// did. Mechanically it is the cleanest transition there is: every pixel
// changes, so a whole-screen partial refresh leaves no residue of READY.
// (Pala Note does the same move; the layout here is ours.)

// ---- The OFF frame's charge ring ----------------------------------------
// The resting screen wears its charge on the panel's edge: a hairline circle
// round the wordmark, with a heavier arc from 12 o'clock for the fraction
// left. The edge is the one part of the panel every other screen leaves
// empty, and a device found in a drawer answers "can I take this out" from
// across the room. Radius keeps 18 px clear of the lid crop.
static const int16_t OFF_RING_R      = 82;
static const int16_t OFF_RING_STROKE = 1;
// A solid 3 px arc on a solid 1 px track did not read as a gauge on the real
// panel: at 90% the eye saw one ring with a break in it, not a ring nine
// tenths full. The track is now DOTTED and the arc a pixel heavier, so the
// solid part is unmistakably the charge and the dotted part the space left.
static const int16_t OFF_ARC_STROKE  = 4;
static const float   OFF_TRACK_DASH_DEG = 4.0f;   // dash and gap, in degrees
static const int16_t OFF_PCT_CY      = 150;   // the figure, inside the ring

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
// The recording timer: where it is DRAWN and, from the same numbers, the
// window the partial refresh pushes.
//
// These used to be independent. The redesign moved the timer up beside the
// waiting figure and left the dirty rect describing the old centred layout, so
// every tick repainted a band of pixels the timer was no longer in — the panel
// was refreshing faithfully, once a second, just not where you could see it.
// A timer that does not visibly count is a device that looks crashed while
// recording, which is the worst possible moment to look crashed.
//
// Anything that draws the timer must use TIMER_RIGHT and TIMER_BASELINE, so
// the region below is always the region it lands in.
static const int16_t TIMER_RIGHT    = SCREEN_W - MARGIN;   // right-aligned to 186
static const int16_t TIMER_BASELINE = FIGURE_BASELINE;     // 122

// FreeMonoBold12pt7b: ~14 px per glyph, cap height ~17. "00:07" is five
// glyphs, so 96 px of box is room to spare, and x is byte-aligned because the
// SSD1681 addresses the window in whole bytes across.
// The waiting figure and its label. It changes on its own — a note is saved,
// or the phone acks one — so like the timer it needs a region of its own.
static const int16_t FIGURE_REGION_Y = FIGURE_BASELINE - 34;   //  88
static const int16_t FIGURE_REGION_H = UNIT_BASELINE - FIGURE_BASELINE + 42;

static const int16_t TIMER_X = 104, TIMER_W = 96;
static const int16_t TIMER_Y = TIMER_BASELINE - 30, TIMER_H = 40;

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
const GFXfont *wordmark();  // IBM Plex Serif 30 — the app's own headline face
const GFXfont *serif();     // IBM Plex Serif 15 — the app's own prose face
}  // namespace font

}  // namespace jota
