// ============================================================================
//  Jota — widget primitives (implementation)
// ============================================================================
#include "ui/widgets.h"

#include <math.h>

#include <string.h>

#include <Fonts/FreeMono9pt7b.h>
#include <Fonts/FreeMonoBold12pt7b.h>
#include <Fonts/FreeMonoBold18pt7b.h>
#include <Fonts/FreeMonoBold24pt7b.h>
#include <Fonts/FreeMonoBold9pt7b.h>
#include <Fonts/FreeSans9pt7b.h>

#include "ui/font_serif15.h"
#include "ui/font_serif30.h"

namespace jota {

namespace font {
const GFXfont *label() { return &FreeMonoBold9pt7b; }
const GFXfont *reading() { return &FreeMono9pt7b; }
const GFXfont *figure() { return &FreeMonoBold12pt7b; }
const GFXfont *display() { return &FreeMonoBold18pt7b; }
const GFXfont *prose() { return &FreeSans9pt7b; }
// The APP's headline face, on the panel. The two objects said the product's
// name in two different voices — Plex Serif on the phone, a typewriter slab
// here — and no arrangement of dots and hairlines was ever going to make those
// feel like one product. Generated from the same TTF the app bundles; see
// tools/fontgen/ttf_to_gfx.py.
const GFXfont *wordmark() { return &JotaSerif30; }
const GFXfont *serif() { return &JotaSerif15; }
}  // namespace font

// ---- Text --------------------------------------------------------------

int16_t textWidth(Adafruit_GFX &g, const char *s) {
  int16_t  x1, y1;
  uint16_t w, h;
  g.getTextBounds(s, 0, 0, &x1, &y1, &w, &h);
  return (int16_t)w;
}

void textLeft(Adafruit_GFX &g, const char *s, int16_t left, int16_t baseline) {
  int16_t  x1, y1;
  uint16_t w, h;
  // With the cursor at x=0 the ink starts at x1, so shift by -x1 to put the
  // INK edge on `left`. Without this the ink wobbles 1px with the glyph.
  g.getTextBounds(s, 0, baseline, &x1, &y1, &w, &h);
  g.setCursor(left - x1, baseline);
  g.print(s);
}

void textRight(Adafruit_GFX &g, const char *s, int16_t right, int16_t baseline) {
  int16_t  x1, y1;
  uint16_t w, h;
  g.getTextBounds(s, 0, baseline, &x1, &y1, &w, &h);
  g.setCursor(right - (int16_t)w - x1, baseline);
  g.print(s);
}

void textCentered(Adafruit_GFX &g, const char *s, int16_t cx, int16_t baseline) {
  int16_t  x1, y1;
  uint16_t w, h;
  g.getTextBounds(s, 0, baseline, &x1, &y1, &w, &h);
  g.setCursor(cx - (int16_t)w / 2 - x1, baseline);
  g.print(s);
}

void textCenteredAt(Adafruit_GFX &g, const char *s, int16_t cx, int16_t cy) {
  int16_t  x1, y1;
  uint16_t w, h;
  g.getTextBounds(s, 0, 0, &x1, &y1, &w, &h);
  // Relative to a baseline of 0 the ink spans [y1, y1+h).
  g.setCursor(cx - (int16_t)w / 2 - x1, cy - (int16_t)h / 2 - y1);
  g.print(s);
}

void textCenteredIn(Adafruit_GFX &g, const char *s, int16_t x, int16_t y,
                    int16_t w, int16_t h) {
  int16_t  x1, y1;
  uint16_t tw, th;
  g.getTextBounds(s, 0, 0, &x1, &y1, &tw, &th);
  g.setCursor(x + (w - (int16_t)tw) / 2 - x1, y + (h - (int16_t)th) / 2 - y1);
  g.print(s);
}

int16_t textWrapped(Adafruit_GFX &g, const char *s, int16_t x, int16_t baseline,
                    int16_t w, int16_t lineHeight, uint8_t maxLines) {
  char    line[96] = {0};
  size_t  lineLen  = 0;
  uint8_t drawn    = 0;
  int16_t y        = baseline;
  int16_t lastY    = baseline;

  const char *p = s;
  while (*p && drawn < maxLines) {
    while (*p == ' ') p++;
    if (!*p) break;

    const char *ws = p;
    while (*p && *p != ' ') p++;
    size_t wl = (size_t)(p - ws);
    if (wl >= sizeof(line)) wl = sizeof(line) - 1;

    char   cand[96];
    size_t cl = 0;
    if (lineLen) {
      memcpy(cand, line, lineLen);
      cl         = lineLen;
      cand[cl++] = ' ';
    }
    memcpy(cand + cl, ws, wl);
    cl += wl;
    cand[cl] = '\0';

    if (textWidth(g, cand) <= w || lineLen == 0) {
      memcpy(line, cand, cl + 1);
      lineLen = cl;
    } else {
      textLeft(g, line, x, y);
      lastY = y;
      drawn++;
      y += lineHeight;
      if (drawn >= maxLines) return lastY;
      memcpy(line, ws, wl);
      line[wl] = '\0';
      lineLen  = wl;
    }
  }

  if (lineLen && drawn < maxLines) {
    textLeft(g, line, x, y);
    lastY = y;
  }
  return lastY;
}

// ---- Chrome ------------------------------------------------------------

void clear(Adafruit_GFX &g) { g.fillScreen(BG); }

void rule(Adafruit_GFX &g, int16_t x, int16_t y, int16_t w) {
  g.drawFastHLine(x, y, w, INK);
}

void statusBar(Adafruit_GFX &g, const char *left, const char *right) {
  g.setTextColor(INK);
  if (left) {
    // The left slot is the screen's identity — bold. The right slot is a
    // reading, so it stays regular weight.
    g.setFont(font::label());
    textLeft(g, left, MARGIN, STATUS_BASELINE);
  }
  if (right) {
    g.setFont(font::reading());
    textRight(g, right, SCREEN_W - MARGIN, STATUS_BASELINE);
  }
  rule(g, MARGIN, STATUS_RULE_Y, CONTENT_W);
}

void linkDot(Adafruit_GFX &g, const char *afterLabel, bool paired,
             bool authed) {
  // Nothing at all until a phone has been paired: an empty circle on a device
  // that has never met a phone would read as a fault rather than as "away".
  if (!paired) return;

  g.setFont(font::label());
  const int16_t x  = (int16_t)(MARGIN + textWidth(g, afterLabel) + GAP_S + 3);
  const int16_t cy = (int16_t)(STATUS_BASELINE - CAP_LABEL / 2);

  if (authed) {
    g.fillCircle(x, cy, 3, INK);
  } else {
    g.drawCircle(x, cy, 3, INK);
  }
}

void bigFigure(Adafruit_GFX &g, const GFXfont *bigFont, int16_t bigCap,
               const char *big, const char *caption) {
  // Block = big cap + GAP_M + rule + GAP_M + caption cap, centred on
  // CONTENT_MID. Computed, so splash and saved cannot drift apart.
  const int16_t blockH = bigCap + GAP_M + 1 + GAP_M + CAP_LABEL;
  const int16_t top    = CONTENT_MID - blockH / 2;

  g.setTextColor(INK);
  g.setFont(bigFont);
  textCentered(g, big, CENTER_X, top + bigCap);

  const int16_t ruleY = top + bigCap + GAP_M;
  rule(g, MARGIN, ruleY, CONTENT_W);

  g.setFont(font::reading());
  textCentered(g, caption, CENTER_X, ruleY + GAP_M + CAP_LABEL);
}

// ---- Controls ----------------------------------------------------------

void row(Adafruit_GFX &g, int16_t y, const char *label, bool selected) {
  const int16_t r = ROW_H / 2;  // always a stadium
  if (selected) {
    g.fillRoundRect(MARGIN, y, CONTENT_W, ROW_H, r, INK);
    g.setTextColor(BG);
  } else {
    g.drawRoundRect(MARGIN, y, CONTENT_W, ROW_H, r, INK);
    g.setTextColor(INK);
  }
  g.setFont(font::label());
  textCenteredIn(g, label, MARGIN, y, CONTENT_W, ROW_H);
  g.setTextColor(INK);  // leave the context clean for the next widget
}

void list(Adafruit_GFX &g, const char *const *items, uint8_t n, uint8_t sel) {
  if (n > ROWS_MAX) n = ROWS_MAX;
  const int16_t blockH = (int16_t)n * ROW_H + (int16_t)(n - 1) * ROW_GAP;
  // Centred in the space BELOW the head rule, not on the whole screen. Centring
  // on the screen put the first pill four pixels under the rule — the list read
  // as though it were hanging off the heading rather than sitting in its own
  // space.
  const int16_t top    = HEAD_RULE_Y + LIST_CLEARANCE;
  const int16_t y0     = top + (CONTENT_BOTTOM - top - blockH) / 2;
  for (uint8_t i = 0; i < n; ++i) {
    row(g, y0 + i * (ROW_H + ROW_GAP), items[i], i == sel);
  }
}

// ---- Indicators --------------------------------------------------------

void ring(Adafruit_GFX &g, int16_t cx, int16_t cy, int16_t r, int16_t stroke) {
  // Filled disc knocked back out. Stacking drawCircle() calls leaves
  // aliasing gaps at the diagonals at these weights.
  g.fillCircle(cx, cy, r, INK);
  g.fillCircle(cx, cy, r - stroke, BG);
}

void progressBar(Adafruit_GFX &g, int16_t x, int16_t y, int16_t w, int16_t h,
                 float frac) {
  if (frac < 0.0f) frac = 0.0f;
  if (frac > 1.0f) frac = 1.0f;

  g.drawRoundRect(x, y, w, h, h / 2, INK);

  const int16_t ih = h - 4;
  int16_t       iw = (int16_t)((float)(w - 4) * frac);
  // A rounded rect narrower than its own diameter degenerates; clamp so the
  // first sliver renders as a dot instead of artefacts.
  if (iw > 0) {
    if (iw < ih) iw = ih;
    g.fillRoundRect(x + 2, y + 2, iw, ih, ih / 2, INK);
  }
}

void batteryGauge(Adafruit_GFX &g, int16_t cx, uint8_t pct, bool known) {
  // Nothing at all rather than an empty stadium: an unmeasured battery and a
  // flat one must never look the same.
  if (!known) return;
  if (pct > 100) pct = 100;

  // Zero-padded, like every other figure in the product, so it does not change
  // width as the charge falls and shuffle the layout under a partial refresh.
  char label[8];
  snprintf(label, sizeof(label), "%03u%%", (unsigned)pct);

  g.setTextColor(INK);
  g.setFont(font::reading());

  // Centre the PAIR, not each half, or the gauge would sit off-axis.
  const int16_t tw    = textWidth(g, label);
  const int16_t total = (int16_t)(GAUGE_W + GAUGE_GAP + tw);
  const int16_t x0    = (int16_t)(cx - total / 2);

  progressBar(g, x0, GAUGE_Y, GAUGE_W, GAUGE_H, (float)pct / 100.0f);
  textLeft(g, label, (int16_t)(x0 + GAUGE_W + GAUGE_GAP), GAUGE_BASELINE);
}

void chargeRing(Adafruit_GFX &g, int16_t cx, int16_t cy, int16_t r,
                uint8_t pct, bool known) {
  if (pct > 100) pct = 100;
  // One scan over the ring's bounding box draws both the dotted track and the
  // solid arc, pixel by pixel: stroked circles bead at this radius and gap at
  // the diagonals. Angle is measured from 12 o'clock, clockwise.
  //
  // The arc ENDS at 12 o'clock rather than starting there. A full cell is the
  // whole ring; as it drains, the dotted gap opens at the top and grows
  // clockwise, the way a clock hand moves. The arc used to start at 12 and
  // end at the charge, which made the gap grow anticlockwise as the days
  // went by — read as "the power is going backwards" by the one person who
  // watched it drain.
  const float startDeg = known ? 360.0f - 360.0f * (float)pct / 100.0f : 361.0f;
  const float tIn    = (float)r - (float)OFF_RING_STROKE / 2.0f;
  const float tOut   = (float)r + (float)OFF_RING_STROKE / 2.0f;
  const float aIn    = (float)r - (float)OFF_ARC_STROKE / 2.0f;
  const float aOut   = (float)r + (float)OFF_ARC_STROKE / 2.0f;
  const int16_t span = r + OFF_ARC_STROKE;
  for (int16_t dy = -span; dy <= span; ++dy) {
    for (int16_t dx = -span; dx <= span; ++dx) {
      const float d = sqrtf((float)(dx * dx + dy * dy));
      if (d < aIn || d > aOut) continue;
      float deg = atan2f((float)dx, (float)-dy) * 180.0f / 3.14159265f;
      if (deg < 0.0f) deg += 360.0f;
      const bool onArc = known && deg >= startDeg;
      if (onArc) {
        g.drawPixel((int16_t)(cx + dx), (int16_t)(cy + dy), INK);
      } else if (d >= tIn && d <= tOut) {
        // Track: dashes of OFF_TRACK_DASH_DEG with equal gaps. Unknown charge
        // draws the whole ring dotted — an unmeasured battery and a flat one
        // must never look the same.
        if (fmodf(deg, 2.0f * OFF_TRACK_DASH_DEG) < OFF_TRACK_DASH_DEG) {
          g.drawPixel((int16_t)(cx + dx), (int16_t)(cy + dy), INK);
        }
      }
    }
  }
}

void dots(Adafruit_GFX &g, int16_t cx, int16_t cy, uint8_t n, uint8_t active) {
  const int16_t r = 3, gap = 14;
  const int16_t x0 = cx - ((int16_t)(n - 1) * gap) / 2;
  for (uint8_t i = 0; i < n; ++i) {
    const int16_t x = x0 + i * gap;
    if (i < active) {
      g.fillCircle(x, cy, r, INK);
    } else {
      g.drawCircle(x, cy, r, INK);
    }
  }
}

}  // namespace jota
