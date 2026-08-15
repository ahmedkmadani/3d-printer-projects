// ============================================================================
//  Jota — battery gauge (implementation)
// ============================================================================
#include "hal/battery.h"

#include <Arduino.h>

namespace jota {

// A 503035 cell's resting curve, in millivolts against percent. Deliberately
// a table: the middle of a LiPo's discharge is almost flat, and a straight
// line from 3.3 V to 4.2 V would read ~50% for most of the useful life and
// then fall off a cliff.
struct Point {
  uint16_t mv;
  uint8_t  pct;
};

static const Point kCurve[] = {
    {4200, 100}, {4150, 95}, {4100, 90}, {4050, 85}, {4000, 80},
    {3950, 75},  {3900, 70}, {3850, 65}, {3800, 60}, {3750, 55},
    {3700, 50},  {3650, 45}, {3600, 40}, {3550, 32}, {3500, 26},
    {3450, 20},  {3400, 14}, {3350, 8},  {3300, 4},  {3200, 0},
};
static const size_t kCurveN = sizeof(kCurve) / sizeof(kCurve[0]);

uint8_t batteryPercentForMillivolts(uint16_t mv) {
  if (mv >= kCurve[0].mv) return 100;
  if (mv <= kCurve[kCurveN - 1].mv) return 0;

  for (size_t i = 1; i < kCurveN; ++i) {
    if (mv >= kCurve[i].mv) {
      // Linear between the two bracketing points.
      const Point &hi = kCurve[i - 1];
      const Point &lo = kCurve[i];
      const uint16_t span = (uint16_t)(hi.mv - lo.mv);
      const uint16_t into = (uint16_t)(mv - lo.mv);
      return (uint8_t)(lo.pct + ((hi.pct - lo.pct) * into) / span);
    }
  }
  return 0;
}

// How often to look. A pack does not move quickly, and every sample costs a
// little power and risks catching a refresh.
static const uint32_t SAMPLE_MS = 30000;

// Weight of a new reading in the running average, as a divisor. Slow on
// purpose: it is what stops a momentary sag under load from being believed.
static const uint32_t EMA_DIV = 4;

void Battery::begin() {
  if (BATTERY_ADC_PIN < 0) return;

  pinMode(BATTERY_ADC_PIN, INPUT);
  // 11 dB reads up to roughly 3.1 V, which covers a 4.2 V pack behind a 2:1
  // divider with room to spare.
  analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);

  // Take one straight away so the first screen has a real figure rather than
  // a dash that fills in half a minute later.
  const uint16_t mv = sampleMillivolts();
  if (mv > 0) {
    emaMv_ = mv;
    mv_    = mv;
    pct_   = batteryPercentForMillivolts(mv);
    known_ = true;
  }
  nextMs_ = SAMPLE_MS;
}

uint16_t Battery::sampleMillivolts() const {
  if (BATTERY_ADC_PIN < 0) return 0;

  // Median of five. One outlier — an interrupt landing mid-conversion, a
  // neighbouring rail switching — cannot move a median, but it would move a
  // mean quite a long way.
  uint32_t s[5];
  for (uint8_t i = 0; i < 5; ++i) {
    s[i] = (uint32_t)analogReadMilliVolts(BATTERY_ADC_PIN);
    delayMicroseconds(200);
  }
  for (uint8_t i = 1; i < 5; ++i) {  // insertion sort, five elements
    const uint32_t v = s[i];
    int8_t j = (int8_t)(i - 1);
    while (j >= 0 && s[j] > v) {
      s[j + 1] = s[j];
      --j;
    }
    s[j + 1] = v;
  }

  return (uint16_t)(s[2] * BATTERY_DIVIDER);
}

void Battery::loop(uint32_t nowMs, bool busy) {
  if (BATTERY_ADC_PIN < 0) return;
  if (nowMs < nextMs_) return;

  // Never sample while the panel is being driven: an e-paper refresh sags the
  // pack hard enough to read as nearly flat, and "battery low" appearing every
  // time the screen changes is exactly the kind of lie this file exists to
  // avoid. Try again shortly.
  if (busy) {
    nextMs_ = nowMs + 500;
    return;
  }
  nextMs_ = nowMs + SAMPLE_MS;

  const uint16_t mv = sampleMillivolts();
  if (mv == 0) return;

  emaMv_ = known_ ? (emaMv_ * (EMA_DIV - 1) + mv) / EMA_DIV : mv;
  mv_    = (uint16_t)emaMv_;
  pct_   = batteryPercentForMillivolts(mv_);
  known_ = true;
}

}  // namespace jota
