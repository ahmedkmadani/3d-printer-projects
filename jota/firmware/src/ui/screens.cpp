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

#include <stdio.h>

#include "ui/widgets.h"

namespace jota {

// ---- Label tables ------------------------------------------------------

// Five rows is the list's exact capacity: 5*22 + 4*5 = 130 <= CONTENT_H 156.
const char *const MENU_ITEMS[] = {"NOTES", "TAGS", "SYNC", "PAIR", "GUIDE"};
const uint8_t     MENU_COUNT   = 5;

const char *const TAG_ITEMS[] = {"WORK", "HOME", "IDEA", "BUY", "LATER"};
const uint8_t     TAG_COUNT   = 5;

// ---- Local helpers -----------------------------------------------------

static void fmtDuration(char *out, size_t n, uint16_t secs) {
  snprintf(out, n, "%02u:%02u", (unsigned)(secs / 60), (unsigned)(secs % 60));
}

static void fmtCount(char *out, size_t n, uint16_t v) {
  snprintf(out, n, "%03u", (unsigned)v);
}

// ---- Screens -----------------------------------------------------------

void screenSplash(Adafruit_GFX &g) {
  clear(g);
  // No chrome — the wordmark centres on the canvas, not the content area.
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCentered(g, "JOTA", CENTER_X, 96);

  rule(g, MARGIN, 109, CONTENT_W);

  g.setFont(font::reading());
  textCentered(g, "V0.1.0", CENTER_X, 131);
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

  char count[8];
  fmtCount(count, sizeof(count), m.noteCount);
  statusBar(g, "READY", count);

  // Idle is the ring and a dot. No figure, no word — stillness reads as
  // ready on its own, and the GUIDE card teaches the buttons once.
  ring(g, CENTER_X, CIRCLE_CY, CIRCLE_R, CIRCLE_STROKE);
  g.fillCircle(CENTER_X, CIRCLE_CY, DOT_R, INK);
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

  char count[8];
  fmtCount(count, sizeof(count), m.noteCount);
  statusBar(g, "TAGS", count);

  list(g, TAG_ITEMS, TAG_COUNT, m.tagSel);
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
  statusBar(g, "PAIR", "BLE");
  // Same big-figure pattern as SAVED — a code is a figure, so it gets the
  // display face and the same rhythm.
  bigFigure(g, font::display(), CAP_DISPLAY,
            m.pairCode ? m.pairCode : "------", "ENTER ON PHONE");
}

void screenOff(Adafruit_GFX &g) {
  // E-paper retains its last image forever. Without this the device would sit
  // in a drawer showing whatever menu it happened to be on, with a frozen
  // clock. This is the object at rest.
  clear(g);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "JOTA", CENTER_X, SCREEN_H / 2);
}

}  // namespace jota
