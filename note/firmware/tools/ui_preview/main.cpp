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

  ring(g, 58, CONTENT_MID, 34, CIRCLE_STROKE);
  g.fillCircle(58, CONTENT_MID, DOT_R, INK);

  ring(g, 142, CONTENT_MID, 34, CIRCLE_STROKE_ACTIVE);
  g.setTextColor(INK);
  g.setFont(font::figure());
  textCentered(g, "0:07", 140, CONTENT_MID + CAP_FIGURE / 2);
}

int main(int argc, char **argv) {
  const std::string out = (argc > 1) ? argv[1] : ".";

  AppModel m{};
  m.noteCount = 12;
  m.noteIndex = 4;
  m.clock     = "14:32";
  m.recSecs   = 7;
  m.syncDone  = 4;
  m.syncTotal = 5;
  m.menuSel   = 1;
  m.tagSel    = 3;
  m.pairCode  = "428 913";
  m.ssid      = "home-5g";
  m.wifiUp    = true;
  // Long enough to exercise wrapping and the max-lines clamp.
  m.note = {12, "14:32",
            "call the dentist about moving the appointment to next week and "
            "ask whether the referral is still valid",
            7};

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
  screenSplash(canvas);
  writePGM(canvas, out + "/01_splash.pgm");
  screenGuide(canvas);
  writePGM(canvas, out + "/02_guide.pgm");
  screenOff(canvas);
  writePGM(canvas, out + "/10_off.pgm");

  const Item items[] = {
      {"03_ready", screenReady},          {"04_recording", screenRecording},
      {"05_saved", screenSaved},          {"06_menu", screenMenu},
      {"07_choose_tag", screenChooseTag}, {"08_syncing", screenSyncing},
      {"09_note_view", screenNoteView},   {"11_pair", screenPair},
      {"12_wifi", screenWifi},
  };

  for (const Item &it : items) {
    it.draw(canvas, m);
    writePGM(canvas, out + "/" + it.name + ".pgm");
  }

  printf("rendered %zu screens to %s\n", sizeof(items) / sizeof(items[0]) + 5,
         out.c_str());
  return 0;
}
