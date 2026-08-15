# Jota BLE service — contract for the phone app

This is what the Flutter app talks to. Jota has **no WiFi**: the phone pulls
audio over Bluetooth and does the transcription, so there are no WiFi
credentials and no API key on the device.

Use `flutter_blue_plus` on the app side. Everything here is UTF-8 text or raw
bytes — no protobuf, no crypto handshake to reimplement.

## Roles

Jota is a **peripheral**: it cannot contact the phone. All it can do is
advertise. The phone is the **central**: it scans, connects, and pulls.

The app registers with the OS for background BLE and says "wake me if you see
this service UUID". The OS starts the app when Jota appears, even if the app
was closed.

## Advertising

Broadcast continuously (slow interval when idle, fast for ~60 s after a
recording or after `SYNC` is pressed, then back to slow).

| Field | Value |
|---|---|
| Local name | `JOTA` |
| Service UUID | `4a6f7461-1e5f-4b2a-9c33-000000000000` |
| Manufacturer data | 7 bytes: `FF FF <pending> <flags> <id-hi> <id-lo> <battery>` |

`FF FF` is the "no company" prefix BLE requires; the five bytes after it are
ours. `flags` bit 0 = paired, bit 1 = owned (some phone holds the bond).

`battery` is charge 0..100, or **`0xFF` for unknown** — a board with no
battery-sense pin wired, which is not the same as a flat one and must never be
shown as 0%. It rides in the advertisement so the app can show charge WITHOUT
connecting, which is the whole point of this field: the common questions should
be answerable for free.

`id-hi`/`id-lo` are the low 16 bits of the device id — enough to tell two
Jotas apart **in a scan list, before connecting to either**. The app shows it
as `JOTA-7F3A` beside the device, and the same four characters are printed on
the device's own PAIR screen, so "which one is mine" is answerable by looking
at both.

The phone can therefore see **how many notes are waiting without connecting**
— if it is zero, the app never wakes and neither side spends battery.

## Characteristics

All share the service base; only the last field changes.

| Name | UUID suffix | Access | Payload |
|---|---|---|---|
| `auth` | `...0001` | write | JSON `{"app":"<uuid>","code":"428913"}` |
| `status` | `...0002` | read, notify | JSON, see below |
| `index` | `...0003` | read | JSON array of pending notes |
| `fetch` | `...0004` | write | JSON `{"id":12,"offset":0}` |
| `data` | `...0005` | notify | raw ADPCM chunks |
| `ack` | `...0006` | write | JSON `{"id":12,"crc":"a1b2c3d4"}` |
| `tags` | `...0007` | read, write | JSON array of strings |
| `clock` | `...0008` | write | Unix seconds, decimal string |

### auth

Nothing else responds until this passes. `status` is the one exception — it is
readable unauthenticated, precisely so the app can find out that it is *not*
authenticated. **Read `authed` from `status` rather than assuming a successful
read means anything**; the app used to infer the bond from the read succeeding,
so it never sent a code, and every sync then read an empty `index` and reported
"all caught up" while notes sat on the device.

Two ways in:

```json
{"app":"9f2c…"}                    // the owner reconnecting: silent, no code
{"app":"9f2c…","code":"428913"}    // a new phone: the digits on the e-paper
```

`app` is a UUID the phone generates once, on first run, and never changes. The
first phone to present a correct code becomes the **owner**, and Jota persists
that UUID: from then on that phone reconnects with no code and no prompt. That
is what "pair once" means, and it is what makes forgetting-and-rejoining cheap.

A **different** `app` uuid is refused with `{"error":"owner"}` — unless it
presents the code currently on the e-paper, which transfers ownership. Physical
possession of the device outranks the stored bond, deliberately: the security
model is possession, and a device that could lock out the person holding it
would be worse, not better.

Wrong code three times → Jota drops the connection and stops advertising for
30 s.

### status

```json
{"pending":3,"paired":true,"authed":false,"owned":true,
 "device":"7f3a91c4","battery":84,"clock":1786045054}
```

`battery` is 0..100, or **-1** when this board cannot measure it.

`authed` is this connection's state, not a stored fact — it is false on every
fresh connection until `auth` passes. `owned` says a phone holds the bond;
`device` is the device id whose last four characters the app shows as
`JOTA-7F3A`.

### index

```json
[{"id":12,"secs":47,"bytes":389120,"crc":"a1b2c3d4","time":1786045054,
  "tag":"PERSONAL"}]
```

`bytes` and `crc` are for the ADPCM copy the phone will receive, not the raw
WAV kept on the SD card.

`tag` is whatever was chosen on the device in the seconds after the recording
stopped, or `""`. It is a plain string, not an index: the phone can edit its
tag list between a recording and a sync, and an index would then point at
something else entirely.

### fetch / data / ack — with resume

The audio arrives as `data` notifications, a few hundred bytes each. A minute
of speech is ~480 KB of ADPCM, roughly 16 s of transfer.

```
app  ──▶ fetch  {"id":12,"offset":0}
Jota ──▶ data   chunk, chunk, chunk …
app  ──▶ ack    {"id":12,"crc":"a1b2c3d4"}
Jota      marks 12 synced, pending--
```

**If the connection drops mid-transfer**, nothing is lost and nothing needs a
retry button:

- Jota only marks a note synced when it receives a **valid `ack`**. No ack, or
  a CRC mismatch, and the note stays pending.
- Because it is still pending, it is still counted in the advertisement, so
  the phone wakes and reconnects on its own.
- The app resumes with `fetch {"id":12,"offset":180224}` — Jota seeks into the
  file and continues from there. Only the missing part is re-sent.
- The app should keep partial data keyed by note id, and verify the CRC over
  the whole note before sending `ack`.

A truncated transfer is therefore never mistaken for a complete one, and a
dropped link costs only the bytes still outstanding.

`fetch` with `offset` beyond the file length, or for an unknown id, gets a
`status` notify with `{"error":"range"}` and no data.

### tags

Read to populate the app's editor, write to replace the whole list. Jota
stores it and offers it on the SAVED screen. Max 8 tags, 12 characters each —
the list widget fits 5 rows at a time, and the app sends only the first 5.

**Tags are chosen AFTER a recording, not armed before it.** The device offers
the list for ten seconds on SAVED; press to choose, or say nothing and the note
arrives untagged for the phone to label.

This replaces pre-arming, which was the only gesture that fit two buttons while
the list lived behind a menu. Arming meant deciding what a note was about
before saying it, and a tag armed and then forgotten silently filed every later
note under a heading chosen once. Choosing afterwards costs nothing, because by
then you know what you said — and it times out, so it never gets in the way of
press-speak-press.

### clock

Jota has no network, so it cannot learn the time by itself. The app writes
Unix seconds on every connect; Jota sets its RTC. This is what makes the
timestamps real rather than counting from boot.

## Sequence, end to end

```
you record                 Jota: note saved to SD, pending = 1
                                 advertise "JOTA, 1 waiting"
                     ──▶    OS wakes the app
app connects         ──▶
status               ◀──    {"authed":false,"owned":true,"device":"7f3a91c4"}
auth {"app":"9f2c…"} ──▶    uuid matches the stored owner
status               ◀──    {"authed":true,…}   ← the app CHECKS this
clock                ──▶    RTC set
index                ◀──    [{"id":12,...}]
fetch id 12          ──▶
data chunks          ◀──    ~16 s for a minute
ack id 12            ──▶    pending = 0
                            app sends audio to Whisper
                            transcript stored in the app
```

## Notes for the app

- Request the largest MTU you can (247 bytes is typical); throughput scales
  almost linearly with it.
- Subscribe to `data` **before** writing `fetch`, or you will miss the first
  chunks.
- Do not assume chunk boundaries mean anything — reassemble by order, and
  trust only the CRC.
- Keep the connection alive until `ack` is sent; disconnecting early is
  handled, but it wastes the transfer.
- Authenticate on **every** connection, including tag reads and writes and the
  clock. `authed` is per-connection state on the device; a `tags` or `clock`
  write on an unauthenticated link is discarded, and — because the
  characteristic still acks the bytes — a discarded write looks exactly like a
  stored one from the phone's side. `status` now reports `{"error":"auth"}` for
  such a write, but the fix is to authenticate, not to watch for the error.
- One connection at a time. The plugin hands out a single device handle per
  remote id, so a second `open` while a sync is running re-discovers services
  underneath it and the matching `close` disconnects the link the transfer is
  still using.
