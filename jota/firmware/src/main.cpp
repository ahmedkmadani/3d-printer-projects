// ============================================================================
//  Jota — pocket voice-note device
//  Waveshare ESP32-S3-ePaper-1.54 (200x200 mono, SSD1681)
//
//  Records for real: mic -> ES8311 -> I2S -> WAV + ADPCM on the microSD, on
//  a task of its own so the panel and the radio keep running. No WiFi, by
//  design — the phone pulls notes over BLE and transcribes them itself.
//
//  Controls
//    BOOT (star)  short = select / start+stop recording   long = back
//    PWR          short = next item                       long = power off
// ============================================================================
#include <Arduino.h>
#include <SPI.h>
#include <GxEPD2_BW.h>

#include "driver/gpio.h"
#include "driver/rtc_io.h"
#include "esp_sleep.h"

#include "app/model.h"
#include "app/nav.h"
#include "app/notes.h"
#include "app/recorder.h"
#include "hal/battery.h"
#include "hal/buttons.h"
#include "hal/mic.h"
#include "hal/sdcard.h"
#include "util/clock.h"
#include <esp_system.h>
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

// ---- Standby ------------------------------------------------------------
// Two minutes with nothing happening and the device goes to deep sleep: the
// panel keeps its resting frame for free, the latch is held so the board
// stays powered, and either button wakes it. If it was BOOT, the wake press
// IS the record press — the note starts before the panel has redrawn. Pala
// Note behaves the same way and that is the behaviour being matched.
//
// Awake and idle the board draws tens of milliamps; a 500 mAh cell is gone
// in hours. Asleep it is microamps. Without this, daily use means
// remembering to hold PWR after every note.
static const uint32_t IDLE_SLEEP_MS = 120000;

GxEPD2_BW<GxEPD2_154_D67, GxEPD2_154_D67::HEIGHT> display(
    GxEPD2_154_D67(EPD_CS, EPD_DC, EPD_RST, EPD_BUSY));

using namespace jota;

static Nav       nav;
static Buttons   buttons;
static Battery   battery;
static AppModel  model;
static NoteStore notes;
static SdCard    sdcard;
static Mic       mic;
static Recorder  recorder;
static Link      bleLink;   // not `link`: collides with POSIX link()

static uint32_t lastActivityMs = 0;
static bool     wakeToRecord   = false;

// Asleep, the panel shows the charge it fell asleep with, for ever: deep
// sleep runs nothing and e-paper keeps its last frame. So the chip wakes on
// a timer every half hour, reads the cell, redraws the OFF frame and goes
// straight back to sleep — no radio, no card index, no buttons. A few
// seconds of work per wake, well under a percent of the cell a day, and the
// battery log gets a reading every half hour through the night, which is
// exactly what a soak test wants.
static const uint64_t SLEEP_TICK_US = 30ULL * 60ULL * 1000000ULL;
static bool           sleepTick     = false;
static uint32_t lastPaintMs    = 0;

// ---- Battery log ---------------------------------------------------------
// One line per event on the card, so a day off the charger can be read back:
//   <unix seconds or 0> <uptime s> <event> <mV> <pct>
// Sleep entries and wakes bracket the standby current; "awake" every ten
// minutes shows the running drain. This is the instrument for the soak.
static const uint32_t BAT_LOG_EVERY_MS = 10UL * 60UL * 1000UL;
static uint32_t       nextBatLogMs     = 0;

static void logBattery(const char *event) {
  Serial.printf("[bat] %s %u mV %u%%\n", event, (unsigned)battery.millivolts(),
                (unsigned)battery.percent());
  if (!sdcard.mounted()) return;
  FILE *f = fopen("/sdcard/jota/battery.log", "a");
  if (!f) return;
  fprintf(f, "%lu %lu %s %u %u\n", (unsigned long)clockNow(),
          (unsigned long)(millis() / 1000UL), event,
          (unsigned)battery.millivolts(), (unsigned)battery.percent());
  fclose(f);
}

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

// The frame the panel keeps while the device is off or asleep. E-paper holds
// its last image forever, so without this the device sits in a drawer showing
// whatever menu it was on, with a frozen clock.
static void restingFrame() {
  display.setFullWindow();
  display.firstPage();
  do {
    screenOff(display, model);
  } while (display.nextPage());
  display.hibernate();
}

static void enterDeepSleep() {
  Serial.println("[jota] idle: deep sleep. BOOT records, PWR wakes.");
  logBattery(sleepTick ? "tick" : "sleep");
  restingFrame();
  sdcard.end();
  mic.powerOff();

  // Both buttons pull to ground. Their pull-ups must survive sleep or the
  // wake pins float and the device wakes itself at random — or never.
  for (gpio_num_t pin : {(gpio_num_t)BTN_PIN_BOOT, (gpio_num_t)BTN_PIN_PWR}) {
    rtc_gpio_pullup_en(pin);
    rtc_gpio_pulldown_dis(pin);
  }
  esp_sleep_enable_ext1_wakeup((1ULL << BTN_PIN_BOOT) | (1ULL << BTN_PIN_PWR),
                               ESP_EXT1_WAKEUP_ANY_LOW);
  esp_sleep_enable_timer_wakeup(SLEEP_TICK_US);

  // The latch is the one output that must not drop: releasing it is how
  // power-off works. Hold it through sleep.
  gpio_hold_en((gpio_num_t)PWR_LATCH);
  gpio_deep_sleep_hold_en();

  delay(20);
  esp_deep_sleep_start();
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
  lastPaintMs = millis();
  nav.paintDone(lastPaintMs);
}

void setup() {
  // Back from deep sleep? Then a button is what woke us, and BOOT means
  // "record", right now, before anything else has a chance to be slow.
  const esp_sleep_wakeup_cause_t cause = esp_sleep_get_wakeup_cause();
  const bool fromSleep = cause == ESP_SLEEP_WAKEUP_EXT1;
  sleepTick            = cause == ESP_SLEEP_WAKEUP_TIMER;
  pinMode(BTN_PIN_BOOT, INPUT_PULLUP);
  wakeToRecord = fromSleep && digitalRead(BTN_PIN_BOOT) == LOW;

  // 1) Hold power on. Without this the board drops dead on battery. The hold
  //    from the last sleep is released first so the pin is ours again.
  gpio_deep_sleep_hold_dis();
  gpio_hold_dis((gpio_num_t)PWR_LATCH);
  pinMode(PWR_LATCH, OUTPUT);
  digitalWrite(PWR_LATCH, HIGH);

  // 2) Panel power (active low).
  pinMode(EPD_PWR, OUTPUT);
  digitalWrite(EPD_PWR, LOW);

  Serial.begin(115200);
  delay(200);
  Serial.printf("\n[jota] booting%s\n", fromSleep ? " (woken by a button)" : "...");

  buttons.begin();

  SPI.begin(EPD_SCK, /*MISO=*/-1, EPD_MOSI, EPD_CS);
  display.init(115200, /*initial=*/true, /*reset_duration=*/2,
               /*pulldown_rst=*/false);
  display.setRotation(0);  // vertical

  if (sleepTick) {
    // The half-hour tick: cell, card for the log, the OFF frame, back to
    // sleep. Nothing else is brought up.
    model = AppModel{};
    sdcard.begin();
    battery.begin();
    model.batteryKnown = battery.known();
    model.batteryPct   = battery.percent();
    enterDeepSleep();
  }

  model           = AppModel{};
  model.noteCount = 0;
  model.note      = {0, "--:--", nullptr, 0, nullptr};
  // The factory list. Link::begin() replaces it with whatever the phone last
  // wrote, if this device has ever been paired.
  tagsSetDefaults(model.tags);
  updateClock(millis());
  model.clock = clockBuf;

  // Card first, then the index on it, then the mic. Without a card the store
  // is empty and the recorder refuses to start; both say so on serial.
  sdcard.begin();
  notes.begin(sdcard.mounted());
  model.pending   = notes.pending();
  model.noteCount = notes.lastId();  // so the next N-xxx continues the card's
  mic.begin();
  recorder.begin(&mic, sdcard.mounted());

  // Before the first paint, so the idle screen shows a real figure rather than
  // filling one in half a minute later.
  battery.begin();
  model.batteryKnown = battery.known();
  model.batteryPct   = battery.percent();
  logBattery(fromSleep ? "wake" : "boot");
  nextBatLogMs = millis() + BAT_LOG_EVERY_MS;

  bleLink.begin(notes, model);
  Serial.printf("[jota] BLE up, %u notes pending\n", (unsigned)notes.pending());

  nav.begin(millis());
  lastActivityMs = millis();

  if (wakeToRecord) {
    // The wake press is the record press. Start the capture BEFORE the first
    // paint: the panel takes over a second to invert and the user is already
    // talking. The loop's screen-transition logic sees RECORDING already up
    // and the recorder already busy, and leaves both alone.
    nav.handle(BtnEvent::BootShort, model, millis());
    const uint16_t id = notes.nextId();
    if (recorder.start(id)) Serial.printf("[jota] woke to record N-%03u\n", (unsigned)id);
  }
  paint();

    // Restore the bond into the model. Without this, `paired` was false on every
  // boot even when a phone owned the device — and nav's "an unowned device
  // shows PAIR by itself" rule then put a pairing code on the panel every time
  // the device was switched on, owned or not. A Jota power-cycled in a cafe
  // was advertising its code to the room.
  model.paired = bleLink.hasOwner();

Serial.println("[jota] ready.");
}

void loop() {
  const uint32_t now = millis();

  const BtnEvent e = buttons.poll(now);
  if (e != BtnEvent::None) {
    nav.handle(e, model, now);
    lastActivityMs = now;
  }
  nav.tick(now, model);
  updateClock(now);

  // Mint the digits when nav opens an offer, and drop them the moment it
  // closes. The code is the proof that a phone can SEE this panel, so it must
  // live exactly as long as the panel is showing it — no longer.
  if (model.needPairCode) {
    model.needPairCode = false;
    model.pairCode     = bleLink.newPairCode();
    // Echoed to serial on purpose. Reading it needs a USB cable in your hand,
    // and physical possession is already the entire security model — the panel
    // gives the same digits to anyone who can see it. It is what makes the
    // pairing flow testable without a camera pointed at the e-paper.
    Serial.printf("[jota] pair offer open, code %s\n", model.pairCode);
  } else if (model.pairCode == nullptr) {
    bleLink.clearPairCode();
  }

  // `pending` is what the advertisement broadcasts, so it must reflect the
  // real note store rather than the recording simulation.
  static uint8_t lastPending = 0xFF;
  static Screen  lastScreen  = Screen::Ready;

  // Recording follows the screen: up when RECORDING appears, down when it
  // goes. nav decides when; main owns the mic and the card, as it owns every
  // other piece of hardware.
  const Screen scr = nav.screen();
  if (scr == Screen::Recording && lastScreen != Screen::Recording) {
    const uint16_t id = notes.nextId();
    if (recorder.start(id)) Serial.printf("[jota] recording N-%03u\n", (unsigned)id);
  }
  if (scr != Screen::Recording && recorder.running()) recorder.stop();

  RecResult rr;
  if (recorder.takeResult(rr)) {
    if (rr.ok) {
      // The tag may already have been chosen on SAVED while the task was
      // closing its files; whatever is chosen after lands via setTag below.
      const char *tag = (model.note.id == rr.id) ? model.note.tag : nullptr;
      if (!notes.add(rr.id, rr.secs, rr.bytes, rr.crc, tag)) {
        Serial.println("[jota] note recorded but NOT indexed");
      }
    } else {
      Serial.println("[jota] recording lost");
    }
    // Keep the panel's numbering tied to the card's, even after a failure.
    model.noteCount = notes.lastId();
  }
  // The tag on SAVED is a toggle until the screen is left; then it is final.
  if (lastScreen == Screen::Saved && scr != Screen::Saved) {
    notes.setTag(model.note.id, model.note.tag);
  }

  model.pending = notes.pending();

  // Advertise fast for a minute whenever there is a fresh reason for the
  // phone to notice: a note appeared, or the user asked for a sync.
  if (model.pending != lastPending && model.pending > 0) bleLink.nudge(now);

  // Repaint the count when it changes, which it does WITHOUT anyone touching
  // a button — a note is saved, or the phone acks one and it falls.
  //
  // Nothing did this before, and e-paper holds its last frame for ever: after
  // a sync took all three notes the panel went on saying "3 WAITING"
  // indefinitely, while the advertisement it was sending out at that very
  // moment correctly said zero. The one question this device exists to
  // answer — is my thought safe? — was being answered wrongly by the only
  // part of it the user actually looks at.
  if (model.pending != lastPending && nav.screen() == Screen::Ready) {
    nav.markDirtyRegion(
        Rect{0, FIGURE_REGION_Y, SCREEN_W, FIGURE_REGION_H});
  }
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
    // it will be right the next time that screen is drawn. The figure lives
    // on the status line, so only that band is pushed: a whole-screen
    // partial for a percent tick left READY in partial-refresh grey — which
    // on this panel reads as a disabled device — until something else
    // happened to draw it in full.
    if (nav.screen() == Screen::Ready) {
      nav.markDirtyRegion(Rect{0, (int16_t)(FOOT_RULE_Y - 2), SCREEN_W,
                               (int16_t)(SCREEN_H - (FOOT_RULE_Y - 2))});
    }
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
    model.noteCount = notes.lastId();
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
    logBattery("off");
    // A power press while recording saves first (nav committed the note);
    // give the task time to close its files before the latch drops.
    if (recorder.busy()) {
      recorder.stop();
      RecResult last;
      while (!recorder.takeResult(last)) delay(5);
      if (last.ok) notes.add(last.id, last.secs, last.bytes, last.crc, model.note.tag);
    }
    restingFrame();
    sdcard.end();
    digitalWrite(PWR_LATCH, LOW);  // release the latch: board cuts power
    while (true) delay(100);       // reached only while USB keeps us alive
  }

  // A quiet screen that was last drawn by a partial gets one full refresh a
  // few seconds after it settled. Partials on this panel come out grey and
  // the full is what makes READY read as ON; the flash lands after the user
  // has stopped touching the device, never mid-gesture.
  if (!nav.dirty() && partialsSinceFull > 0 && quietScreen(nav.screen()) &&
      now - lastPaintMs >= 3000 && !recorder.busy()) {
    nav.markDirty(/*full=*/true);
  }

  if (now >= nextBatLogMs) {
    nextBatLogMs = now + BAT_LOG_EVERY_MS;
    logBattery("awake");
  }

  if (nav.dirty()) paint();

  // Anything that is not "READY with nobody around" counts as activity: a
  // note being captured, a phone mid-sync, a screen with a timer on it.
  if (nav.screen() != Screen::Ready || recorder.busy() || bleLink.connected()) {
    lastActivityMs = now;
  }
  if (now - lastActivityMs >= IDLE_SLEEP_MS) enterDeepSleep();

  delay(5);
}
