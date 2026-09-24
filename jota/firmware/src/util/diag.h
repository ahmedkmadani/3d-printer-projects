// ============================================================================
//  Jota — diagnostics
//
//  The device could not answer "which firmware are you" or "why did you
//  reboot", and every bug report started by rediscovering both. This module
//  is the memory: a build identity injected at compile time (git_rev.py),
//  the reset reason of the current boot, and four counters that survive
//  power-off in NVS — boots, crashes, notes recorded, syncs served.
//
//  Served to the phone over the `diag` characteristic (docs/ble-service.md)
//  and printed at boot, so the answer is one serial line or one BLE read
//  away instead of an afternoon.
// ============================================================================
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace jota {

// Reads the reset reason and bumps the persistent counters. Call once per
// real boot — the half-hour sleep tick must NOT call it, or the counters
// count the clock instead of the user.
void diagBegin();

// This boot's reset reason as one short word: poweron / sw / panic / wdt /
// brownout / sleep / other.
const char *diagResetWord();

// A note was recorded and indexed (not recovered — recovery re-indexes an
// old recording, it does not make a new one).
void diagCountNote();

// The phone read the index on an authenticated link: a sync was served.
void diagCountSync();

// The JSON the `diag` characteristic answers with. Returns the byte count.
size_t diagJson(char *out, size_t n);

}  // namespace jota
