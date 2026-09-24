# CLAUDE.md — working context for this repo

Read this first on a fresh machine or a fresh session. It is the durable
context that chat history is not.

## What Jota is

A pocket voice-note device. Press a button, speak, and the transcript lands on
your phone. Built on a **Waveshare ESP32-S3-ePaper-1.54** board (200×200 1-bit
e-paper, onboard mic, ES8311 codec, microSD, PCF85063 RTC, ETA6098 PMIC,
SHTC3, LiPo charger) plus a 503035 LiPo, in a 3D-printed snap-fit case.

The board in hand is the **Touch variant** — silkscreen
`ESP32-S3-Touch-ePaper-1.54`, rev **V2**. Same product, same page, same stock
case, plus an FT6336 touch controller we do not use. Both variants ship from
<https://www.waveshare.com/esp32-s3-epaper-1.54.htm>. Worth knowing because the
touch layer may make the display stack thicker than the enclosure assumes.

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

- No WiFi credentials and no server anywhere. The OpenAI key lives on the
  PHONE, in its keychain, set in the app's Settings — never on the device
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
(analyses clean, 27 tests pass).

**Battery gauge: live since 2026-09-23.** `BATTERY_ADC_PIN` is GPIO4 with a
2:1 divider, from two sources: the board's own back label (`ADC GP4`) and
Waveshare's 01_ADC_Test, which reads ADC1 channel 3 and doubles the calibrated
millivolts. First readings on USB: 4052 mV → 85%, 4106 mV → 90%. The e-paper
gauge, the advertisement byte, `status.battery` and the app's device card all
carry the figure now. It was `-1` for a month on the claim that "the verified
pin map has no battery-sense pin"; the pin map was incomplete, not the board.

**Standby.** Two minutes idle on READY, with no recording and no phone
connected, and the device deep-sleeps behind its OFF frame (dotted ring, the
charge as a solid arc). Either button wakes it via `ext1`; if BOOT is the
button still held at boot, the recording starts before the panel has redrawn
(Pala Note does the same). A button held at boot is swallowed by the button
HAL so the wake press cannot also stop the note. The latch on GPIO17 is
`gpio_hold`-ed through sleep — verified on battery 2026-09-23: unplugged,
slept, woke on BOOT, recorded, synced. PWR long is still a true power-off.

Header pinout from the same drawing: `RXD`/`TXD`, `SDA`=GP20, `SCL`=GP19,
`GND`, `GP5`, `3V3`, `GP2`, `VSYS`, `GP1`.

Tags are armed on the device (TAGS → select) and spent by the next recording,
travelling to the phone as a string in `index`. Selecting the armed tag again
disarms it.

**Real since 2026-09-23:** the microphone and the SD card. Recording writes
`NNNN.wav` (raw archive) and `NNNN.ima` (ADPCM copy) under `/sdcard/jota` on
a background task; the note store indexes them on the card and serves the
`.ima` to the phone. The codec is driven by Espressif's Apache-licensed
`esp_codec_dev`, vendored in `jota/firmware/src/vendor` — the same component
Pala and Waveshare use; their `codec_board` wrapper is not used because it
needs IDF 5. The synthetic notes are gone. The card must be FAT32: this
core's FAT driver has exFAT off, and a card over 32 GB ships exFAT.

**Firmware 2026-09-24:** boots print a `[diag]` line (git rev, reset
reason, boot/crash counters in NVS); `diag` (…09, read) and `erase` (…0a,
write, echoes the device id) joined the BLE contract — Settings' Erase
device is real now, erase-over-BLE untested on hardware. Asleep, the chip
timer-wakes every 30 min (verified 15:58 2026-09-24): battery read, OFF
frame redrawn (arc now ENDS at 12 o'clock, gap grows clockwise), one
`tick` line in `/sdcard/jota/battery.log`, no BLE. PAIR screen sleeps
after 10 min; READY keeps 2. The `!` serial reboot hook is gone — it made
every serial attach a power cut. App-side: an advertisement is a Jota
only with the FFFF marker and plausible fields (a neighbour's gadget once
appeared as "JOTA-01C9").

**Power cut mid-note is survivable, verified 2026-09-23.** The recorder
fsyncs the WAV every ~4 s; at boot the note store rebuilds any un-indexed
`NNNN.wav` (header patched, `.ima` re-encoded) and indexes it as pending.
Test: `!` on serial calls `esp_restart()` with no files closed. Six seconds
into N-010 the reset gave back a 4 s note on the next boot. The card also
carries `battery.log` (time, uptime, event, mV, %) for the soak; the phone's
clock write now sets the system clock, so notes are stamped as they are made.

**The app's BLE path met real hardware on 2026-09-23:** pairing, clock,
index, fetch, tags and forget all ran phone-to-Jota, foreground only.
**Still never tested for real: background sync** (app closed, device
advertising with pending notes, OS wakes the app).

The pairing code is **six random digits from the hardware RNG**, minted when a
pairing offer opens and dropped when it closes — it is never persisted and
never appears in source. It is only live while the device is showing its PAIR
screen (a two-minute window). It was a fixed `428 913` compiled into every
unit, which is not a secret: anyone who had seen one Jota could pair with any
other without holding it.

**Forgetting works on both sides.** The app writes `{"app":…,"forget":true}` to
`auth`, honoured only for the current owner, and Jota clears the bond. The app
requires the device in range to forget, with an explicit "remove anyway" that
warns the Jota keeps trusting that phone until it is erased on the device. This
matters because the app's uuid never changes: a forget that cleared only the
phone's record let the next connection authenticate silently, so unpairing in
order to hand the device on changed nothing.

**Identity and the bond.** Each Jota derives a device id from its efuse MAC and
shows the last four characters (`91C4`) on its splash and PAIR screens; the app
shows the same as `JOTA-91C4`, and the id also rides in the advertisement so two
devices can be told apart *without connecting*. Each app install mints a uuid
once and presents it on every connection; the first phone to give a correct code
becomes the device's stored **owner** and reconnects silently forever after.
Another phone is refused unless it enters the code currently on the e-paper,
which transfers ownership — possession of the device deliberately outranks the
stored bond.

Beware the shape of the auth bug this replaced: `status` is readable
unauthenticated *on purpose*, so "the read succeeded" proves nothing. Read
`status.authed`. The old code inferred the bond from a successful read, never
sent a code, and every sync then read an empty `index` and said "all caught up"
while notes sat on the device.

## Hardware facts worth not rediscovering

- **The board has no RESET button.** Download mode = hold PWR to power off,
  hold BOOT (star), press PWR while holding, release. Without this the port
  never appears and PlatformIO falls back to `/dev/ttyS0`, which is a legacy
  port that does not exist.
- The USB-C port is the ESP32-S3's **native** USB, so `/dev/ttyACM*` only
  exists while firmware brings up USB CDC or the ROM bootloader runs. A sketch
  that crashes before `setup()` makes the port vanish.
- **GPIO17 must be HIGH at boot** or the board powers itself off on battery.
  **GPIO6 LOW** powers the panel. **GPIO42 is NOT the mic's supply**: the
  ES8311 answers and records at the same level with it high or low (tested
  2026-09-23). Waveshare's BSP drives it LOW for "audio on", HIGH for off, so
  it gates the speaker side; we hold it HIGH until the device plays sound.
- Pin map is verified against `waveshareteam/ESP32-S3-ePaper-1.54`, not guessed.
  It is tabulated in `jota/firmware/README.md`. It is **not complete**: it
  missed the `ADC GP4` battery sense that Waveshare prints on the board's own
  back label.
- **The stock 2×6 female header must be desoldered before the board will fit
  any case of ours.** It stands 8.5 mm off the PCB back and the interior floor
  is 7.5 mm below it, so the board cannot seat. This is not a preference: the
  first real print was assembled with it fitted, the board sat on the rim, and
  the case was blamed. `validate.py` now proves it — set
  `HEADER_FITTED = True` in `params.py` and the build fails with the overlap
  in mm. Waveshare's own case dodges this by slotting the back so the header
  pokes out; we will not, because it is a pocket device.
- The board **does** have four mounting holes and the stock case screws into
  them — Waveshare dimensions the screw pitch at **28.10 mm**. An earlier
  comment in `params.py` claiming otherwise has been corrected. We still clamp
  rather than screw, only because the hole positions relative to the PCB
  outline are unpublished and unmeasured.
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
- `jota/docs/market-research/` — what else exists (Aug 2026) and where Jota
  differs; includes a STT bake-off finding that questions the Google choice
