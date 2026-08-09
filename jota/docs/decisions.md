# Decisions

The forks that shaped Jota, and why they went the way they did. Recorded
because the reasoning is the part that does not survive in a diff.

---

## 1. The phone does the transcription, not the device

**Considered:** Jota joins WiFi and uploads audio to Whisper itself.

**Chosen:** Jota is BLE-only. The phone pulls the audio and transcribes it with
its own internet.

**Why:** the phone is always nearby, and it removes an entire category of
problems — no WiFi provisioning, no credentials or API key on a device that can
be lost, and no server to run or pay for.

**Cost:** BLE is slow for audio, so notes only sync when the phone is in range.
Mitigated by compressing (see below).

Killed the `WIFI` screen; `SYNC` now means "hand notes to my phone".

---

## 2. ADPCM for the copy in flight, raw WAV for the archive

**Why:** raw audio is ~1.9 MB/min, about a minute of BLE transfer per minute of
speech. IMA ADPCM at 4:1 gives ~480 KB/min and ~16 s. Opus would be four times
better again but is a much heavier lift on the chip.

ADPCM is lossy, but the loss is inaudible for speech and irrelevant to Whisper,
which was trained on far worse. **The raw WAV stays on the SD card**, so the
archive is never compressed — only the copy in flight.

Later: Opus is a drop-in upgrade that changes nothing else.

---

## 3. A custom BLE service, not Espressif's provisioning protocol

**Considered:** Espressif's provisioning protocol, which has official Android
and iOS SDKs.

**Chosen:** a custom GATT service (`ble-service.md`), talked to with
`flutter_blue_plus`.

**Why:** Espressif publish no Flutter SDK — only community wrappers around the
native ones. Their protocol also needs protobuf plus an X25519/AES handshake,
and covers *only* WiFi setup. Notes, tags and the clock would have needed a
custom service anyway.

**Cost:** we cannot test with Espressif's ready-made app, and security is ours
to get right — handled by a pairing code shown on the panel.

---

## 4. The pairing code lives on the e-paper

Possession of the device is the whole security model: without the code on the
screen, anyone in BLE range could pair. An always-on display is a far better
place for that than a blinking LED — the screen earns its keep.

---

## 5. Resume is in the protocol, not bolted on

`fetch` takes a byte offset and `ack` carries a CRC. A note is only retired on
a **valid** ack, so an interrupted transfer stays pending, keeps being
advertised, and resumes from where it stopped. A truncated transfer can never
be mistaken for a complete one.

The block-based ADPCM framing exists for the same reason: every block carries
the predictor in its header, so any block decodes cold and seeking is trivial.

---

## 6. Design first, features on top

Phase 1 shipped the complete UI and navigation with **no audio at all**,
verified on a host preview that renders the real draw code to PNG. Every
feature since has dropped into screens that already existed and were approved.

The preview exists because e-paper full refresh is ~2 s and reflashing is slow;
iterating layout on hardware would have been miserable.

The same approach was repeated for the app: fakes behind interfaces so the real
screens run in a browser.

---

## 7. Two snaps, not four

**Original:** four snap-fit catches, two on each of two perpendicular walls.

**Problem:** they could not be released — you cannot flex the `+Y` panels while
lifting `-X`, so the case could only be opened by breaking it, which also meant
**the LiPo could never be replaced**. Separately, the `+Y` snaps could not
coexist with the speaker grille on that wall; forcing both left 0.1 mm slivers
of skirt that a slicer flagged as floating regions.

**Chosen:** two snaps on the long `-X` wall with a 30° release angle, plus full
skirt engagement on three sides.

Also halved the closing force, which was ~150 N in PLA — you would have bowed
the lid before the snaps deflected.

---

## 8. Rim edges are chamfers, not fillets

The case reads as a pebble because of an 8 mm vertical corner radius. The top
and bottom edges stay **chamfers** because both print on the bed, where a
fillet flares from a horizontal tangent — at R=2 the first 0.2 mm layer would
overhang the one below by ~0.87 mm and droop.

A true pillowed edge needs supports. The reference device was probably printed
with them.

---

## 9. The plunger goes in from inside, before the board

It was first a dumbbell — cap and flange both wider than the bore — so it could
not be fitted from either direction. "Fixing" it by deleting the flange gave
zero press travel and zero retention, because the switch's own return spring
ejects it.

Retention has to be inboard, which means the pin goes in **before the board**,
and the board then traps it.
