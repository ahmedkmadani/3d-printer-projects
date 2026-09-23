// ============================================================================
//  Jota — screens (implementation)
//
//  Chrome is one status line and a hairline. Figures are zero-padded and
//  monospaced so they read as instrument output rather than app copy.
//
//  STATUS RIGHT SLOT RULE: it always holds the screen's one defining figure.
//  The live clock appears only where a time is the datum (recording, saving);
//  elsewhere it is a count, a ratio, or a position.
// ============================================================================
#include "ui/screens.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>

#include "ui/widgets.h"

namespace jota {

// ---- Label tables ------------------------------------------------------

// Five rows is the list's exact capacity: 5*22 + 4*5 = 130 <= CONTENT_H 156.

// ---- Local helpers -----------------------------------------------------

static void fmtDuration(char *out, size_t n, uint16_t secs) {
  snprintf(out, n, "%02u:%02u", (unsigned)(secs / 60), (unsigned)(secs % 60));
}

static void fmtCount(char *out, size_t n, uint16_t v) {
  snprintf(out, n, "%03u", (unsigned)v);
}

// The last four characters of the device id, uppercased — "91C4". The app
// prints the same four as JOTA-91C4, so the two can be matched by eye.
static void fmtShortId(char *out, size_t n, const char *deviceId) {
  if (!deviceId || !*deviceId) {
    snprintf(out, n, "----");
    return;
  }
  const size_t len = strlen(deviceId);
  const char  *tail = (len > 4) ? deviceId + len - 4 : deviceId;
  size_t       w    = 0;
  for (const char *p = tail; *p && w + 1 < n; ++p) {
    out[w++] = (char)toupper((unsigned char)*p);
  }
  out[w] = '\0';
}

// Every screen opens the same way: a serif word on the left, a hairline under
// it. It is the app's Home header, on the panel — which is the whole reason
// the two objects read as one product.
static void head(Adafruit_GFX &g, const char *word) {
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textLeft(g, word, MARGIN, HEAD_BASELINE);
  rule(g, MARGIN, HEAD_RULE_Y, CONTENT_W);
}

// The foot line: the same two facts the app's device chip carries, in the same
// order. A dot rather than a word for the link — filled while a phone is
// connected, hollow when one is bonded but away, absent when none ever paired.
// `ink` is INK on every screen but RECORDING, which is the panel inverted.
static void footState(Adafruit_GFX &g, const AppModel &m, uint16_t ink = INK) {
  g.drawFastHLine(MARGIN, FOOT_RULE_Y, CONTENT_W, ink);
  if (m.paired || m.authed) {
    if (m.authed) {
      g.fillCircle(MARGIN + 4, FOOT_BASELINE - 4, 3, ink);
    } else {
      g.drawCircle(MARGIN + 4, FOOT_BASELINE - 4, 3, ink);
    }
  }
  g.setTextColor(ink);
  g.setFont(font::reading());
  // PAIRED, not AWAY.
  //
  // BLE does not hold the link open — the phone connects, takes what is
  // waiting, and drops it again, because keeping a connection alive would
  // drain both batteries to say nothing. So "no phone connected right now" is
  // the state this device is in more than 99% of the time, and calling that
  // AWAY made the normal case read as a fault: it sounds like the phone has
  // wandered off, when what is true is "we are paired and there is nothing to
  // do". A status line that spends its whole life in the alarming state is not
  // reporting, it is nagging.
  //
  // The filled dot still marks the moment a phone is actually talking to us,
  // which is the only part worth distinguishing.
  textLeft(g, m.authed ? "SYNCING" : (m.paired ? "PAIRED" : "NOT PAIRED"),
           MARGIN + 14, FOOT_BASELINE);
  if (m.batteryKnown) {
    char b[8];
    snprintf(b, sizeof(b), "%u%%", (unsigned)m.batteryPct);
    textRight(g, b, SCREEN_W - MARGIN, FOOT_BASELINE);
  }
}

// ---- Screens -----------------------------------------------------------

void screenReady(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  g.setTextColor(INK);

  // The app's own layout, and now its own typeface: a serif headline, a
  // hairline under it, one figure with a mono caps label, and the state on a
  // quiet line at the foot. Same bones as the phone's Home screen — which is
  // what makes the two objects read as one product rather than two.
  g.setFont(font::wordmark());
  textLeft(g, "Jota", MARGIN, HEAD_BASELINE);
  rule(g, MARGIN, HEAD_RULE_Y, CONTENT_W);

  // WAITING, not the lifetime count. The old figure only ever went up, so a
  // note already handed to the phone still showed on the panel and the device
  // could never answer the one question it exists to answer: is my thought
  // safe? Pending falling to zero IS that answer.
  char c[8];
  snprintf(c, sizeof(c), "%u", (unsigned)m.pending);
  g.setFont(font::display());
  textLeft(g, c, MARGIN, FIGURE_BASELINE);
  g.setFont(font::label());
  textLeft(g, m.pending ? "WAITING" : "ALL SYNCED", MARGIN, UNIT_BASELINE);

  footState(g, m);
}

void screenRecording(Adafruit_GFX &g, const AppModel &m) {
  // The panel INVERTED: ink everywhere, the layout knocked out of it. Same
  // head, same figure slot, same foot as READY — the object does not change
  // identity because it is listening — but it is black while it does, which
  // on e-paper reads as the device switching on. See theme.h.
  //
  // Every pixel changes on the way in and again on the way out, so neither
  // transition can leave READY or SAVED showing through a partial refresh —
  // the residue problem that used to force a 1.3 s full repaint here.
  g.fillRect(0, 0, SCREEN_W, SCREEN_H, INK);
  g.setTextColor(BG);

  g.setFont(font::wordmark());
  textLeft(g, "Jota", MARGIN, HEAD_BASELINE);
  g.drawFastHLine(MARGIN, HEAD_RULE_Y, CONTENT_W, BG);

  // The timer replaces the waiting count. Everything that ticks lives inside
  // FIGURE_REGION, and nav pushes exactly that window — the --check test
  // enforces it.
  char t[12];
  fmtDuration(t, sizeof(t), m.recSecs);
  g.setFont(font::display());
  textLeft(g, t, MARGIN, FIGURE_BASELINE);
  g.setFont(font::label());
  textLeft(g, "RECORDING", MARGIN, UNIT_BASELINE);

  footState(g, m, BG);
  g.setTextColor(INK);  // leave the context clean for the next screen
}

void screenSaved(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textLeft(g, "Saved", MARGIN, HEAD_BASELINE);
  rule(g, MARGIN, HEAD_RULE_Y, CONTENT_W);

  char t[12];
  fmtDuration(t, sizeof(t), m.note.secs);

  if (m.tags.count == 0) {
    // Nothing to offer, so this is purely a confirmation: the length, in the
    // same face the user was watching a second ago.
    g.setFont(font::display());
    textLeft(g, t, MARGIN, FIGURE_BASELINE);
    g.setFont(font::label());
    textLeft(g, "KEPT", MARGIN, UNIT_BASELINE);
    return;
  }

  // Tagging happens HERE, after the fact, because this is the only moment you
  // know what you just said. Optional, and it times out — see nav.cpp.
  g.setFont(font::reading());
  textRight(g, t, SCREEN_W - MARGIN, HEAD_BASELINE);

  uint8_t first = 0, selInWindow = 0;
  const uint8_t rows =
      tagsWindow(m.tags, m.tagSel, ROWS_MAX, &first, &selInWindow);

  // The tag already on this note carries a leading asterisk, so the cursor
  // (inversion) and the choice (the mark) are two different things you can see
  // at once. ASCII only: the bundled fonts carry 32..126 and nothing else.
  char        marked[ROWS_MAX][TAG_LEN_MAX + 3];
  const char *window[ROWS_MAX];
  for (uint8_t i = 0; i < rows; ++i) {
    const uint8_t idx = (uint8_t)(first + i);
    const char   *nm  = m.tags.items[idx];
    snprintf(marked[i], sizeof(marked[i]), "%s%s",
             (m.note.tag && nm == m.note.tag) ? "* " : "", nm);
    window[i] = marked[i];
  }
  list(g, window, rows, selInWindow);
}

void screenPair(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  head(g, "Pair");

  // The right slot carries this device's own four characters — the same ones
  // the app shows beside it in a list. That is the whole answer to "which of
  // these two Jotas am I holding", and it has to be readable while pairing,
  // which is exactly when the question gets asked.
  char id[8];
  fmtShortId(id, sizeof(id), m.deviceId);
  g.setFont(font::reading());
  textRight(g, id, SCREEN_W - MARGIN, HEAD_BASELINE);

  if (!m.pairCode) {
    // The phone answered. Same rhythm as every other screen, so a pair
    // confirms the way a saved note does.
    g.setFont(font::display());
    textLeft(g, "OK", MARGIN, FIGURE_BASELINE);
    g.setFont(font::label());
    textLeft(g, "PHONE CONNECTED", MARGIN, UNIT_BASELINE);
    return;
  }

  // The code is the screen. Centred and in the display face because it is
  // being read off a panel at arm's length and typed into a phone — the one
  // moment on this device where legibility beats layout.
  g.setFont(font::display());
  textCenteredAt(g, m.pairCode, CENTER_X, FIGURE_BASELINE + 8);
  rule(g, MARGIN, FOOT_RULE_Y, CONTENT_W);
  g.setFont(font::label());
  textLeft(g, "ENTER ON PHONE", MARGIN, FOOT_BASELINE);
}

void screenErase(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  head(g, "Erase");

  // Say the size of it in figures. "Erase everything" is abstract; "12 notes"
  // is the thing you are about to lose, and it is the only number that could
  // change someone's mind at this point.
  char c[8];
  snprintf(c, sizeof(c), "%u", (unsigned)m.noteCount);
  g.setTextColor(INK);
  g.setFont(font::display());
  textLeft(g, c, MARGIN, FIGURE_BASELINE);
  g.setFont(font::label());
  textLeft(g, "NOTES AND PHONE", MARGIN, UNIT_BASELINE);

  // The way out is stated, because there is no cancel button to find and
  // doing nothing is the safe answer.
  rule(g, MARGIN, FOOT_RULE_Y, CONTENT_W);
  g.setFont(font::reading());
  textLeft(g, "HOLD BOTH AGAIN", MARGIN, FOOT_BASELINE);
}

void screenOff(Adafruit_GFX &g, const AppModel &m) {
  // E-paper retains its last image forever. Without this the device would sit
  // in a drawer showing whatever menu it happened to be on, with a frozen
  // clock. This is the object at rest — the wordmark alone, centred, the one
  // screen that is allowed to be nothing but the name.
  clear(g);
  g.setTextColor(INK);

  // The charge it went to sleep with, worn on the panel's edge: a hairline
  // ring round the name with the fraction left as a heavier arc. A device
  // found in a drawer answers "can I take this out with me" from across the
  // room, without being switched on. The figure sits inside the ring because
  // figures are how this product says everything else. See theme.h.
  chargeRing(g, CENTER_X, SCREEN_H / 2, OFF_RING_R, m.batteryPct, m.batteryKnown);

  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, SCREEN_H / 2 + 6);

  if (m.batteryKnown) {
    char b[8];
    snprintf(b, sizeof(b), "%u%%", (unsigned)m.batteryPct);
    g.setFont(font::label());
    textCenteredAt(g, b, CENTER_X, OFF_PCT_CY);
  }
}

}  // namespace jota
