# Jota — firmware

Firmware for the **Waveshare ESP32-S3-ePaper-1.54** board. C++ / Arduino,
built with **PlatformIO**.

Jota records voice notes and hands them to a phone over **BLE**. It has no
WiFi: the phone does the transcription using its own internet, so the device
holds no credentials, no API key, and there is no server anywhere.

- **Panel:** 1.54" 200×200 mono B/W, SSD1681
- **Display library:** [GxEPD2](https://github.com/ZinggJM/GxEPD2) (`GxEPD2_154_D67`)
- **BLE:** NimBLE — the S3 is BLE-only (no Bluetooth Classic), and NimBLE is
  far smaller than Bluedroid

## Build / flash / monitor

Open this folder in VS Code with the **PlatformIO IDE** extension, then use the
toolbar: Build (✓), Upload (→), Serial Monitor (🔌, 115200).

### Getting into download mode

**This board has no RESET button** — only **PWR** and **BOOT** (the
star-marked side button). The usual "hold BOOT, tap RESET" does not apply.

1. Hold **PWR** until the board powers fully off.
2. Hold **BOOT** (star) and keep holding.
3. Still holding BOOT, press **PWR** to power on.
4. Release both.

It should then appear as `/dev/ttyACM*` (USB ID `303a:1001`). Because the
USB-C port is the ESP32-S3's **native** USB, the port only exists while
firmware brings up USB CDC or the ROM bootloader is running — a sketch that
crashes before `setup()` makes the port vanish entirely, and download mode is
the way back in.

## Controls

Two buttons, and the contract holds on every screen:

| | Short | Long (≥1.5 s) |
|---|---|---|
| **BOOT** (star) | select / confirm / start+stop recording | back |
| **PWR** | next item | power off |

Power-off releases the GPIO17 latch. Before it does, the panel is left showing
a deliberate resting frame — e-paper holds its last image forever, so this is
what the object looks like in a drawer.

## Layout

```
src/
├── main.cpp        power latch, init, loop, refresh policy
├── ui/theme.h      every layout token; one origin (CONTENT_MID)
├── ui/widgets      status bar, stadium rows, list, ring, progress, text
├── ui/screens      one pure draw per screen, over a view model
├── app/model.h     AppModel — all a screen is allowed to know
├── app/nav         screen state machine
├── app/notes       note store; serves audio by byte range
├── audio/adpcm     IMA ADPCM encoder (4:1) for the copy sent over BLE
├── hal/buttons     debounce, short/long press
└── link/ble        the GATT service in docs/ble-service.md
tools/ui_preview/   renders every screen to PNG on the host — no flashing
```

Screens are **pure draws**: they take a canvas and the model and paint. No SD,
no BLE, no `delay()`. That is what lets the same code render on the host
preview, and keeps features from tangling the layout.

### Host UI preview

E-paper full refresh is ~2 s and reflashing is slow, so layout is iterated on
the laptop:

```bash
tools/ui_preview/build.sh      # -> ../renders/ui/*.png + contact_sheet.png
```

Widgets take an `Adafruit_GFX&` rather than the panel object. `GxEPD2_BW`
derives from it and `GFXcanvas1` is an in-memory 1-bit canvas with the same
API, so what you review is what the panel draws — not a mockup.

## Design language

Quiet, technical, minimal. Monospace for everything structural so figures read
as measurements; sans only for transcripts, because mono fits ~15 characters
per line at 172 px and shreds prose. Figures are zero-padded (`N-012`,
`00:47`, `004/005`). Chrome is one status line and one hairline. Stadiums and
circles are the only shapes, and selection is shown by inversion.

The status strip's right slot always holds the screen's one defining figure.

## Pin map

Verified against Waveshare's official examples
(`waveshareteam/ESP32-S3-ePaper-1.54`), not guessed.

| Function | GPIO | | Function | GPIO |
|---|---|---|---|---|
| EPD SCK | 12 | | EPD BUSY | 8 |
| EPD MOSI | 13 | | EPD panel power | 6 (**LOW** = on) |
| EPD CS | 11 | | **Power latch** | **17 (HIGH = stay on)** |
| EPD DC | 10 | | BOOT button | 0 |
| EPD RST | 9 | | PWR button | 18 |
| Audio I2S MCLK | 14 | | Audio power | **42** |
| Audio I2S BCLK | 15 | | Codec ES8311 I2C | SDA 47 / SCL 48 |
| Audio I2S WS | 38 | | Speaker PA enable | 46 |
| Mic in (DIN) | 16 | | microSD (SDMMC 1-bit) | CLK 39 / CMD 41 / D0 40 |
| Speaker out (DOUT) | 45 | | RTC PCF85063 | I2C 47/48 |

> ⚠️ **Three pins make or break it.** GPIO17 must be **HIGH** at boot or the
> board powers itself off on battery. GPIO6 must be **LOW** to power the panel.
> GPIO42 must be driven before the microphone will do anything at all.

### Battery sense — one unresolved pin

The table above has **no battery-sense pin**, because Waveshare's examples do
not use one. The gauge is therefore built but switched off: `BATTERY_ADC_PIN`
in `src/hal/battery.h` is `-1`, and every surface — the e-paper, the
advertisement, `status`, the app — says the charge is *unknown* rather than
inventing a figure.

To turn it on, find the GPIO carrying the divided pack voltage (board
schematic or the Waveshare wiki) and set two constants:

```cpp
static const int   BATTERY_ADC_PIN = <gpio>;   // was -1
static const float BATTERY_DIVIDER = 2.0f;     // pack volts / pin volts
```

Nothing else changes: the ADC is read through `analogReadMilliVolts()` so the
per-chip eFuse calibration applies, samples are median-filtered and smoothed,
and sampling is skipped while the panel is refreshing (a refresh sags the pack
by enough to read as flat). Sanity check after wiring: a full pack should
report ~4.15–4.20 V, i.e. 100%; if it reports half of that, the divider ratio
is wrong, not the pin.

## What is real, and what is not

**Real:** the whole UI and navigation, the button HAL, the e-paper refresh
policy, the ADPCM encoder, the note store's byte-range serving and CRC
checking, and the complete BLE service — pairing, index, chunked transfer,
resume-from-offset, tags, clock.

**Not yet:** the microphone. `app/notes` serves three short notes synthesised
in flash, so the phone app can be built and tested end to end — connect, pair,
fetch, resume, ack — with no SD card and no mic. Swapping the source for the
recorder changes nothing the app can see.

The pairing code is currently the fixed `428 913`.

## Phone link

The BLE service is specified in **[docs/ble-service.md](docs/ble-service.md)** —
advertising format, all eight characteristics, payloads, and the end-to-end
sequence including resume after a dropped connection. That document is the
contract the app in [`../app/`](../app/) is written against.

The advertisement carries the pending-note count, so the phone can tell
whether anything is waiting **without connecting**; at zero the app never
wakes.

## Next

1. Microphone: ES8311 over I2C, I2S capture, ADPCM straight into the note store.
2. microSD: keep the raw WAV as the archive; only the compressed copy is sent.
3. Real pairing code per session, and an NVS first-run flag so `GUIDE` shows once.
4. Deep sleep between notes, waking on BOOT (`ext_wakeup` is already GPIO0).
