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



// ---- three directions, for choosing between -----------------------------
// Each is a whole language, shown across the three screens you actually live
// in. Drawn with the real widgets, so whatever is picked is what ships.
//
// The rule every direction must obey: RECORDING is READY plus ink, never
// minus. Partial refresh lays ink down cleanly but leaves residue where ink is
// removed, so a direction that moves or hides something on record costs a
// 1.3 s full repaint — and "recording" arriving late is the one thing this
// device cannot afford.

static void fmtT(char *b, size_t n, uint16_t secs) {
  snprintf(b, n, "%02u:%02u", (unsigned)(secs / 60), (unsigned)(secs % 60));
}

// ===== 1. WORD — the name is the screen. Quietest thing that can work. =====
static void w_ready(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, SCREEN_H / 2 - 8);
  if (m.pending) {
    char l[24];
    snprintf(l, sizeof(l), "%u waiting", (unsigned)m.pending);
    g.setFont(font::reading());
    textCenteredAt(g, l, CENTER_X, SCREEN_H / 2 + 36);
  }
}
static void w_rec(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  g.fillCircle(CENTER_X, 50, REC_DOT_R, INK);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, SCREEN_H / 2 - 8);
  char t[12]; fmtT(t, sizeof(t), m.recSecs);
  g.setFont(font::figure());
  textCentered(g, t, CENTER_X, SCREEN_H / 2 + 44);
}
static void w_saved(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Saved", CENTER_X, SCREEN_H / 2 - 8);
  char t[12]; fmtT(t, sizeof(t), m.note.secs);
  g.setFont(font::reading());
  textCenteredAt(g, t, CENTER_X, SCREEN_H / 2 + 36);
}

// ===== 2. FIGURE — the one number that matters, as big as it will go. =====
// Idle answers "is my thought safe" with the count itself; recording answers
// "is it listening" with the clock. The word shrinks to a label.
static void f_ready(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  char c[8]; snprintf(c, sizeof(c), "%u", (unsigned)m.pending);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, m.pending ? c : "-", CENTER_X, SCREEN_H / 2 - 6);
  g.setFont(font::label());
  textCenteredAt(g, m.pending ? "WAITING" : "READY", CENTER_X,
                 SCREEN_H / 2 + 40);
}
static void f_rec(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  char t[12]; fmtT(t, sizeof(t), m.recSecs);
  g.fillCircle(30, SCREEN_H / 2 - 6, REC_DOT_R, INK);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, t, CENTER_X + 12, SCREEN_H / 2 - 6);
  g.setFont(font::label());
  textCenteredAt(g, "RECORDING", CENTER_X, SCREEN_H / 2 + 40);
}
static void f_saved(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  char t[12]; fmtT(t, sizeof(t), m.note.secs);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, t, CENTER_X, SCREEN_H / 2 - 6);
  g.setFont(font::label());
  textCenteredAt(g, "SAVED", CENTER_X, SCREEN_H / 2 + 40);
}

// ===== 3. FRAME — one hairline of chrome, content beneath. =====
// The most "instrument" of the three: the status line always says which Jota
// and how many are waiting, and the body says what it is doing right now.
static void r_chrome(Adafruit_GFX &g, const AppModel &m, const char *right) {
  const char *d = m.deviceId ? m.deviceId : "";
  const size_t n = strlen(d);
  char id[8];
  snprintf(id, sizeof(id), "%s", n > 4 ? d + n - 4 : d);
  for (char *q = id; *q; ++q) *q = (char)toupper((unsigned char)*q);
  statusBar(g, id, right);
  linkDot(g, id, m.paired, m.authed);
}
static void r_ready(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  char c[8]; snprintf(c, sizeof(c), "%03u", (unsigned)m.pending);
  r_chrome(g, m, c);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, CONTENT_MID);
}
static void r_rec(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  char c[8]; snprintf(c, sizeof(c), "%03u", (unsigned)m.pending);
  r_chrome(g, m, c);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, CONTENT_MID);
  g.fillCircle(CENTER_X, CONTENT_MID - 46, REC_DOT_R, INK);
  char t[12]; fmtT(t, sizeof(t), m.recSecs);
  g.setFont(font::figure());
  textCentered(g, t, CENTER_X, CONTENT_MID + 54);
}
static void r_saved(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  char t[12]; fmtT(t, sizeof(t), m.note.secs);
  char id[16]; snprintf(id, sizeof(id), "N-%03u", (unsigned)m.note.id);
  statusBar(g, id, t);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Saved", CENTER_X, CONTENT_MID);
}


// ---- iterations between WORD and FRAME, now carrying STATE --------------
// Three facts have to be readable at rest: is it linked to my phone, how many
// notes are waiting, and how much charge is left. All three iterations say all
// three things — what differs is WHERE they live and how loudly.
//
// The link is a dot rather than a word: filled = a phone is connected right
// now, hollow = one is bonded but away, absent = nothing has ever paired. Same
// vocabulary as the app's own chip, so the two objects read as one product.
//
// All keep the rule that RECORDING is READY plus ink, never minus.

// A — ONE LINE. Everything in the status row: link, charge, waiting. The body
// is nothing but the name.
static void a_ready(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  char right[24];
  if (m.batteryKnown)
    snprintf(right, sizeof(right), "%u%%  %u", (unsigned)m.batteryPct,
             (unsigned)m.pending);
  else
    snprintf(right, sizeof(right), "%u", (unsigned)m.pending);
  statusBar(g, "", right);
  linkDot(g, "", m.paired, m.authed);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, CONTENT_MID + 4);
}
static void a_rec(Adafruit_GFX &g, const AppModel &m) {
  a_ready(g, m);
  g.fillCircle(CENTER_X, CONTENT_TOP + 22, REC_DOT_R, INK);
  char t[12]; fmtT(t, sizeof(t), m.recSecs);
  g.setTextColor(INK);
  g.setFont(font::figure());
  textCentered(g, t, CENTER_X, CONTENT_BOTTOM - 14);
}

// B — SPLIT. The link and what is waiting go up top where a status line
// belongs; the charge goes to the foot as the gauge, where a physical
// quantity reads better as a shape than a number.
static void b_ready(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  char right[24] = "";
  if (m.pending) snprintf(right, sizeof(right), "%u WAITING",
                          (unsigned)m.pending);
  statusBar(g, "", right);
  linkDot(g, "", m.paired, m.authed);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, CONTENT_MID - 6);
  batteryGauge(g, CENTER_X, m.batteryPct, m.batteryKnown);
}
static void b_rec(Adafruit_GFX &g, const AppModel &m) {
  b_ready(g, m);
  g.fillCircle(CENTER_X, CONTENT_TOP + 20, REC_DOT_R, INK);
  char t[12]; fmtT(t, sizeof(t), m.recSecs);
  g.setTextColor(INK);
  g.setFont(font::figure());
  textCentered(g, t, CENTER_X, CONTENT_MID + 46);
}

// C — FOOT. Nothing above the name at all. Every piece of state sits on one
// quiet line at the bottom, so the resting screen is the mark and a footnote.
static void c_ready(Adafruit_GFX &g, const AppModel &m) {
  clear(g);
  g.setTextColor(INK);
  g.setFont(font::wordmark());
  textCenteredAt(g, "Jota", CENTER_X, SCREEN_H / 2 - 16);

  rule(g, MARGIN, CONTENT_BOTTOM - 34, CONTENT_W);
  char l[28];
  if (m.pending)
    snprintf(l, sizeof(l), "%u waiting", (unsigned)m.pending);
  else
    snprintf(l, sizeof(l), "all synced");
  g.setFont(font::reading());
  textLeft(g, l, MARGIN + 12, CONTENT_BOTTOM - 12);
  if (m.batteryKnown) {
    char b[8];
    snprintf(b, sizeof(b), "%u%%", (unsigned)m.batteryPct);
    textRight(g, b, SCREEN_W - MARGIN, CONTENT_BOTTOM - 12);
  }
  // The link dot, on the same baseline at the left edge.
  if (m.paired || m.authed) {
    if (m.authed) g.fillCircle(MARGIN + 3, CONTENT_BOTTOM - 16, 3, INK);
    else g.drawCircle(MARGIN + 3, CONTENT_BOTTOM - 16, 3, INK);
  }
}
static void c_rec(Adafruit_GFX &g, const AppModel &m) {
  c_ready(g, m);
  g.fillCircle(CENTER_X, 44, REC_DOT_R, INK);
  char t[12]; fmtT(t, sizeof(t), m.recSecs);
  g.setTextColor(INK);
  g.setFont(font::figure());
  textCentered(g, t, CENTER_X, SCREEN_H / 2 + 24);
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
  struct V { const char *n; void (*f)(Adafruit_GFX &, const AppModel &); };
  const V variants[] = {
      {"D1_word_ready", w_ready},   {"D1_word_rec", w_rec},
      {"D1_word_saved", w_saved},   {"D2_figure_ready", f_ready},
      {"D2_figure_rec", f_rec},     {"D2_figure_saved", f_saved},
      {"D3_frame_ready", r_ready},  {"D3_frame_rec", r_rec},
      {"D3_frame_saved", r_saved},
      {"E1_quiet_ready", a_ready},  {"E1_quiet_rec", a_rec},
      {"E2_under_ready", b_ready},  {"E2_under_rec", b_rec},
      {"E3_words_ready", c_ready},  {"E3_words_rec", c_rec},
  };
  for (const V &v : variants) {
    v.f(canvas, m);
    writePGM(canvas, out + "/" + v.n + ".pgm");
  }

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
