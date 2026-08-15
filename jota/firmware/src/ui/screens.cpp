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
const char *const MENU_ITEMS[] = {"NOTES", "TAGS", "SYNC", "PAIR", "GUIDE"};
const uint8_t     MENU_COUNT   = 5;

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

void screenSplash(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  // No chrome — the wordmark centres on the canvas, not the content area.
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCentered(g, "JOTA", CENTER_X, 96);

  rule(g, MARGIN, 109, CONTENT_W);

  // Version and identity together: this is the one screen every boot shows, so
  // it is where "which unit is this" costs nothing to answer.
  char id[8];
  fmtShortId(id, sizeof(id), m.deviceId);

  char line[24];
  snprintf(line, sizeof(line), "V0.1.0  %s", id);

  g.setFont(font::reading());
  textCentered(g, line, CENTER_X, 131);
}

void screenGuide(Adafruit_GFX &g) {
  clear(g);
  statusBar(g, "GUIDE", nullptr);

  // Monospace keeps the two columns aligned without a layout pass. This card
  // is what buys the idle screen the right to stay wordless.
  g.setTextColor(INK);
  g.setFont(font::reading());
  textLeft(g, "BOOT  RECORD", MARGIN, 94);
  textLeft(g, "PWR   MENU", MARGIN, 112);
  textLeft(g, "HOLD  BACK", MARGIN, 130);
}

void screenReady(Adafruit_GFX &g, const AppModel &m) {
  clear(g);

  // WAITING, not the lifetime count. The old figure only ever went up, so a
  // note that had just been handed to the phone still showed on the panel and
  // the device could never answer the one question it exists to answer: is my
  // thought safe? Pending falling to zero IS that answer.
  char count[8];
  fmtCount(count, sizeof(count), m.pending);
  statusBar(g, "READY", count);
  linkDot(g, "READY", m.paired, m.authed);

  // Idle is the ring and a dot. No figure, no word — stillness reads as
  // ready on its own, and the GUIDE card teaches the buttons once.
  ring(g, CENTER_X, CIRCLE_CY, CIRCLE_R, CIRCLE_STROKE);
  g.fillCircle(CENTER_X, CIRCLE_CY, DOT_R, INK);

  // An armed tag has to be visible HERE, on the screen you are looking at when
  // you press record. Armed silently on another screen, it would file notes
  // under a heading chosen minutes ago and forgotten.
  const char *armed = tagAt(m.tags, m.tagArmed);
  if (armed) {
    g.setTextColor(INK);
    g.setFont(font::label());
    textCenteredAt(g, armed, CENTER_X, CIRCLE_CY);
  }

  batteryGauge(g, CENTER_X, m.batteryPct, m.batteryKnown);
}

void screenRecording(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  statusBar(g, "REC", m.clock);

  // Same centre, same outer edge as idle — only the annulus thickens inward
  // and the timer appears. Purely additive ink, so the transition is safe as
  // a partial refresh and reads instantly as a different state.
  ring(g, CENTER_X, CIRCLE_CY, CIRCLE_R, CIRCLE_STROKE_ACTIVE);

  char t[12];
  fmtDuration(t, sizeof(t), m.recSecs);
  g.setTextColor(INK);
  g.setFont(font::figure());
  textCentered(g, t, CENTER_X, CIRCLE_CY + CAP_FIGURE / 2);

  // Same gauge, same pixels as READY — see the note in theme.h. Without it the
  // idle screen's gauge would ghost through this one.
  batteryGauge(g, CENTER_X, m.batteryPct, m.batteryKnown);
}

void screenSaved(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  statusBar(g, "SAVED", m.clock);

  char id[16];
  snprintf(id, sizeof(id), "N-%03u", (unsigned)m.note.id);

  // The duration is set in `figure()` — the same face the user was watching
  // inside the ring one second ago. Continuity across the transition.
  char t[12];
  fmtDuration(t, sizeof(t), m.note.secs);
  bigFigure(g, font::display(), CAP_DISPLAY, id, t);

  // If it was filed under a tag, say so on the confirmation — the only moment
  // the person can still tell that the tag was wrong.
  if (m.note.tag) {
    g.setTextColor(INK);
    g.setFont(font::label());
    textCenteredAt(g, m.note.tag, CENTER_X, CONTENT_BOTTOM - 14);
  }
}

void screenMenu(Adafruit_GFX &g, const AppModel &m) {
  clear(g);

  char count[8];
  fmtCount(count, sizeof(count), m.noteCount);
  statusBar(g, "MENU", count);

  list(g, MENU_ITEMS, MENU_COUNT, m.menuSel);
}

void screenChooseTag(Adafruit_GFX &g, const AppModel &m) {
  clear(g);

  // The defining figure here is the position in the list, not the note count:
  // the list can be eight long and the panel shows five, so the status slot is
  // the only thing that says where in it you are.
  char pos[16];
  snprintf(pos, sizeof(pos), "%03u/%03u",
           (unsigned)(m.tags.count ? m.tagSel + 1 : 0),
           (unsigned)m.tags.count);
  statusBar(g, "TAGS", pos);

  if (m.tags.count == 0) {
    // The phone may legitimately write an empty list. Say so — a blank content
    // area reads as a failed refresh, which is the one thing e-paper must
    // never look like.
    g.setTextColor(INK);
    // Two lines: the mono face fits about fourteen characters across the
    // content column, and textCenteredAt does not wrap — one long line runs
    // off the panel and the overflow reappears at the left margin.
    g.setFont(font::label());
    textCenteredAt(g, "NO TAGS", CENTER_X, CONTENT_MID - 16);
    g.setFont(font::reading());
    textCenteredAt(g, "ADD THEM", CENTER_X, CONTENT_MID + 10);
    textCenteredAt(g, "IN THE APP", CENTER_X, CONTENT_MID + 28);
    return;
  }

  // Eight tags, five rows. Scroll the window rather than truncate, or the last
  // three would be selectable but invisible.
  uint8_t first = 0, selInWindow = 0;
  const uint8_t rows = tagsWindow(m.tags, m.tagSel, ROWS_MAX, &first,
                                  &selInWindow);

  // The armed tag is marked with a leading asterisk, so the cursor (inversion)
  // and the choice (the mark) are two different things you can see at once.
  // ASCII only: the bundled GFX fonts carry 32..126 and nothing else, so a
  // prettier bullet glyph renders as blank space on the panel.
  char        marked[ROWS_MAX][TAG_LEN_MAX + 3];
  const char *window[ROWS_MAX];
  for (uint8_t i = 0; i < rows; ++i) {
    const uint8_t idx = (uint8_t)(first + i);
    snprintf(marked[i], sizeof(marked[i]), "%s%s",
             (idx == m.tagArmed) ? "* " : "", m.tags.items[idx]);
    window[i] = marked[i];
  }

  list(g, window, rows, selInWindow);
}

void screenSyncing(Adafruit_GFX &g, const AppModel &m) {
  clear(g);

  char ratio[16];
  snprintf(ratio, sizeof(ratio), "%03u/%03u", (unsigned)m.syncDone,
           (unsigned)m.syncTotal);
  statusBar(g, "SYNC", ratio);

  // SYNC means handing notes to the paired phone over BLE — there is no
  // upload from the device. The bar alone: the ratio already lives in the
  // status slot.
  const float frac =
      m.syncTotal ? (float)m.syncDone / (float)m.syncTotal : 0.0f;
  progressBar(g, MARGIN, CONTENT_MID - PROGRESS_H / 2, CONTENT_W, PROGRESS_H,
              frac);
}

void screenNoteView(Adafruit_GFX &g, const AppModel &m) {
  clear(g);

  char pos[16];
  snprintf(pos, sizeof(pos), "%03u/%03u", (unsigned)m.noteIndex,
           (unsigned)m.noteCount);

  char id[16];
  snprintf(id, sizeof(id), "N-%03u", (unsigned)m.note.id);
  statusBar(g, id, pos);

  // The note's own timestamp and duration belong in the body, not in the
  // status slot where they would masquerade as the live clock.
  char t[12];
  fmtDuration(t, sizeof(t), m.note.secs);
  g.setTextColor(INK);
  g.setFont(font::reading());
  textLeft(g, m.note.time ? m.note.time : "--:--", MARGIN, META_BASELINE);
  textRight(g, t, SCREEN_W - MARGIN, META_BASELINE);

  if (m.note.text) {
    // Prose is the one place sans beats mono: at 172 px the monospace face
    // fits only ~15 characters per line, which shreds a transcript.
    g.setFont(font::prose());
    textWrapped(g, m.note.text, MARGIN, PROSE_TOP, CONTENT_W, PROSE_LEADING,
                PROSE_MAX_LINES);
  } else {
    g.setFont(font::reading());
    textCenteredAt(g, "NO TRANSCRIPT", CENTER_X, CONTENT_MID + 12);
  }
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
