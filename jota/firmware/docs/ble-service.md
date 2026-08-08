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
| Manufacturer data | 4 bytes: `FF FF <pending> <flags>` |

`FF FF` is the "no company" prefix BLE requires; the two bytes after it are
ours. `flags` bit 0 = paired. The phone can therefore see **how many notes are
waiting without connecting** — if it is zero, the app never wakes and neither
side spends battery.

## Characteristics

All share the service base; only the last field changes.

| Name | UUID suffix | Access | Payload |
|---|---|---|---|
| `auth` | `...0001` | write | 6 digits, e.g. `428913` |
| `status` | `...0002` | read, notify | JSON, see below |
| `index` | `...0003` | read | JSON array of pending notes |
| `fetch` | `...0004` | write | JSON `{"id":12,"offset":0}` |
| `data` | `...0005` | notify | raw ADPCM chunks |
| `ack` | `...0006` | write | JSON `{"id":12,"crc":"a1b2c3d4"}` |
| `tags` | `...0007` | read, write | JSON array of strings |
| `clock` | `...0008` | write | Unix seconds, decimal string |

### auth

Nothing else responds until this matches the 6 digits on the e-paper. Wrong
code three times → Jota drops the connection and stops advertising for 30 s.

This is the whole security model: **possession of the device**. Pair once; the
bond is remembered, so `auth` is only needed the first time.

### status

```json
{"pending":3,"paired":true,"battery":84,"clock":1786045054}
```

### index

```json
[{"id":12,"secs":47,"bytes":389120,"crc":"a1b2c3d4","time":1786045054}]
```

`bytes` and `crc` are for the ADPCM copy the phone will receive, not the raw
WAV kept on the SD card.

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
stores it and the `TAGS` screen shows it. Max 8 tags, 12 characters each — the
list widget fits 5 rows at a time.

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
auth (first time)    ──▶
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
