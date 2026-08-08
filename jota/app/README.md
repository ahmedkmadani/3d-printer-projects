# Jota — companion app

The phone half of Jota, a pocket voice-note device.

Jota records, compresses to IMA ADPCM, and holds notes on an SD card. It has no
WiFi and cannot reach the internet or contact the phone. This app scans for it,
pulls the audio over BLE, verifies it, transcribes it using the **phone's**
connection, and is the archive. There is no server and no backend anywhere in
this product.

The BLE contract this implements is [`../firmware/docs/ble-service.md`](../firmware/docs/ble-service.md).
The design language is inherited from [`../firmware/src/ui/theme.h`](../firmware/src/ui/theme.h).

---

## Running it

```bash
flutter pub get
flutter run                 # a real phone, real Jota
```

### Look-and-feel preview, no hardware required

```bash
flutter run -d chrome -t lib/main_preview.dart
```

Runs the **real screens** in a browser against a simulated device and an
in-memory archive. See [Preview mode](#preview-mode) for exactly what is and is
not real about it.

### Checks

```bash
flutter analyze                        # clean
flutter test                           # 7 tests
flutter test --platform chrome test/widget_test.dart   # the same screens, in a browser
flutter build web -t lib/main_preview.dart
```

---

## Layout

```
lib/
├── main.dart                 entry point: real BLE + sqflite
├── main_preview.dart         entry point: fakes, for the browser
├── app.dart                  the widget both entry points share
│
├── ble/                      everything about the link
│   ├── jota_protocol.dart      THE CONTRACT: UUIDs, payloads, advertisement parsing
│   ├── jota_link.dart          one connected session; the 8 characteristics as methods
│   ├── sync_service.dart       interface + SyncProgress/SyncResult
│   ├── sync_engine.dart        the real one: fetch/data/verify/ack, with resume
│   ├── device_scanner.dart     interface + AdapterStatus
│   ├── jota_scanner.dart       the real one, over flutter_blue_plus
│   ├── background_sync.dart    interface + BackgroundMode + the honest explanations
│   └── foreground_background_sync.dart   Android foreground service
│
├── audio/
│   ├── adpcm.dart              IMA ADPCM decoder — inverse of the firmware's encoder
│   ├── wav.dart                RIFF/WAVE writer, 16-bit PCM
│   ├── crc32.dart              IEEE CRC-32, streamed
│   ├── note_player.dart        playback interface
│   └── decoded_note_player.dart  the real one, over just_audio
│
├── data/                     interface + implementation, one pair per concern
│   ├── note.dart               the model
│   ├── note_repository.dart  ·  sqflite_note_repository.dart
│   ├── audio_store.dart      ·  file_audio_store.dart
│   ├── partial_store.dart    ·  file_partial_store.dart
│   ├── settings_store.dart   ·  prefs_settings_store.dart
│   └── database.dart           schema
│
├── design/
│   ├── theme.dart              ALL tokens. The sibling of the firmware's theme.h
│   ├── widgets.dart            rule, statusBar, row, list, ring, progressBar, dots
│   └── format.dart             every figure the user sees, zero-padded
│
├── screens/                  note list, detail, sync, pair, tag editor, settings
├── state/                    Services container + two ChangeNotifiers
├── transcribe/
│   ├── transcriber.dart        the interface
│   ├── whisper_transcriber.dart  OpenAI
│   └── transcription_queue.dart  serial, resumable
└── preview/                  fakes for the browser preview (see below)
```

Every dependency in `Services` is an **interface**. That is what lets `main.dart`
assemble BLE + sqflite + Keychain while `main_preview.dart` assembles fakes and
runs the identical screens.

---

## Package choices

| Package | Why |
|---|---|
| `flutter_blue_plus` | The only BLE package with maintained background support on both platforms and a stream API that does not reorder notifications. Exposes `setOptions(restoreState:)`, which iOS state restoration requires. |
| `sqflite` | See below. |
| `path_provider`, `path` | Archive and partial-transfer files. |
| `flutter_secure_storage` | The OpenAI key. Keychain / EncryptedSharedPreferences. Nothing else goes here. |
| `shared_preferences` | Non-secrets: paired device id, toggles, model name. |
| `http` | One kind of request (multipart upload). `dio` would also work and is heavier. |
| `just_audio` | Plays a decoded WAV from a file path on both platforms. |
| `flutter_foreground_task` | The Android foreground service. Nothing equivalent exists or is needed on iOS. |
| `provider` | Two ChangeNotifiers and a container. A code-generating DI framework would be more machinery than graph. |
| `intl` | Locale-aware date formatting. |

Versions are **pinned exactly**, not caret-ranged. This app talks to physical
hardware over a hand-written binary protocol; a silent minor bump in
`flutter_blue_plus` is exactly the kind of thing that becomes "sync stopped
working" three months later. Bump deliberately, re-test against hardware.

### sqflite, not drift

- The schema is two tables and about a dozen columns. Drift's real value is
  compile-checked queries and typed joins; there are no joins here.
- Drift needs `build_runner`: a codegen step in CI, `.g.dart` files in review
  diffs, and a generator version that has to agree with the SDK. Poor trade for
  two tables.
- **The audio never goes in the database.** A row holds a path; the bytes are a
  file. That removes the one thing sqflite is genuinely awkward about (large
  BLOBs) and leaves it doing what it is good at.

If this ever grows joins or a second writer, drift is the right move — and
`NoteRepository` being an interface is what makes that swap cheap.

---

## The BLE flow

Service `4a6f7461-1e5f-4b2a-9c33-000000000000`, eight characteristics, all of
them in `lib/ble/jota_protocol.dart` and nowhere else.

### Before connecting

Jota advertises as `JOTA` with 4 bytes of manufacturer data: `FF FF <pending>
<flags>`. `FF FF` is the "no company assigned" identifier — a manufacturer-data
record is required to start with one, and Jota has no Bluetooth SIG ID.

So **the phone learns how many notes are waiting without connecting**. If that
count is zero it never opens a link, and neither side spends battery. This is the
single most important thing in the protocol.

### One sync run

```
connect + request MTU 247      throughput scales almost linearly with MTU
read status                    if it answers, we are bonded already
  └─ if it does not:  write auth   the 6 digits on the e-paper
write clock                    Unix seconds, EVERY connect — the device has no
                               other time source, so this is what makes its
                               timestamps real rather than counted from boot
read index                     [{"id":12,"secs":47,"bytes":389120,"crc":…}]
subscribe data                 BEFORE any fetch, or the first chunks are lost
for each note:
    write fetch {"id":12,"offset":M}
    accumulate data chunks     in arrival order; boundaries mean nothing
    CRC32 the whole note
    ├─ match     → move to archive → insert row → write ack
    └─ mismatch  → discard, do NOT ack, let the device offer it again
```

### Resume

A dropped link costs the bytes still outstanding and nothing else. There is no
retry button because there is nothing for a user to do.

- Partial bytes live in a **file per (device, note)**, so they survive the app
  being killed mid-transfer — which on iOS is the normal way a background sync
  ends.
- The resume offset is **rounded down to a whole 256-byte ADPCM block**. Every
  block carries the predictor and step index it needs in its own header, so a
  block boundary is the only offset a decoder can start from cold, and it is what
  the firmware seeks to. Discarding ≤255 bytes (~31 ms, re-received anyway) buys
  the guarantee that a resumed note decodes identically to an unbroken one.
  (The contract's own example, `offset: 180224`, is 704 whole blocks.)
- **Nothing is ever acked without a verified CRC32 over the complete note.** An
  ack tells the device to forget the recording; the phone's copy becomes the only
  copy at that instant.
- The note is moved into the archive **before** the ack is written. If the process
  dies between the two, the device re-offers the note, the app finds it already
  stored with a matching CRC, and re-acks it without moving a byte. The other
  order would lose the note.
- A `status` notify of `{"error":"range"}` means our offset was invalid for that
  file — the partial is discarded and the note starts over.

### Audio

The archive copy is the **ADPCM exactly as it came off the wire** — that is what
the CRC covers, and it is 4× smaller than PCM. The device deletes its copy after
the ack, so this is the only copy.

Playback and Whisper both need a container, so the ADPCM is decoded to 16-bit PCM
WAV (16 kHz mono) and cached. That cache is disposable and rebuilds on demand;
clearing it is a button in Settings.

`lib/audio/adpcm.dart` is the exact inverse of the firmware's encoder, and
`test/adpcm_matches_firmware_test.dart` proves it against vectors generated by
compiling the real C++ encoder on the host.

---

## Background sync, honestly

Jota is a peripheral. It cannot contact the phone. All it can do is advertise, and
the phone has to notice. What "noticing" costs is completely different per
platform, and the app says so in Settings rather than only here.

**Android — a foreground service.** A persistent, silent, low-importance
notification is the price of a process that does not get frozen. The service keeps
the process alive; the scan and the sync run in the normal isolate with the normal
database. The task handler does not do BLE work — running it in its own isolate
would mean a second `FlutterBluePlus`, a second sqflite handle and a second copy
of every store, for no gain. On Android 13+ a denied notification permission means
no foreground service, and the UI reports `DENIED` instead of pretending.

**iOS — `bluetooth-central` plus state restoration, and no timers.**
There is no foreground service and no way to buy one. What does work:

- a scan that names an **explicit service UUID** keeps being delivered to a
  backgrounded app (an unfiltered scan returns nothing) — `JotaScanner` always
  filters;
- the system may terminate the app and later relaunch it in the background when
  that service is seen, provided the app opted into state restoration **before any
  other CoreBluetooth call** — `Services.boot()` does this first;
- an `autoConnect` request survives into the background and completes when the
  device appears.

Delivery is on the system's schedule. It can be minutes.

**What does not work, on either platform, and is deliberately not implemented:**
a periodic timer that wakes every N minutes and scans. iOS suspends timers the
moment the app backgrounds; Android's Doze does the same outside a maintenance
window. A "sync every 10 minutes" toggle would be a lie in the settings screen.

---

## Design

The app must feel like the same product as the device without being a 1-bit e-ink
imitation. What carries across is the *rules*, not the pixel values. All of them
live in `lib/design/theme.dart`, which mirrors the structure of the firmware's
`theme.h`.

**Type roles, named by job — the firmware's five, unchanged.**

| Role | Used for | Face |
|---|---|---|
| `label` | status label, row labels, buttons | mono bold |
| `reading` | status value, metadata | mono regular |
| `figure` | the one live number on a screen | mono bold, large |
| `display` | pair codes, terminal confirmations | mono bold, largest |
| `prose` | transcripts **only** | sans |
| `wordmark` | JOTA — an asset, not a style | mono bold |

**Monospace for every figure and identifier.** Note ids (`N-012`), durations
(`00:47`), counts (`012`), ratios (`004/005`), byte sizes, CRCs — all mono, all
zero-padded, all produced by `lib/design/format.dart` so the string on the panel
and the string in the app are made the same way. This is the strongest single
signal that the two halves are one product.

**Sans for prose only.** At transcript width a monospace face fits about fifteen
characters per line, which shreds a paragraph. Same split the device makes, same
reason.

**One status line, one hairline, one idea.** `JotaScreen` gives every screen a
label, a right slot, and a rule. No bottom nav, no tab strip, no FAB.

**STATUS RIGHT SLOT RULE**, inherited verbatim from `screens.cpp`: the right slot
always holds the screen's one defining figure — a count on the note list, a ratio
while syncing, a position within a note. Never two things.

**Selection by inversion.** A selected row is filled with ink and its label is
knocked out — never a tint, a border weight, or a checkmark. `JotaRow` is the one
list component and radius is always height/2, so **every** control is a stadium.

**Near-monochrome.** Six colours, five of which are greys. There is exactly one
accent and it appears in exactly two places: the pending-notes dot, and error
text. Never for emphasis, never for a chip, never on a button.

**No shadows, no gradients.** `shadowColor` is transparent theme-wide. The device
is a flat panel; a drop shadow is the fastest way to look like a different app.

**Full dark mode**, following the system.

Widget primitives in `lib/design/widgets.dart` carry the firmware's names, so a
screen written against one reads like a screen written against the other: `rule`,
`statusBar`, `bigFigure`, `row`, `list`, `ring`, `progressBar`, `dots`. The ring's
outer edge never moves between idle and active — only the annulus thickens inward,
exactly as `theme.h` specifies.

---

## Preview mode

```bash
flutter run -d chrome -t lib/main_preview.dart
```

**What it is for.** Judging the look and feel — layout, type, spacing, dark mode,
the flow between screens — with no Android SDK, no phone, and no hardware.

**What is real.** Everything from `Services` downward: the actual screen classes
in `lib/screens/`, the actual controllers, the actual design tokens, the actual
ADPCM decoder and WAV writer. If the preview's layout is wrong, the app's layout
is wrong.

**What is faked** (`lib/preview/`):

| Faked | Instead of |
|---|---|
| `InMemoryNoteRepository` | sqflite |
| `InMemoryAudioStore`, `InMemoryPartialStore` | files on disk |
| `InMemorySettingsStore` | Keychain / SharedPreferences |
| `FakeScanner` | a BLE scan — advertises on a 3 s timer |
| `FakeSyncService` | the real engine — walks the same phases on delays and emits the same `SyncProgress` |
| `FakeTranscriber` | OpenAI — answers from a script after 1.2 s |
| `FakeNotePlayer` | just_audio — **silent**, advances a position at 1× |
| `FakeBackgroundSync` | the foreground service — always reports the Android answer |

**What the preview does NOT test.** All of BLE: GATT, MTU negotiation, chunk
reassembly, CRC over bytes that came off a wire, resume-after-disconnect, pairing
against real firmware. All of storage: SQL, migrations, file handling, secure
storage. Real audio: nothing makes a sound, and the seeded audio is deterministic
pseudo-random bytes of the correct *length*, not speech. Background sync and every
platform permission. In short: it proves nothing about correctness and everything
about appearance.

**Seeded state.** Eight notes covering every state the list and detail screens can
be in — transcribed long and short, still queued, finished with no speech in it,
failed for want of an API key, tagged and untagged, today through last week. Four
tags in use. The simulated device holds three more notes so a sync has something
to pull.

It starts **unpaired and with no API key**, because those two empty states are
what a new user sees first, and the pair flow is one of the things worth looking
at. To walk it: **SYNC → tap JOTA → enter the pair code**. On real hardware that
code is on the e-paper; here it is on the strip along the bottom of the window
(`428 913`). Adding any non-empty API key in Settings switches the simulated
Whisper on, and the queue drains for real.

Reloading the page resets everything to the seed.

The same fakes back `test/widget_test.dart`, so `flutter test` exercises the
preview graph on every run and a fake that drifts out of step with an interface
fails there rather than in a browser tab nobody opened.

---

## Status

`flutter analyze` is clean, `flutter test` passes (including the cross-language
ADPCM check against the firmware's encoder), the widget tests pass in a real
browser via `flutter test --platform chrome`, and both web targets build.

Everything in the BLE contract is implemented. What remains before it talks to
real hardware:

- Run it on a physical Android/iOS device against a physical Jota — none of the
  BLE code has touched a radio yet.
- Confirm the manufacturer-data parse against the real advertisement. The parser
  accepts both the `FF FF`-prefixed form and a pre-stripped one, but only hardware
  says which arrives.
- Confirm the `auth` failure mode. A wrong code surfaces as a write error or an
  immediate disconnect rather than a typed response, so the app treats both as an
  auth failure — worth checking against the firmware's actual behaviour, since
  three wrong codes cost a 30-second advertising blackout.
- iOS state restoration needs a real relaunch-from-terminated test; it cannot be
  verified in a simulator.
- Bundle a monospace font. The app currently falls back to the platform's
  (Roboto Mono / SF Mono), which is good but means Android and iOS do not look
  identical. `pubspec.yaml` has the asset block ready and commented out;
  `JotaFonts.mono` is the single constant to flip.
