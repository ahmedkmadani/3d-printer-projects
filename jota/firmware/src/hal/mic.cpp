#include "hal/mic.h"

#include <Arduino.h>
#include <string.h>

#include "driver/i2c.h"
#include "driver/i2s.h"
#include "esp_heap_caps.h"
#include "vendor/esp_codec_dev/include/esp_codec_dev.h"
#include "vendor/esp_codec_dev/include/esp_codec_dev_defaults.h"

namespace jota {

// Pin map: jota/firmware/README.md, verified against Waveshare's examples.
static const int PIN_AUDIO_PWR = 42;
static const int PIN_PA        = 46;  // speaker amplifier enable
static const int PIN_I2C_SDA   = 47;
static const int PIN_I2C_SCL   = 48;
static const int PIN_I2S_MCLK  = 14;
static const int PIN_I2S_BCLK  = 15;
static const int PIN_I2S_WS    = 38;
static const int PIN_I2S_DIN   = 16;
static const int PIN_I2S_DOUT  = 45;

static const i2c_port_t I2C_PORT = I2C_NUM_0;
static const i2s_port_t I2S_PORT = I2S_NUM_0;

// One step under what both references use (45 dB). At 45 the meter showed
// full-scale clipping on loud syllables spread through every note (N-008:
// 37 clipped samples from 0.9 s to 9.9 s, rms -21 dBFS). The ES8311's mic
// gain steps in 6 dB; 36 keeps speech around -27 dBFS rms with headroom for
// plosives, which Whisper reads as well as -21 and without the flat tops.
static const float MIC_GAIN_DB = 36.0f;

bool Mic::begin() {
  ready_ = false;

  // GPIO42 is NOT the microphone's supply. Tested 2026-09-23: the ES8311
  // answers on I2C and records speech at the same level with this pin high
  // (N-001, rms -24 dBFS) and low (N-006, rms -26 dBFS). Waveshare's power
  // BSP calls it the audio power pin and drives it LOW for on, HIGH for off,
  // with a pull-up — so it gates the speaker side, and HIGH is the off state
  // we want until this device plays anything. The old README claim that the
  // mic was dead without it was never true.
  pinMode(PIN_AUDIO_PWR, OUTPUT);
  digitalWrite(PIN_AUDIO_PWR, HIGH);
  // Nothing plays through the speaker, and an enabled amplifier hisses.
  pinMode(PIN_PA, OUTPUT);
  digitalWrite(PIN_PA, LOW);
  delay(20);

  i2c_config_t ic     = {};
  ic.mode             = I2C_MODE_MASTER;
  ic.sda_io_num       = PIN_I2C_SDA;
  ic.scl_io_num       = PIN_I2C_SCL;
  ic.sda_pullup_en    = GPIO_PULLUP_ENABLE;
  ic.scl_pullup_en    = GPIO_PULLUP_ENABLE;
  ic.master.clk_speed = 400000;
  if (i2c_param_config(I2C_PORT, &ic) != ESP_OK ||
      i2c_driver_install(I2C_PORT, I2C_MODE_MASTER, 0, 0, 0) != ESP_OK) {
    Serial.println("[mic] I2C install failed");
    return false;
  }

  // Master, both directions: the codec is a slave and takes every clock from
  // us, and the vendored driver expects TX to exist even though nothing is
  // ever written to it. MCLK = 256 x fs, which is what the ES8311 wants.
  i2s_config_t is         = {};
  is.mode                 = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX | I2S_MODE_TX);
  is.sample_rate          = MIC_SAMPLE_RATE;
  is.bits_per_sample      = I2S_BITS_PER_SAMPLE_16BIT;
  is.channel_format       = I2S_CHANNEL_FMT_RIGHT_LEFT;
  is.communication_format = I2S_COMM_FORMAT_STAND_I2S;
  is.intr_alloc_flags     = ESP_INTR_FLAG_LEVEL1;
  is.dma_buf_count        = 8;
  is.dma_buf_len          = 256;   // frames; 8 x 256 = 128 ms of slack
  is.use_apll             = false;
  is.tx_desc_auto_clear   = true;
  is.fixed_mclk           = 0;
  is.mclk_multiple        = I2S_MCLK_MULTIPLE_256;
  is.bits_per_chan        = I2S_BITS_PER_CHAN_16BIT;
  if (i2s_driver_install(I2S_PORT, &is, 0, NULL) != ESP_OK) {
    Serial.println("[mic] I2S install failed");
    return false;
  }
  i2s_pin_config_t pc = {};
  pc.mck_io_num       = PIN_I2S_MCLK;
  pc.bck_io_num       = PIN_I2S_BCLK;
  pc.ws_io_num        = PIN_I2S_WS;
  pc.data_out_num     = PIN_I2S_DOUT;
  pc.data_in_num      = PIN_I2S_DIN;
  if (i2s_set_pin(I2S_PORT, &pc) != ESP_OK) {
    Serial.println("[mic] I2S pins failed");
    return false;
  }

  audio_codec_i2c_cfg_t i2cCfg = {};
  i2cCfg.port                  = I2C_PORT;
  i2cCfg.addr                  = ES8311_CODEC_DEFAULT_ADDR;
  const audio_codec_ctrl_if_t *ctrl = audio_codec_new_i2c_ctrl(&i2cCfg);
  const audio_codec_gpio_if_t *gpio = audio_codec_new_gpio();

  audio_codec_i2s_cfg_t i2sCfg = {};
  i2sCfg.port                  = I2S_PORT;
  const audio_codec_data_if_t *data = audio_codec_new_i2s_data(&i2sCfg);

  es8311_codec_cfg_t cc          = {};
  cc.ctrl_if                     = ctrl;
  cc.gpio_if                     = gpio;
  cc.codec_mode                  = ESP_CODEC_DEV_WORK_MODE_BOTH;
  cc.pa_pin                      = -1;   // we hold GPIO46 low ourselves
  cc.use_mclk                    = true;
  cc.master_mode                 = false;
  cc.no_dac_ref                  = true; // right channel empty, not DAC echo
  cc.hw_gain.pa_voltage          = 3.3f;
  cc.hw_gain.codec_dac_voltage   = 3.3f;
  cc.hw_gain.pa_gain             = 6.0f;
  const audio_codec_if_t *codec = (ctrl && gpio) ? es8311_codec_new(&cc) : nullptr;

  if (!ctrl || !gpio || !data || !codec) {
    Serial.println("[mic] ES8311 did not answer on I2C 0x18");
    return false;
  }

  esp_codec_dev_cfg_t dc = {};
  dc.dev_type            = ESP_CODEC_DEV_TYPE_IN_OUT;
  dc.codec_if            = codec;
  dc.data_if             = data;
  dev_                   = esp_codec_dev_new(&dc);
  if (!dev_) {
    Serial.println("[mic] codec device failed");
    return false;
  }
  ready_ = true;
  Serial.println("[mic] ES8311 up");
  return true;
}

bool Mic::open() {
  if (!ready_) return false;
  if (open_) return true;
  esp_codec_dev_sample_info_t fs = {};
  fs.sample_rate                 = MIC_SAMPLE_RATE;
  fs.channel                     = 2;
  fs.bits_per_sample             = 16;
  if (esp_codec_dev_open((esp_codec_dev_handle_t)dev_, &fs) != ESP_CODEC_DEV_OK) {
    Serial.println("[mic] open failed");
    return false;
  }
  // After open: the driver's open routine writes the codec's default gain,
  // so a gain set before it would be silently undone.
  esp_codec_dev_set_in_gain((esp_codec_dev_handle_t)dev_, MIC_GAIN_DB);
  esp_codec_dev_set_out_vol((esp_codec_dev_handle_t)dev_, 0);
  open_ = true;
  return true;
}

void Mic::powerOff() {
  close();
  digitalWrite(PIN_AUDIO_PWR, HIGH);  // Waveshare's OFF level; see begin()
  ready_ = false;
}

void Mic::close() {
  if (!open_) return;
  esp_codec_dev_close((esp_codec_dev_handle_t)dev_);
  open_ = false;
}

size_t Mic::read(int16_t *mono, size_t n) {
  if (!open_ || n == 0) return 0;
  if (stereoCap_ < n) {
    if (stereo_) heap_caps_free(stereo_);
    stereo_    = (int16_t *)heap_caps_malloc(n * 2 * sizeof(int16_t), MALLOC_CAP_8BIT);
    stereoCap_ = stereo_ ? n : 0;
    if (!stereo_) return 0;
  }
  if (esp_codec_dev_read((esp_codec_dev_handle_t)dev_, stereo_,
                         (int)(n * 2 * sizeof(int16_t))) != ESP_CODEC_DEV_OK) {
    return 0;
  }
  for (size_t i = 0; i < n; ++i) mono[i] = stereo_[2 * i];
  return n;
}

}  // namespace jota
