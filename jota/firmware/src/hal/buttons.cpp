// ============================================================================
//  Jota — button HAL (implementation)
// ============================================================================
#include "hal/buttons.h"

#include <Arduino.h>

namespace jota {

// Verified against Waveshare's user_config.h for this board.
static const uint8_t PIN_BOOT = 0;
static const uint8_t PIN_PWR  = 18;

static const uint32_t DEBOUNCE_MS = 30;
static const uint32_t LONG_MS     = 1500;

// Erase is destructive and unrecoverable, so its gesture is deliberately
// longer than any accidental pocket press — and long enough that you cannot
// arrive at it without meaning to.
static const uint32_t BOTH_MS     = 5000;

void Buttons::begin() {
  boot_ = Btn{PIN_BOOT, false, false, 0, 0, false};
  pwr_  = Btn{PIN_PWR, false, false, 0, 0, false};

  pinMode(PIN_BOOT, INPUT_PULLUP);
  pinMode(PIN_PWR, INPUT_PULLUP);
}

uint8_t Buttons::update(Btn &b, uint32_t nowMs) {
  // Both buttons pull to GND when pressed.
  const bool raw = (digitalRead(b.pin) == LOW);

  if (raw != b.raw) {
    b.raw       = raw;
    b.changedMs = nowMs;
    return 0;
  }
  if ((nowMs - b.changedMs) < DEBOUNCE_MS) return 0;

  if (raw && !b.down) {  // press begins
    b.down      = true;
    b.downMs    = nowMs;
    b.longFired = false;
    return 0;
  }

  if (raw && b.down && !b.longFired && (nowMs - b.downMs) >= LONG_MS) {
    b.longFired = true;
    return 2;
  }

  if (!raw && b.down) {  // release
    b.down = false;
    // If the long event already fired, the release is not also a short.
    return b.longFired ? 0 : 1;
  }

  return 0;
}

BtnEvent Buttons::poll(uint32_t nowMs) {
  const uint8_t b = update(boot_, nowMs);
  const uint8_t p = update(pwr_, nowMs);

  // BOTH held is checked FIRST and swallows everything else. With two buttons
  // there is no third gesture available for "erase", so it has to be the pair
  // — and it has to outrank the singles, or the erase hold would fire PwrLong
  // (power off) at 1.5s and the device would switch itself off half way
  // through the gesture, every time.
  if (boot_.down && pwr_.down && !bothFired_ &&
      (nowMs - (boot_.downMs > pwr_.downMs ? boot_.downMs : pwr_.downMs)) >=
          BOTH_MS) {
    bothFired_ = true;
    // Neither single press may also report: the user made one gesture.
    boot_.longFired = true;
    pwr_.longFired  = true;
    return BtnEvent::BothLong;
  }
  if (!boot_.down && !pwr_.down) bothFired_ = false;

  // While both are down but the threshold has not been reached, hold the
  // singles back rather than firing them — otherwise starting the erase
  // gesture would first start a recording.
  if (boot_.down && pwr_.down) return BtnEvent::None;

  switch (b) {
    case 1: return BtnEvent::BootShort;
    case 2: return BtnEvent::BootLong;
    default: break;
  }
  switch (p) {
    case 1: return BtnEvent::PwrShort;
    case 2: return BtnEvent::PwrLong;
    default: break;
  }
  return BtnEvent::None;
}

}  // namespace jota
