// Minimal Arduino core shim for the host preview build.
//
// Only what Adafruit_GFX actually touches: fixed-width types, the PROGMEM
// no-ops, a tiny String (used by one getTextBounds overload) and Print.
#pragma once

#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

#include <algorithm>
#include <string>

typedef uint8_t boolean;
typedef uint8_t byte;

// Flash-string machinery is meaningless on the host.
#define PROGMEM
#define PSTR(s) (s)
#define F(s) (s)
class __FlashStringHelper;

using std::max;
using std::min;

#ifndef constrain
#define constrain(a, lo, hi) ((a) < (lo) ? (lo) : ((a) > (hi) ? (hi) : (a)))
#endif

#define DEG_TO_RAD 0.017453292519943295769236907684886
#define RAD_TO_DEG 57.295779513082320876798154814105
#define radians(deg) ((deg) * DEG_TO_RAD)
#define degrees(rad) ((rad) * RAD_TO_DEG)
#define sq(x) ((x) * (x))

// Adafruit_GFX declares a getTextBounds(const String&, ...) overload, so the
// type has to exist even though the preview never calls it.
class String {
 public:
  String() {}
  String(const char *s) : s_(s ? s : "") {}
  const char  *c_str() const { return s_.c_str(); }
  unsigned int length() const { return (unsigned int)s_.size(); }
  char         operator[](unsigned int i) const { return s_[i]; }

 private:
  std::string s_;
};

#include "Print.h"
