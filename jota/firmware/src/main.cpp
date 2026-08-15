// ============================================================================
//  Jota — pocket voice-note device
//  Waveshare ESP32-S3-ePaper-1.54 (200x200 mono, SSD1681)
//
//  PHASE 1: the complete UI and navigation, with recording and syncing
//  SIMULATED. No audio, no SD, no WiFi yet — this build exists to lock the
//  look and the interaction on real hardware.
//
//  Controls
//    BOOT (star)  short = select / start+stop recording   long = back
//    PWR          short = next item                       long = power off
// ============================================================================
#include <Arduino.h>
#include <SPI.h>
#include <GxEPD2_BW.h>

#include "app/model.h"
#include "app/nav.h"
#include "app/notes.h"
#include "hal/battery.h"
#include "hal/buttons.h"
#include "link/ble.h"
#include "ui/screens.h"
#include "ui/theme.h"

// ---- Pin map -----------------------------------------------------------
// Verified against Waveshare's official examples for this board
// (waveshareteam/ESP32-S3-ePaper-1.54, 02_Example/Arduino/user_config.h).
static const int EPD_SCK  = 12;
static const int EPD_MOSI = 13;
static const int EPD_CS   = 11;
static const int EPD_DC   = 10;
static const int EPD_RST  = 9;
static const int EPD_BUSY = 8;
static const int EPD_PWR  = 6;   // panel power, active LOW
static const int PWR_LATCH = 17;  // HIGH keeps the board alive off USB
static const int AUDIO_PWR = 42;  // codec rail — phase 2

GxEPD2_BW<GxEPD2_154_D67, GxEPD2_154_D67::HEIGHT> display(
    GxEPD2_154_D67(EPD_CS, EPD_DC, EPD_RST, EPD_BUSY));

using namespace jota;

static Nav       nav;
static Buttons   buttons;
static Battery   battery;
static AppModel  model;
static NoteStore notes;
static Link      bleLink;   // not `link`: collides with POSIX link()

// Full refresh clears e-paper ghosting; partial is fast but accumulates it.
static uint16_t       partialsSinceFull = 0;
// Moving a solid inverted row is the worst case for partial update: the old
// black bar leaves grey residue. 4 keeps a list legible while scrolling
// without flashing on every press.
static const uint16_t FULL_EVERY        = 4;

// A screen is "quiet" when nothing is animating and the user is not mid-act.
// The de-ghosting flash is deferred to one of these, so it is only ever seen
// while idle — never interrupting a recording, a sync, or a confirmation.
static bool quietScreen(Screen s) {
  // READY and PAIR are the only screens where nothing is running and the user
  // is not mid-act. SAVED is excluded on purpose: its ten-second tag offer is
  // the user's, and a de-ghosting flash across it would look like the note had
  // been lost.
  return s == Screen::Ready || s == Screen::Pair;
}

// PHASE 1 CLOCK: counts from 00:00 at boot. There is no real time source yet
// — the board's PCF85063 RTC (I2C 47/48) has no valid time until phase 2 sets
// it over NTP, so reading it now would just show a plausible-looking lie.
static char     clockBuf[6]  = "00:00";
static uint32_t lastClockMin = 0xFFFFFFFF;

// Returns true when the displayed minute actually changed.
static bool updateClock(uint32_t nowMs) {
  const uint32_t mins = nowMs / 60000UL;
  if (mins == lastClockMin) return false;
  lastClockMin = mins;
  snprintf(clockBuf, sizeof(clockBuf), "%02u:%02u",
           (unsigned)((mins / 60) % 24), (unsigned)(mins % 60));
  return true;
}

static void paint() {
  const bool ghostDue =
      partialsSinceFull >= FULL_EVERY && quietScreen(nav.screen());
  const bool full = nav.needsFull() || ghostDue;

  if (full) {
    display.setFullWindow();
    partialsSinceFull = 0;
  } else if (nav.hasRegion()) {
    // Only one element changed — push just those pixels. A five-digit timer
    // does not need all 40000.
    const Rect &r = nav.region();
    display.setPartialWindow(r.x, r.y, r.w, r.h);
    partialsSinceFull++;
  } else {
    display.setPartialWindow(0, 0, display.width(), display.height());
    partialsSinceFull++;
  }

  display.firstPage();
  do {
    renderScreen(display, nav.screen(), model);
  } while (display.nextPage());

  nav.clearDirty();
  // The draw above blocks for up to ~2s on a full refresh. Timed screens must
  // start counting from now — when the user can actually see them.
  nav.paintDone(millis());
}

void setup() {
  // 1) Hold power on. Without this the board drops dead on battery.
  pinMode(PWR_LATCH, OUTPUT);
  digitalWrite(PWR_LATCH, HIGH);

  // 2) Panel power (active low).
  pinMode(EPD_PWR, OUTPUT);
  digitalWrite(EPD_PWR, LOW);

  // 3) Keep the audio rail off until phase 2 actually needs it.
  pinMode(AUDIO_PWR, OUTPUT);
  digitalWrite(AUDIO_PWR, LOW);

  Serial.begin(115200);
  delay(200);
  Serial.println("\n[jota] booting...");

  buttons.begin();

  SPI.begin(EPD_SCK, /*MISO=*/-1, EPD_MOSI, EPD_CS);
  display.init(115200, /*initial=*/true, /*reset_duration=*/2,
               /*pulldown_rst=*/false);
  display.setRotation(0);  // vertical

  model           = AppModel{};
  model.noteCount = 0;
  model.note      = {0, "--:--", nullptr, 0, nullptr};
  // The factory list. Link::begin() replaces it with whatever the phone last
  // wrote, if this device has ever been paired.
  tagsSetDefaults(model.tags);
  updateClock(millis());
  model.clock = clockBuf;

  // Dummy notes live in flash — no SD card and no microphone needed yet, so
  // the phone app can be built against a real protocol today.
  notes.begin();
  model.pending = notes.pending();

  // Before the first paint, so the idle screen shows a real figure rather than
  // filling one in half a minute later.
  battery.begin();
  model.batteryKnown = battery.known();
  model.batteryPct   = battery.percent();

  bleLink.begin(notes, model);
  Serial.printf("[jota] BLE up, %u notes pending\n", (unsigned)notes.pending());

  nav.begin(millis());
  paint();

  Serial.println("[jota] ready.");
}

void loop() {
  const uint32_t now = millis();

  const BtnEvent e = buttons.poll(now);
  if (e != BtnEvent::None) nav.handle(e, model, now);
  nav.tick(now, model);
  updateClock(now);

  // The pairing code the phone must present is whatever the panel is showing.
  bleLink.setPairCode(model.pairCode);

  // `pending` is what the advertisement broadcasts, so it must reflect the
  // real note store rather than the recording simulation.
  static uint8_t lastPending = 0xFF;
  static Screen  lastScreen  = Screen::Ready;
  model.pending = notes.pending();

  // Advertise fast for a minute whenever there is a fresh reason for the
  // phone to notice: a note appeared, or the user asked for a sync.
  if (model.pending != lastPending && model.pending > 0) bleLink.nudge(now);
  // Landing on READY after saving is the moment a phone should be looking:
  // there is a fresh note and the user has stopped touching the device. The
  // old trigger was opening the SYNC screen, which no longer exists — syncing
  // is not something you ask this device to do.
  if (nav.screen() == Screen::Ready && lastScreen == Screen::Saved) {
    bleLink.nudge(now);
  }
  lastPending = model.pending;
  lastScreen  = nav.screen();

  // `nav.dirty()` means a refresh is imminent; sampling into one reads the
  // pack under load and reports a healthy battery as nearly flat.
  battery.loop(now, /*busy=*/nav.dirty());
  if (battery.known() &&
      (battery.percent() != model.batteryPct || !model.batteryKnown)) {
    model.batteryKnown = true;
    model.batteryPct   = battery.percent();
    // Only the idle screen carries the gauge as a live figure; anywhere else
    // it will be right the next time that screen is drawn.
    if (nav.screen() == Screen::Ready) nav.markDirty();
  }
  bleLink.setBattery(battery.advByte());

  bleLink.loop(now);

  // A tag write from the phone changes what TAGS draws. Repaint it while the
  // user is looking at it — otherwise the panel would keep showing the old
  // list until something else happened to redraw, which on e-paper is
  // indistinguishable from the write having failed.
  if (bleLink.takeTagsChanged() && nav.screen() == Screen::Saved) {
    nav.markDirty(/*full=*/true);
  }

  // The user held both buttons twice: erase everything and start over. Nav
  // asks; main does it, because nav owns no storage and no radio.
  if (nav.wipeRequested()) {
    Serial.println("[jota] ERASE: wiping notes, owner and tags");
    nav.clearWipeRequest();
    notes.eraseAll();
    bleLink.forgetOwner();
    tagsSetDefaults(model.tags);
    model.noteCount = 0;
    model.pending   = notes.pending();
    model.paired    = false;
    model.authed    = false;
    model.note      = {0, "--:--", nullptr, 0, nullptr};
    model.tagSel    = 0;
    // Straight back to the unowned state, which puts PAIR up by itself.
    nav.go(Screen::Ready, now);
    nav.markDirty(/*full=*/true);
  }

  if (nav.powerOff()) {
    Serial.println("[jota] powering off");
    // Leave a deliberate resting frame. E-paper holds its last image forever,
    // so without this the device sits in a drawer showing whatever menu it
    // was on, with a frozen clock.
    display.setFullWindow();
    display.firstPage();
    do {
      screenOff(display, model);
    } while (display.nextPage());

    display.hibernate();
    digitalWrite(PWR_LATCH, LOW);  // release the latch: board cuts power
    while (true) delay(100);       // reached only while USB keeps us alive
  }

  if (nav.dirty()) paint();

  delay(5);
}
