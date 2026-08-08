# note — firmware

Firmware for the **Waveshare ESP32-S3 1.54" e-Paper AIoT board** (the board this
enclosure is built around). C++ / Arduino framework, built with **PlatformIO**.

- **Panel:** 1.54" 200×200 mono B/W, SSD1681 controller
- **Display library:** [GxEPD2](https://github.com/ZinggJM/GxEPD2) (`GxEPD2_154_D67`)

## One-time setup

1. Install **VS Code**, then the **PlatformIO IDE** extension.
2. `File → Open Folder…` → open this `firmware/` folder.
3. PlatformIO auto-installs the ESP32 toolchain + GxEPD2 on first build.

## Build / flash / monitor

Use the PlatformIO toolbar at the bottom of VS Code:

| Button | Action |
|--------|--------|
| ✓ | **Build** |
| → | **Upload** (flash over USB-C) |
| 🔌 | **Serial Monitor** (115200 baud) |

If upload can't find the port: hold **BOOT**, tap **RESET**, release **BOOT** to
force download mode, then Upload again.

## Pin map (already wired in `src/main.cpp`)

| Function | GPIO | | Function | GPIO |
|---|---|---|---|---|
| EPD SCK  | 12 | | EPD BUSY | 8 |
| EPD MOSI | 13 | | EPD panel power | 6 (LOW = on) |
| EPD CS   | 11 | | **Power latch** | **17 (HIGH = stay on)** |
| EPD DC   | 10 | | Note button | 1 (to GND) |
| EPD RST  | 9  | | Battery ADC | 4 |

> ⚠️ **Two pins make or break it:** GPIO17 must be driven **HIGH** at boot or the
> board powers itself off on battery, and GPIO6 must be **LOW** to power the panel.
> Both are handled in `setup()`.

## Wiring the button

Connect a momentary push button between **GPIO1 and GND**. The firmware uses the
internal pull-up, so no resistor is needed. (The onboard side button is the power
button on GPIO18 — don't use it for notes.)

## What the starter does

- Latches power, powers + inits the panel, draws a title screen.
- Each button press increments a counter using **partial refresh** (fast, no
  full-screen flash) — the skeleton for "append a note."

## Roadmap

1. Replace the counter with a real note list (store in RTC RAM or the TF card).
2. Add WiFi (`WiFi.h` + `HTTPClient`) to POST notes to your cloud endpoint.
3. Deep-sleep between presses for long battery life (wake on the button pin).
