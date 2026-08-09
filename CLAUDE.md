# CLAUDE.md — working context for this repo

Read this first on a fresh machine or a fresh session. It is the durable
context that chat history is not.

## What Jota is

A pocket voice-note device. Press a button, speak, and the transcript lands on
your phone. Built on a **Waveshare ESP32-S3-ePaper-1.54** board (200×200 1-bit
e-paper, onboard mic, ES8311 codec, microSD, RTC, LiPo charger) plus a 503035
LiPo, in a 3D-printed snap-fit case.

Inspired by [Pala Note](https://www.youtube.com/watch?v=3t0k7E7WiOQ). That
project's repo has **no LICENSE file** (= all rights reserved), so it is used
only as a behavioural/visual reference. Code here is built on Waveshare's
official vendor examples and our own work. Nothing is copied.

## Three parts

| Path | What | Toolchain |
|---|---|---|
| `jota/` (`src/`, `models/`, `renders/`) | enclosure — parametric CAD | Python + build123d, shared `.venv` at repo root |
| `jota/firmware/` | device — e-paper UI, BLE link | PlatformIO / Arduino-ESP32 |
| `jota/app/` | phone — Flutter companion | Flutter (at `~/dev/flutter/bin`, **not on PATH**) |

## The architecture decision that shapes everything

**Jota has no WiFi.** It records, compresses to IMA ADPCM, and hands notes to
the phone over BLE. **The phone does the transcription** using its own
internet (OpenAI Whisper).

Consequences, all deliberate:

- No WiFi credentials, no API key, and no server anywhere
- The device cannot learn the time by itself — **the phone sets the clock over BLE**
- BLE is too slow for raw audio (1.9 MB/min), hence ADPCM at 4:1 → ~480 KB/min,
  ~16 s of transfer per minute of speech
- The **raw WAV stays on the SD card** as the archive; only the compressed copy
  is ever transmitted, so compression never touches the master

The BLE contract is **`jota/firmware/docs/ble-service.md`**. It is the single
source of truth for both sides — the firmware implements it, the app is written
against it. Change it deliberately and update both.

## Build and run

```bash
# CAD (from repo root)
python3 -m venv .venv && pip install -r requirements.txt
.venv/bin/python jota/src/validate.py     # must pass before exporting
.venv/bin/python jota/src/export.py       # -> models/stl, models/step, .3mf
.venv/bin/python jota/src/render.py       # -> renders/*.png

# Firmware
cd jota/firmware && pio run                       # build
pio run --target upload --upload-port /dev/ttyACM0
tools/ui_preview/build.sh                 # render every screen to PNG, no flashing

# App
export PATH="$PATH:$HOME/dev/flutter/bin"
cd jota/app
flutter run -d chrome -t lib/main_preview.dart    # UI preview, fakes, no BLE
flutter test && flutter analyze
```

## Current state — what is real, what is not

**Real:** the enclosure (validated, exported); the firmware UI, navigation,
button HAL and e-paper refresh policy; the ADPCM encoder; the note store with
byte-range serving, CRC and resume; the whole BLE service; the Flutter app
(analyses clean, 7 tests pass).

**Simulated:** the microphone. `jota/firmware/src/app/notes.cpp` synthesises
three short notes in flash so the app can be built end to end with no SD card
and no mic. Recording and syncing on the device UI are also simulated.

**Never run against real hardware:** the app's BLE path. It has only ever
talked to fakes.

The pairing code is the fixed `428 913`.

## Hardware facts worth not rediscovering

- **The board has no RESET button.** Download mode = hold PWR to power off,
  hold BOOT (star), press PWR while holding, release. Without this the port
  never appears and PlatformIO falls back to `/dev/ttyS0`, which is a legacy
  port that does not exist.
- The USB-C port is the ESP32-S3's **native** USB, so `/dev/ttyACM*` only
  exists while firmware brings up USB CDC or the ROM bootloader runs. A sketch
  that crashes before `setup()` makes the port vanish.
- **GPIO17 must be HIGH at boot** or the board powers itself off on battery.
  **GPIO6 LOW** powers the panel. **GPIO42** powers the audio rail — the mic is
  dead without it.
- Pin map is verified against `waveshareteam/ESP32-S3-ePaper-1.54`, not guessed.
  It is tabulated in `jota/firmware/README.md`.
- ESP32-S3 is **BLE only** — no Bluetooth Classic. NimBLE, not Bluedroid.

## Conventions

**Design language** (device and app share it, `theme.h` ↔ `theme.dart`):
monospace for every figure and identifier, sans only for prose; figures
zero-padded (`N-012`, `00:47`, `004/005`); stadiums and circles as the only
shapes; selection shown by inversion; one status line and one hairline as the
whole chrome. Fonts are named by role (`label/reading/figure/display/prose`),
never by size — naming them by metric is what let the same datum render at two
different sizes on adjacent screens.

**CAD:** every dimension is a named constant in `jota/src/params.py`.
`validate.py` must pass before `export.py`. Unverified numbers are marked
`# GUESS:` and listed in the enclosure README.

**Commits:** explain *why*, not just what. Where a change fixes a defect,
state the defect and the evidence.

## Known risks

- **`SWITCH_TIP_X = 17.05` is still a guess** and now drives both the button
  travel and the PCB's +X datum. Measure it before printing a final case.
- `validate.py` has no minimum-feature-width check and no overhang check. Three
  real defects got past it (flat 90° overhangs at the PCB seat, an 86%-blocked
  speaker grille, and 0.1 mm skirt slivers that a slicer flagged as floating
  regions). Adding those two checks is the highest-value outstanding work on
  the CAD side.
- The snap cantilevers bend **normal to the layer planes**, the weak direction.
  Strain is 1.11% after redesign; PETG is required, not merely recommended.
- Background BLE sync is heavily restricted by both phone OSes. A 10-minute
  timer does not work — the device advertises and the OS wakes the app. See
  the app README.

## History

- `jota/docs/plan-phase1-ui.md` — the approved phase-1 plan (design-first)
- `jota/docs/decisions.md` — the architecture forks and why they went that way
- `jota/docs/claude_code_prompt.md` — the original enclosure brief
