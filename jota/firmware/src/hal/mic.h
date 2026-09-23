// ============================================================================
//  Jota — microphone
//
//  The onboard mic goes through the ES8311 codec: I2C 47/48 for control,
//  I2S (MCLK 14, BCLK 15, WS 38, DIN 16) for the samples. The codec sits on
//  an audio rail switched by GPIO42 and is dead until that pin is driven.
//
//  Brought up the way Waveshare's own audio example and Pala Note both do it
//  — Espressif's esp_codec_dev component (Apache-2.0, vendored under
//  src/vendor) — but without their codec_board wrapper, which needs the IDF 5
//  drivers this core does not have. The I2C and I2S set-up is done here with
//  the IDF 4.4 drivers instead.
//
//  The codec is opened stereo and only the left channel is kept: that is the
//  configuration both references run, and it is the one known to work.
// ============================================================================
#pragma once

#include <stddef.h>
#include <stdint.h>

namespace jota {

static const uint32_t MIC_SAMPLE_RATE = 16000;

class Mic {
 public:
  // Power the rail, install the buses, probe the codec. False = no codec
  // answered, and every later call is a no-op.
  bool begin();
  bool ready() const { return ready_; }

  // Start / stop the capture clocks. Open only while recording: an open codec
  // draws current and fills DMA buffers nobody reads.
  bool open();
  void close();

  // Blocking read of `n` mono samples. Returns n, or 0 on failure.
  size_t read(int16_t *mono, size_t n);

 private:
  bool     ready_     = false;
  bool     open_      = false;
  void    *dev_       = nullptr;  // esp_codec_dev_handle_t
  int16_t *stereo_    = nullptr;
  size_t   stereoCap_ = 0;        // in frames
};

}  // namespace jota
