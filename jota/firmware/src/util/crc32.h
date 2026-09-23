// ============================================================================
//  Jota — CRC32 (IEEE, reflected), table-less
//
//  Shared by the recorder (which computes a note's CRC as it writes the
//  ADPCM copy) and the note store (which the phone's ack is checked against).
//  Table-less on purpose: a few hundred KB per note is well under a second
//  and it saves 1 KB of RAM.
// ============================================================================
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace jota {

static inline uint32_t crc32Update(uint32_t crc, const uint8_t *buf, size_t n) {
  crc = ~crc;
  while (n--) {
    crc ^= *buf++;
    for (int k = 0; k < 8; ++k) {
      crc = (crc >> 1) ^ (0xEDB88320u & (uint32_t)(-(int32_t)(crc & 1)));
    }
  }
  return ~crc;
}

}  // namespace jota
