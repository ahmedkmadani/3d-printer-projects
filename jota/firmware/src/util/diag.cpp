// ============================================================================
//  Jota — diagnostics (implementation)
// ============================================================================
#include "util/diag.h"

#include <Arduino.h>
#include <Preferences.h>

#include <esp_system.h>
#include <stdio.h>

// Injected by git_rev.py at build time. The fallbacks only appear when the
// build runs outside a git checkout.
#ifndef JOTA_GIT_REV
#define JOTA_GIT_REV "dev"
#endif
#ifndef JOTA_BUILD_DATE
#define JOTA_BUILD_DATE "unknown"
#endif

namespace jota {

static const char *g_reset   = "other";
static uint32_t    g_boots   = 0;
static uint32_t    g_crashes = 0;
static uint32_t    g_notes   = 0;
static uint32_t    g_syncs   = 0;

static void save(const char *key, uint32_t v) {
  Preferences p;
  p.begin("diag", /*readOnly=*/false);
  p.putULong(key, v);
  p.end();
}

void diagBegin() {
  switch (esp_reset_reason()) {
    case ESP_RST_POWERON:   g_reset = "poweron"; break;
    case ESP_RST_SW:        g_reset = "sw"; break;
    case ESP_RST_PANIC:     g_reset = "panic"; break;
    case ESP_RST_INT_WDT:
    case ESP_RST_TASK_WDT:
    case ESP_RST_WDT:       g_reset = "wdt"; break;
    case ESP_RST_BROWNOUT:  g_reset = "brownout"; break;
    case ESP_RST_DEEPSLEEP: g_reset = "sleep"; break;
    default:                g_reset = "other"; break;
  }
  const bool crashed = strcmp(g_reset, "panic") == 0 ||
                       strcmp(g_reset, "wdt") == 0 ||
                       strcmp(g_reset, "brownout") == 0;

  Preferences p;
  p.begin("diag", /*readOnly=*/false);
  g_boots   = p.getULong("boots", 0) + 1;
  g_crashes = p.getULong("crashes", 0) + (crashed ? 1 : 0);
  g_notes   = p.getULong("notes", 0);
  g_syncs   = p.getULong("syncs", 0);
  p.putULong("boots", g_boots);
  if (crashed) p.putULong("crashes", g_crashes);
  p.end();

  Serial.printf("[diag] fw %s built %s, reset %s, boot %lu (crashes %lu)\n",
                JOTA_GIT_REV, JOTA_BUILD_DATE, g_reset,
                (unsigned long)g_boots, (unsigned long)g_crashes);
}

const char *diagResetWord() { return g_reset; }

void diagCountNote() { save("notes", ++g_notes); }
void diagCountSync() { save("syncs", ++g_syncs); }

size_t diagJson(char *out, size_t n) {
  const int w = snprintf(
      out, n,
      "{\"fw\":\"%s\",\"built\":\"%s\",\"reset\":\"%s\",\"boots\":%lu,"
      "\"crashes\":%lu,\"notes\":%lu,\"syncs\":%lu,\"up\":%lu,\"heap\":%lu}",
      JOTA_GIT_REV, JOTA_BUILD_DATE, g_reset, (unsigned long)g_boots,
      (unsigned long)g_crashes, (unsigned long)g_notes, (unsigned long)g_syncs,
      (unsigned long)(millis() / 1000UL),
      (unsigned long)esp_get_free_heap_size());
  return (w < 0 || (size_t)w >= n) ? 0 : (size_t)w;
}

}  // namespace jota
