# Jota — phase 1: lock the on-device design system

## Context

The `note/` project has a finished, validated 3D-printed enclosure. The
firmware is still a button-counter demo.

The device is now named **Jota**. The goal is a pocket voice-note device in
the spirit of [Pala Note](https://www.youtube.com/watch?v=3t0k7E7WiOQ):
press, speak, get a transcript.

**This phase deliberately ships no audio.** Per the decision to *lock the
design first and build features on top*, phase 1 builds the complete UI
system and screen navigation with stub data. Every later feature (recording,
SD, WiFi, transcription) then drops into screens that already exist and are
already approved.

> **Licensing:** Pala Note's repo has no LICENSE file (= all rights
> reserved). Used only as a *visual/behavioural* reference. Code is built on
> Waveshare's official vendor examples and our own work — nothing copied.

## Design language (read from the reference screenshots)

- **1-bit only.** White ground, black ink. No greys, no dither.
- **Rounded corners everywhere** — buttons are rounded rects (r≈8), tags are
  full pills (r = h/2).
- **Selection = inversion.** Selected row is filled black with white text;
  unselected is a 1px outline with black text. This is the single
  interaction signal — no carets, no arrows.
- **Two title styles:** letterspaced caps (`SYNCING`, `CHOOSE TAG`) for modal
  screens; lowercase + horizontal rule (`menu`) for navigation.
- **Generous whitespace.** 12px margin, content never touches the edge.
- **Circle motif** for the idle/ready state — thin outline, small label and
  dot inside.

## Screen inventory

```
 SPLASH            READY             RECORDING         SAVED
┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│          │      │   ╭───╮  │      │   ╭───╮  │      │  saved   │
│  Jota    │      │  │jota │ │      │  │ ●   │ │      │          │
│          │      │  │  •  │ │      │  │0:07 │ │      │ note 12  │
│          │      │   ╰───╯  │      │   ╰───╯  │      │  0:07    │
│          │      │  ready   │      │ recording│      │          │
└──────────┘      └──────────┘      └──────────┘      └──────────┘

 MENU              CHOOSE TAG        SYNCING           NOTE VIEW
┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│ menu     │      │CHOOSE TAG│      │ SYNCING  │      │ note 12  │
│ ──────── │      │ ╭──────╮ │      │          │      │ 14:32    │
│ ╭──────╮ │      │ ╰──────╯ │      │  • • •   │      │ ──────── │
│ │Notes │ │      │ ╭──────╮ │      │          │      │ call the │
│ ╰──────╯ │      │ ▓Buy▓▓▓│ │      │ ▓▓▓▓▓░░░ │      │ dentist  │
│ ▓Tags▓▓▓ │      │ ╰──────╯ │      │   4 / 5  │      │          │
│ ╭──────╮ │      │ ╭──────╮ │      │          │      │          │
│ │Sync  │ │      │ │Private│ │     │          │      │          │
└──────────┘      └──────────┘      └──────────┘      └──────────┘
   ▓ = inverted (selected)
```

## Architecture

The key move: **widgets take `Adafruit_GFX&`, not the e-paper object.**
`GxEPD2_BW` already derives from `Adafruit_GFX`, and `GFXcanvas1` is a plain
in-memory 1-bit canvas with the same API. So the exact same screen code
renders on the device *and* on the laptop with no `#ifdef`s.

```
note/firmware/
├── src/
│   ├── main.cpp          power latch, init, loop, button dispatch
│   ├── ui/theme.h        layout constants + font choices (single source)
│   ├── ui/widgets.{h,cpp}  title, button, list, pill, progress, dots, circle
│   ├── ui/screens.{h,cpp}  one function per screen, pure draw, no I/O
│   ├── app/nav.{h,cpp}     screen state machine
│   ├── app/model.h         NoteMeta/Tag structs + a stub note store
│   └── hal/buttons.{h,cpp} debounce + short/long press
└── tools/ui_preview/     host build → PNGs (see below)
```

`screens.cpp` must stay **pure**: it takes a model struct and a canvas, and
draws. No SD, no WiFi, no `delay()`. That's what makes host preview possible
and keeps later features from tangling the UI.

## Host preview harness

E-paper full refresh is ~2 s and reflashing is slow — iterating on layout on
hardware would be painful. `tools/ui_preview/` compiles `widgets.cpp` +
`screens.cpp` with a ~60-line Arduino shim against a `GFXcanvas1(200,200)`
and writes every screen to `note/renders/ui/*.png`.

This mirrors the workflow the CAD side already uses (`export.py` → `renders/`),
so we can review and lock the whole design as a contact sheet before a single
flash. Same code path means what you approve is what the panel shows.

## Layout constants (`theme.h`)

| Constant | Value | Notes |
|---|---|---|
| `SCREEN` | 200×200 | square panel |
| `MARGIN` | 12 | content inset |
| `BTN_H` / `BTN_GAP` | 24 / 6 | menu rows |
| `BTN_R` | 8 | rounded-rect radius |
| `PILL_R` | `h/2` | tag pills |
| `RULE_Y` | 40 | under lowercase titles |
| `LIST_Y0` | 56 | first row top |

Menu arithmetic: 4 × 24 + 3 × 6 = **114 px**, from y=56 → 170. Fits with
30 px to spare. Tag list of 5 uses `BTN_H` 22 / gap 5 = **130 px** → fits.

## Buttons

Only two exist: **BOOT (GPIO0)** and **PWR (GPIO18)**. Because the power
latch (GPIO17) is held by firmware, PWR is fully software-interpreted.

| Button | Short | Long (≥1.5 s) |
|---|---|---|
| BOOT | select / confirm | back |
| PWR | next item | power off (release latch) |

## Refresh policy

- Full refresh on screen change, and every 8th partial, to clear ghosting.
- Partial refresh for the recording timer and sync progress bar only.
- `nav` owns this — screens never call refresh themselves.

## Build order

1. `theme.h` + `widgets.cpp` — button, pill, title, rule, progress, dots, circle.
2. `tools/ui_preview` + shim → render widget samples to PNG. **Review gate.**
3. `screens.cpp` — all 8 screens against stub model data → contact sheet.
   **This is the design lock.**
4. `hal/buttons` — debounce, short/long, on real hardware.
5. `app/nav` — wire the state machine, flash it, navigate the real device.
6. Rename `note/` → `jota/` and update paths/README (single commit, `git mv`).

Steps 1–3 need no hardware at all.

## Deferred to phase 2 (explicitly not now)

Audio capture (ES8311/I2S), microSD, RTC timestamps, WiFi, transcription
backend, playback. The hardware map for all of it is already extracted and
recorded below so phase 2 starts with no research.

| Subsystem | Pins | Source |
|---|---|---|
| e-paper | SCK 12, MOSI 13, CS 11, DC 10, RST 9, BUSY 8, PWR 6 | `user_config.h` |
| Audio I2S | MCLK 14, BCLK 15, WS 38, DIN 16 (mic), DOUT 45 (spk) | `board_cfg.h` |
| Codec ES8311 | I2C SDA 47, SCL 48; PA enable 46 | `board_cfg.h` |
| Audio power | **GPIO42** — required or mic is dead | `user_config.h` |
| microSD | SDMMC 1-bit: CLK 39, CMD 41, D0 40 | `04_SD_Card` |
| Power latch | GPIO17 HIGH = stay on | `user_config.h` |
| RTC PCF85063 | I2C 47/48 | `02_I2C_PCF85063` |

(from `waveshareteam/ESP32-S3-ePaper-1.54`, `02_Example/Arduino` — verified,
not guessed. A microSD card is still needed before phase 2.)

## Verification

- **Design lock:** `tools/ui_preview` renders all 8 screens to
  `note/renders/ui/`; review as a contact sheet and approve before step 4.
- **Build:** `pio run` clean at every step.
- **On hardware:** flash after step 5; walk every screen with the two side
  buttons and confirm each matches its PNG, that selection inversion reads
  clearly on the real panel, and that ghosting is gone after a full refresh.
- **Fit:** confirm text is legible through the lid's 28 mm window — the
  window crops to 27 mm active area, so nothing critical within 4 px of any
  edge.
