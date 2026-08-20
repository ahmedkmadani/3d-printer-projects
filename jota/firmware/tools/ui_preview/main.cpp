// ============================================================================
//  Jota — host UI preview
//
//  Renders every screen to a 200x200 PGM using the SAME widgets.cpp /
//  screens.cpp the firmware compiles. GFXcanvas1 and GxEPD2_BW are both
//  Adafruit_GFX, so what you review here is what the panel draws.
//
//  Build + run: ./build.sh
// ============================================================================
#include <Adafruit_GFX.h>

#include <cstdio>
#include <string>

#include "app/model.h"
#include "ui/screens.h"
#include "ui/theme.h"
#include "ui/widgets.h"

using namespace jota;

static const int kRowBytes = (SCREEN_W + 7) / 8;

// GFXcanvas1 sets a bit when the colour is non-zero. Our palette uses
// BG = 0xFFFF and INK = 0x0000, so a set bit is white and a clear bit is ink.
static void writePGM(GFXcanvas1 &c, const std::string &path) {
  const uint8_t *buf = c.getBuffer();
  FILE          *f   = fopen(path.c_str(), "wb");
  if (!f) {
    fprintf(stderr, "cannot write %s\n", path.c_str());
    return;
  }
  fprintf(f, "P5\n%d %d\n255\n", SCREEN_W, SCREEN_H);
  for (int y = 0; y < SCREEN_H; ++y) {
    for (int x = 0; x < SCREEN_W; ++x) {
      const uint8_t bit = buf[y * kRowBytes + (x >> 3)] & (0x80 >> (x & 7));
      fputc(bit ? 255 : 0, f);
    }
  }
  fclose(f);
}

// Sample sheet of every primitive in both states — what to check when tuning
// weights, radii and vertical centring.
static void sheetWidgets(Adafruit_GFX &g) {
  clear(g);
  statusBar(g, "WIDGETS", "OK");

  row(g, 40, "ROW", false);
  row(g, 67, "ROW SELECTED", true);

  progressBar(g, MARGIN, 104, CONTENT_W, PROGRESS_H, 0.60f);

  dots(g, CENTER_X, 130, 5, 2);

  ring(g, CENTER_X, 160, 18, CIRCLE_STROKE);
}

// The two ring states side by side — the transition the whole product turns
// on. Outer edges must be identical.
static void sheetRings(Adafruit_GFX &g) {
  clear(g);
  statusBar(g, "RINGS", "OK");

  // Idle beside recording. They have to be checked together, because the whole
  // partial-refresh trick depends on the right one being the left one PLUS
  // ink — the word does not move and nothing is taken away.
  // Stacked, not side by side: the wordmark is ~112px wide and two of them
  // across a 200px panel simply collide.
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, 74);

  g.fillCircle(CENTER_X, 118, REC_DOT_R, INK);
  textCenteredAt(g, "Jota", CENTER_X, 150);
}


// ---- idle variants, for choosing between --------------------------------
// The question is how little the resting screen can say. Everything here is
// drawn with the real widgets, so what is picked is what ships.

// A — the word, and nothing else at all.
static void idleA(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, SCREEN_H / 2);
}

// B — the word, and the one fact that changes: how many are waiting. Silent
// when there is nothing to say.
static void idleB(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, SCREEN_H / 2 - 10);
  if (m.pending) {
    char line[24];
    snprintf(line, sizeof(line), "%u waiting", (unsigned)m.pending);
    g.setFont(font::reading());
    textCenteredAt(g, line, CENTER_X, SCREEN_H / 2 + 34);
  }
}

// C — the word, with the chrome kept but stripped to one figure: no device id,
// no battery percentage, just the count in the slot that exists for it.
static void idleC(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  char count[8];
  snprintf(count, sizeof(count), "%03u", (unsigned)m.pending);
  statusBar(g, "", count);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, CONTENT_MID);
}

// The recording state for B: the word stays put, a dot and the timer arrive.
static void recB(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, SCREEN_H / 2 - 10);
  g.fillCircle(CENTER_X, 52, REC_DOT_R, INK);
  char t[12];
  snprintf(t, sizeof(t), "%02u:%02u", (unsigned)(m.recSecs / 60),
           (unsigned)(m.recSecs % 60));
  g.setFont(font::figure());
  textCentered(g, t, CENTER_X, SCREEN_H / 2 + 44);
}

int main(int argc, char **argv) {
  const std::string out = (argc > 1) ? argv[1] : ".";

  AppModel m{};
  m.noteCount = 12;
  m.clock     = "14:32";
  m.recSecs   = 7;
  m.tagSel    = 1;   // legal for a 3-tag list
  // Tags come from the phone now, so the preview seeds them the same way the
  // device does before it has ever been written to.
  tagsSetDefaults(m.tags);
  m.deviceId     = "7f3a91c4";
  m.batteryKnown = true;
  m.batteryPct   = 62;
  m.authed   = true;  // a phone is connected: the link dot is filled
  m.pairCode  = "428 913";
  m.paired    = true;
  m.pending   = 3;
  // Long enough to exercise wrapping and the max-lines clamp.
  m.note = {12, "14:32",
            "call the dentist about moving the appointment to next week and "
            "ask whether the referral is still valid",
            7, "PERSONAL"};

  struct Item {
    const char *name;
    void (*draw)(Adafruit_GFX &, const AppModel &);
  };

  GFXcanvas1 canvas(SCREEN_W, SCREEN_H);

  // Screens that ignore the model.
  sheetWidgets(canvas);
  writePGM(canvas, out + "/00_widgets.pgm");
  sheetRings(canvas);
  writePGM(canvas, out + "/00b_rings.pgm");
  idleA(canvas, m);
  writePGM(canvas, out + "/A_idle_word_only.pgm");
  idleB(canvas, m);
  writePGM(canvas, out + "/B_idle_with_count.pgm");
  recB(canvas, m);
  writePGM(canvas, out + "/B_recording.pgm");
  idleC(canvas, m);
  writePGM(canvas, out + "/C_idle_status_slot.pgm");

  screenOff(canvas, m);
  writePGM(canvas, out + "/09_off.pgm");

  // The whole product, in five frames.
  const Item items[] = {
      {"01_ready", screenReady},
      {"02_recording", screenRecording},
      {"03_saved", screenSaved},
      {"04_pair", screenPair},
      {"05_erase", screenErase},
  };

  for (const Item &it : items) {
    it.draw(canvas, m);
    writePGM(canvas, out + "/" + it.name + ".pgm");
  }

  // A saved note with no tags at all: the phone may legitimately have written
  // an empty list, and that path draws a completely different SAVED.
  AppModel bare = m;
  bare.tags.count = 0;
  screenSaved(canvas, bare);
  writePGM(canvas, out + "/03b_saved_no_tags.pgm");

  printf("rendered %zu screens to %s\n", sizeof(items) / sizeof(items[0]) + 4,
         out.c_str());
  return 0;
}
