#include "hal/sdcard.h"

#include <Arduino.h>
#include <SD_MMC.h>
#include <sys/stat.h>

#include "app/notes.h"

namespace jota {

// Verified against Waveshare's 04_SD_Card example for this board.
static const int SD_CLK = 39;
static const int SD_CMD = 41;
static const int SD_D0  = 40;

bool SdCard::begin() {
  ok_ = false;
  if (!SD_MMC.setPins(SD_CLK, SD_CMD, SD_D0)) {
    Serial.println("[sd] setPins failed");
    return false;
  }
  // 1-bit: the board only routes D0.
  if (!SD_MMC.begin("/sdcard", /*mode1bit=*/true)) {
    Serial.println("[sd] no card, or it would not mount");
    return false;
  }
  if (SD_MMC.cardType() == CARD_NONE) {
    Serial.println("[sd] no card");
    return false;
  }
  struct stat st;
  if (stat(NOTES_DIR, &st) != 0 && mkdir(NOTES_DIR, 0777) != 0) {
    Serial.printf("[sd] cannot create %s\n", NOTES_DIR);
    return false;
  }
  Serial.printf("[sd] mounted, %llu MB, %llu MB used\n",
                SD_MMC.cardSize() / (1024ULL * 1024ULL),
                SD_MMC.usedBytes() / (1024ULL * 1024ULL));
  ok_ = true;
  return true;
}

}  // namespace jota
