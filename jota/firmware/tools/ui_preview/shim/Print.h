// Minimal Arduino `Print` for the host preview build.
// Adafruit_GFX derives from Print and relies on write()/print() only.
#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

class Print {
 public:
  virtual ~Print() {}

  virtual size_t write(uint8_t c) = 0;

  virtual size_t write(const uint8_t *buf, size_t n) {
    size_t count = 0;
    while (n--) count += write(*buf++);
    return count;
  }

  size_t write(const char *s) {
    return s ? write((const uint8_t *)s, strlen(s)) : 0;
  }

  size_t print(const char *s) { return write(s); }
  size_t print(char c) { return write((uint8_t)c); }

  size_t print(int n) { return printf_("%d", n); }
  size_t print(unsigned n) { return printf_("%u", n); }
  size_t print(long n) { return printf_("%ld", n); }
  size_t print(unsigned long n) { return printf_("%lu", n); }
  size_t print(double n) { return printf_("%g", n); }

  size_t println() { return write((uint8_t)'\n'); }
  size_t println(const char *s) { return print(s) + println(); }

 private:
  template <typename T>
  size_t printf_(const char *fmt, T v) {
    char buf[32];
    const int n = snprintf(buf, sizeof(buf), fmt, v);
    return n > 0 ? write((const uint8_t *)buf, (size_t)n) : 0;
  }
};
