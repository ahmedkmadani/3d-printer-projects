# The solution

Answers [the problem](problem.md). Read that first.

## In one line

**A small device with one button. Press, talk, and later read your sorted
thoughts on your phone.**

## The flow

```
press button  →  it records  →  phone picks it up  →  text  →  sorted  →  I read it
   (device)       (device)         (BLE)            (STT)    (Gemma)      (app)
```

## Why a separate device, not just an app

The phone is the distraction. That is the one problem an app cannot fix.
A separate device has no screen to fall into, no notifications, one button.

## Two parts

**The device** — records and stores. That is all.
No reading notes on it. No transcript. It is a capture tool.

**The phone** — the library. Gets the audio, turns it into text, sorts it,
keeps it. This is where I read and search.

## What runs where

| Job | Where | Why |
|---|---|---|
| Record | Device | Hands free, no phone needed |
| Send audio | BLE to phone | No WiFi on the device, no server |
| Speech → text | **Google Cloud STT** (for now) | Only thing good enough for Sudanese Arabic — but see [market-research/stt-options.md](market-research/stt-options.md): Deepgram lists `ar-SD`, Speechmatics does code-switching. Bake off all three. |
| Sort and summarise | **Gemma on the phone** | Stays offline. Runs on any Android, not just Pixel |
| Store | Phone, local | Nothing in a cloud account |

## Direction

**Now (v1):** cloud speech-to-text. Easy, works, proves the product.

**Next (v2):** move speech-to-text onto the phone. Then nothing leaves the
device at all.

This is the honest state today: **the audio goes to Google to become text.**
The sorting of that text never leaves the phone. Full privacy is the goal, not
yet the fact. Say this plainly anywhere it is published.

## Stack

- Device: ESP32-S3 e-paper board, Arduino/PlatformIO
- Phone: Flutter
- Text: Google Cloud Speech-to-Text
- Sorting: Gemma via MediaPipe, on-device
- Link: custom BLE service (`firmware/docs/ble-service.md`)

Google stack on purpose — this gets published as a Google article.

## Dropped

OpenAI Whisper. It was the old plan. Replaced by Google Cloud STT.
The `Transcriber` interface in the app stays, so this is one file swap.

## Risks

| Risk | What to do |
|---|---|
| **Sudanese Arabic may transcribe badly** | Test with a real recording before building anything else |
| **Mixing Arabic and English in one sentence** | Most engines pick one language. Test this too |
| Gemma is small — Arabic sorting may be weak | Test on real transcripts |
| vivo phone kills background apps | Always keep a manual sync button that works |

## Next test (do this first)

Record 2 minutes of normal Sudanese speech, with some English mixed in.
Send it to Google Cloud STT. Read the result.

If it is unreadable, the whole product stops here and the plan changes.
