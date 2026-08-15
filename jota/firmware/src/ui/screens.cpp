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

// ---- Screens -----------------------------------------------------------

void screenReady(Adafruit_GFX &g, const AppModel &m) {
  clear(g);

  // Left slot is this device's own four characters — the same ones the app
  // shows beside it in a list, and the answer to "which of these is mine".
  char id[8];
  fmtShortId(id, sizeof(id), m.deviceId);

  // WAITING, not the lifetime count. The old figure only ever went up, so a
  // note that had just been handed to the phone still showed on the panel and
  // the device could never answer the one question it exists to answer: is my
  // thought safe? Pending falling to zero IS that answer.
  char count[8];
  fmtCount(count, sizeof(count), m.pending);
  statusBar(g, id, count);
  linkDot(g, id, m.paired, m.authed);

  // The mark is the whole screen. No "READY" label: there is nothing else this
  // device does while sitting still, and a word saying so is a word to read.
  ring(g, CENTER_X, CIRCLE_CY, CIRCLE_R, CIRCLE_STROKE);
  g.setTextColor(INK);
  g.setFont(font::figure());
  textCenteredAt(g, "Jota", CENTER_X, CIRCLE_CY);

  batteryGauge(g, CENTER_X, m.batteryPct, m.batteryKnown);
}

void screenRecording(Adafruit_GFX &g, const AppModel &m) {
  clear(g);

  // EVERY pixel of READY is redrawn identically — status line, wordmark, ring,
  // gauge. Only the inner ring and the timer are new. That is what makes this
  // transition safe as a partial refresh: partial updates can lay ink down
  // cleanly but leave residue where ink is removed, so the rule is that
  // RECORDING may only ADD to READY, never take away.
  char id[8];
  fmtShortId(id, sizeof(id), m.deviceId);
  char count[8];
  fmtCount(count, sizeof(count), m.pending);
  statusBar(g, id, count);
  linkDot(g, id, m.paired, m.authed);

  ring(g, CENTER_X, CIRCLE_CY, CIRCLE_R, CIRCLE_STROKE);
  ring(g, CENTER_X, CIRCLE_CY, CIRCLE_INNER_R, CIRCLE_STROKE);
  g.setTextColor(INK);
  g.setFont(font::figure());
  textCenteredAt(g, "Jota", CENTER_X, CIRCLE_CY);

  char t[12];
  fmtDuration(t, sizeof(t), m.recSecs);
  g.setFont(font::figure());
  textCentered(g, t, CENTER_X, TIMER_BASELINE);

  batteryGauge(g, CENTER_X, m.batteryPct, m.batteryKnown);
}

void screenSaved(Adafruit_GFX &g, const AppModel &m) {
  clear(g);

  char id[16];
  snprintf(id, sizeof(id), "N-%03u", (unsigned)m.note.id);
  char t[12];
  fmtDuration(t, sizeof(t), m.note.secs);
  statusBar(g, id, t);

  if (m.tags.count == 0) {
    // Nothing to offer, so this is purely a confirmation. The duration is set
    // in the same face the user was watching under the ring a second ago.
    bigFigure(g, font::display(), CAP_DISPLAY, "SAVED", t);
    return;
  }

  g.setTextColor(INK);
  g.setFont(font::label());
  textCenteredAt(g, "SAVED", CENTER_X, CONTENT_TOP + 10);

  // Tagging happens HERE, after the fact, because this is the only moment you
  // know what you just said. It is optional and it times out: see nav.cpp.
  //
  // Eight tags, five rows. Scroll the window rather than truncate, or the last
  // three would be selectable but invisible.
  uint8_t first = 0, selInWindow = 0;
  const uint8_t rows =
      tagsWindow(m.tags, m.tagSel, ROWS_MAX, &first, &selInWindow);

  // The tag already on this note is marked with a leading asterisk, so the
  // cursor (inversion) and the choice (the mark) are two different things you
  // can see at once. ASCII only: the bundled GFX fonts carry 32..126 and
  // nothing else, so a prettier bullet renders as blank space on the panel.
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

  // The right slot carries this device's own four characters — the same ones
  // the app shows beside it in a list. That is the whole answer to "which of
  // these two Jotas am I holding", and it has to be readable while pairing,
  // which is exactly when the question gets asked.
  char id[8];
  fmtShortId(id, sizeof(id), m.deviceId);
  statusBar(g, "PAIR", id);

  if (!m.pairCode) {
    // The phone answered. Same big-figure rhythm as SAVED, so a pair confirms
    // the way a saved note does.
    bigFigure(g, font::display(), CAP_DISPLAY, "PAIRED", "PHONE CONNECTED");
    return;
  }

  // A code is a figure, so it gets the display face.
  bigFigure(g, font::display(), CAP_DISPLAY, m.pairCode, "ENTER ON PHONE");
}

void screenErase(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  statusBar(g, "ERASE", "");

  g.setTextColor(INK);
  g.setFont(font::label());
  textCenteredAt(g, "ERASE ALL?", CENTER_X, CONTENT_TOP + 26);

  // Say the size of it in figures. "Erase everything" is abstract; "13 notes"
  // is the thing you are about to lose, and it is the only number that could
  // change someone's mind at this point.
  char line[32];
  snprintf(line, sizeof(line), "%u NOTES", (unsigned)m.noteCount);
  g.setFont(font::reading());
  textCenteredAt(g, line, CENTER_X, CONTENT_MID - 6);
  textCenteredAt(g, "AND YOUR PHONE", CENTER_X, CONTENT_MID + 16);

  // The way out is stated, because there is no cancel button to find and
  // doing nothing is the safe answer.
  textCenteredAt(g, "HOLD BOTH AGAIN", CENTER_X, CONTENT_BOTTOM - 30);
  textCenteredAt(g, "OR WAIT", CENTER_X, CONTENT_BOTTOM - 12);
}

void screenOff(Adafruit_GFX &g, const AppModel &m) {
  // E-paper retains its last image forever. Without this the device would sit
  // in a drawer showing whatever menu it happened to be on, with a frozen
  // clock. This is the object at rest.
  clear(g);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "JOTA", CENTER_X, SCREEN_H / 2 - 12);

  // The charge it went to sleep with. A device found in a drawer answering
  // "can I take this out with me" without being switched on is worth the ink.
  batteryGauge(g, CENTER_X, m.batteryPct, m.batteryKnown);
}

}  // namespace jota
