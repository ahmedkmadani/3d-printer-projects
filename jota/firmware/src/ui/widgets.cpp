// ============================================================================
//  Jota — widget primitives (implementation)
// ============================================================================
#include "ui/widgets.h"

#include <string.h>

#include <Fonts/FreeMono9pt7b.h>
#include <Fonts/FreeMonoBold12pt7b.h>
#include <Fonts/FreeMonoBold18pt7b.h>
#include <Fonts/FreeMonoBold24pt7b.h>
#include <Fonts/FreeMonoBold9pt7b.h>
#include <Fonts/FreeSans9pt7b.h>

namespace jota {

namespace font {
const GFXfont *label() { return &FreeMonoBold9pt7b; }
const GFXfont *reading() { return &FreeMono9pt7b; }
const GFXfont *figure() { return &FreeMonoBold12pt7b; }
const GFXfont *display() { return &FreeMonoBold18pt7b; }
const GFXfont *prose() { return &FreeSans9pt7b; }
const GFXfont *wordmark() { return &FreeMonoBold24pt7b; }
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
  const int16_t y0     = CONTENT_MID - blockH / 2;
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
