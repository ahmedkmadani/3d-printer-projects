// ============================================================================
//  Jota — microSD
//
//  1-bit SDMMC on CLK 39 / CMD 41 / D0 40, mounted at /sdcard, with the
//  notes living under /sdcard/jota. The card is the archive: the raw WAV of
//  every note stays here, and only the compressed copy ever leaves.
// ============================================================================
#pragma once

namespace jota {

class SdCard {
 public:
  // Mount the card and make sure the notes directory exists. False when no
  // card is fitted or it will not mount; recording then has nowhere to go.
  bool begin();
  bool mounted() const { return ok_; }

  // Flush and unmount. Before deep sleep: the card loses power with the
  // rails, and an unmounted FAT is the one that comes back clean.
  void end();

 private:
  bool ok_ = false;
};

}  // namespace jota
