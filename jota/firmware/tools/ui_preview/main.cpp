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

#include <cctype>
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




// ---- regression checks -------------------------------------------------
// Rendering a screen only proves it LOOKS right in a contact sheet. The two
// rules below are invisible there and both have already been broken once:
//
//   1. A live region must contain every pixel that changes inside it. The
//      redesign moved the recording timer and left the dirty rect describing
//      the old layout, so the panel refreshed once a second in a band the
//      timer was not in. It looked, on real hardware, exactly like a crash.
//
//   2. Nothing may sit under the lid crop (4 px), except on RECORDING, which
//      is the panel inverted: ink to the edge on purpose, and nothing under
//      the lid there carries information.
//
// (A third rule, "RECORDING differs from READY only inside FIGURE_REGION",
// went when RECORDING became inverted: both of its transitions now change
// every pixel, which is exactly what makes them safe as partial refreshes.)
//
// Each is one image diff, which is why they are checked here rather than
// trusted to a reviewer's eye.

static bool inkAt(const GFXcanvas1 &c, int x, int y) {
  const uint8_t *b = c.getBuffer();
  // A SET bit is white (BG = 0xFFFF), so ink is the CLEAR bit.
  return (b[y * kRowBytes + (x >> 3)] & (0x80 >> (x & 7))) == 0;
}

// nav.h owns the real Rect, and nav.cpp is not part of this build (it pulls in
// buttons and storage). The region under test is the same four tokens either
// way, which is the point: both sides read theme.h.
struct Box { int x, y, w, h; };

static int failures = 0;

// Every pixel that differs between two renders must fall inside `r`.
static void diffWithin(void (*draw)(Adafruit_GFX &, const AppModel &),
                       AppModel a, AppModel b, Box r, const char *what) {
  GFXcanvas1 ca(SCREEN_W, SCREEN_H), cb(SCREEN_W, SCREEN_H);
  draw(ca, a);
  draw(cb, b);

  int outside = 0, inside = 0, fx = -1, fy = -1;
  for (int y = 0; y < SCREEN_H; ++y) {
    for (int x = 0; x < SCREEN_W; ++x) {
      if (inkAt(ca, x, y) == inkAt(cb, x, y)) continue;
      const bool in = (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h);
      if (in) {
        inside++;
      } else {
        if (fx < 0) { fx = x; fy = y; }
        outside++;
      }
    }
  }
  if (outside) {
    printf("  FAIL  %s\n        %d pixel(s) change OUTSIDE the region, "
           "first at (%d,%d); region is x %d..%d y %d..%d\n",
           what, outside, fx, fy, r.x, r.x + r.w, r.y, r.y + r.h);
    failures++;
    return;
  }
  // A region that never changes is the same bug wearing a different hat: the
  // refresh fires and nothing moves.
  if (inside == 0) {
    printf("  FAIL  %s\n        nothing changed at all - the region is dead\n",
           what);
    failures++;
    return;
  }
  printf("  pass  %s (%d px, all inside)\n", what, inside);
}

static int runChecks(AppModel m) {
  printf("checks\n");

  // 1. The recording timer ticks inside its own region.
  AppModel t7 = m, t8 = m;
  t7.recSecs = 7;
  t8.recSecs = 8;
  diffWithin(screenRecording, t7, t8,
             Box{0, FIGURE_REGION_Y, SCREEN_W, FIGURE_REGION_H},
             "recording timer ticks inside FIGURE_REGION");

  // A minute rollover moves more digits than a second does.
  AppModel t59 = m, t60 = m;
  t59.recSecs = 59;
  t60.recSecs = 60;
  diffWithin(screenRecording, t59, t60,
             Box{0, FIGURE_REGION_Y, SCREEN_W, FIGURE_REGION_H},
             "timer minute rollover stays inside FIGURE_REGION");

  // 2. Nothing may be drawn under the lid: the window crops the active area,
  //    so ink within 4 px of an edge is cropped in the hand even though the
  //    contact sheet shows it.
  {
    const int  kBleed = 4;
    // RECORDING is the panel inverted, so "ink" there is the background and
    // the rule flips: nothing KNOCKED OUT may sit under the lid. Its edge is
    // solid ink by design, and solid ink under a lid loses nothing.
    void (*screens[])(Adafruit_GFX &, const AppModel &) = {
        screenReady, screenRecording, screenSaved, screenPair, screenErase};
    const char *names[]    = {"ready", "recording", "saved", "pair", "erase"};
    const bool  inverted[] = {false, true, false, false, false};
    for (int i = 0; i < 5; ++i) {
      GFXcanvas1 c(SCREEN_W, SCREEN_H);
      AppModel   r = m;
      r.recSecs = 7;
      screens[i](c, r);
      int bad = 0, fx = -1, fy = -1;
      for (int y = 0; y < SCREEN_H; ++y) {
        for (int x = 0; x < SCREEN_W; ++x) {
          const bool edge = x < kBleed || y < kBleed ||
                            x >= SCREEN_W - kBleed || y >= SCREEN_H - kBleed;
          if (edge && (inkAt(c, x, y) != inverted[i])) {
            if (fx < 0) { fx = x; fy = y; }
            bad++;
          }
        }
      }
      char what[64];
      snprintf(what, sizeof(what), "%s keeps %dpx clear of every edge",
               names[i], kBleed);
      if (bad) {
        printf("  FAIL  %s\n        %d px in the bleed, first at (%d,%d)\n",
               what, bad, fx, fy);
        failures++;
      } else {
        printf("  pass  %s\n", what);
      }
    }
  }

  printf("\n%s\n", failures ? "CHECKS FAILED" : "all checks passed");
  return failures ? 1 : 0;
}

int main(int argc, char **argv) {
  const std::string arg1 = (argc > 1) ? argv[1] : ".";
  const bool        checkOnly = (arg1 == "--check");
  const std::string out = checkOnly ? "." : arg1;

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

  if (checkOnly) return runChecks(m);

  GFXcanvas1 canvas(SCREEN_W, SCREEN_H);

  // Screens that ignore the model.
  sheetWidgets(canvas);
  writePGM(canvas, out + "/00_widgets.pgm");
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
