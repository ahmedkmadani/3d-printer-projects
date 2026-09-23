# Competitors — the detail

Working notes behind [README.md](README.md). Prices and status as scanned
**August 2026**; re-check before quoting any of it.

---

## 1. Button-press AI voice recorders

The closest commercial shape to Jota: you press, it records, a cloud turns it
into text. No screen on any of them.

### Plaud Note — the category leader
- Credit-card format, 0.12 in thick, 1.06 oz, 64 GB, ~30 h recording.
- **$159** hardware. Free Starter = 300 transcription min/mo; Pro = 1,200 min/mo.
  One review puts real first-year cost around **$259**.
- 112 languages. Dual-mode: records **phone calls** as well as the room.
- Compliance as a selling point: ISO 27001/27701, SOC 2, HIPAA, GDPR, EN18031.
- Positioned at meetings, calls, lectures, "professionals & teams".

### Plaud NotePin
- Wearable capsule — clip, pendant or wristband. Manual press to record.
- Real-world **4–6 h** active recording. Same subscription as Note.

### Mobvoi TicNote
- **$159.99** (£149.99 / €169.99). 64 GB, 120+ languages, free 300 credits/mo.
- Also records phone calls. Same "red dot rule" — physical press to start.
- Newer **TicNote Pods**: 4G earbuds, no phone needed, $299 (WiFi model $249).
  Worth watching — it removes the phone from the loop entirely, which is the
  one architectural idea that could out-flank Jota.

### UMEVO Note Plus
- 3 mm thick, 50 g, magnetic, **40 h** battery, 64 GB. ChatGPT-backed.
- **Unlimited transcription free for year 1**, then a free tier + top-ups —
  explicitly marketed against Plaud's subscription.

**Read on the category:** they optimise the *one-shot summary of an event*.
Nothing in it is built to notice that the same worry showed up in four separate
sessions.

---

## 2. Always-on ambient wearables

These listen continuously. Different consent problem, different product — and
the half of the market that keeps getting bought and switched off.

### Limitless Pendant — dead
- Acquired by **Meta, announced 5 Dec 2025**. Pendant sales stopped the same day.
- Existing users supported "at least another year"; Unlimited Plan made free.
- **EU and UK service withdrawn**, user data scheduled for deletion after
  19 Dec 2025. The Rewind app's screen/audio capture disabled the same date.
- Was $29/mo unlimited. Real battery ~12–14 h with continuous Rewind on.

### Bee Pioneer
- Wrist-worn, **$49.99**. Acquired by Amazon; the **$19/mo was scrapped** after.
- iOS only as of mid-2026, Android "coming".

### Omi — Based Hardware
- **$89**, worn as a necklace (or taped to the forehead — really).
- **Open-source hardware and software**, plugin ecosystem, 25+ languages,
  1,200 cloud min/mo free, local-use option.
- Picked up ex-Limitless users specifically because they'd been burned by
  vendor lock-in. The closest thing to a values-competitor for Jota — but it is
  always-on and cloud-processed.

### Friend
- Notable only for its reception: its ads were **vandalised in public**. That is
  the category's public reputation, and Jota inherits none of it by not being
  always-on.

**Context:** Amazon also removed Alexa's "Do Not Send Voice Recordings" setting
in 2026, citing generative features that need the cloud. The direction of travel
in this category is *away* from local.

---

## 3. Phone apps

Good products; wrong problem. All of them start with unlocking the phone, which
[problem.md](../problem.md) names as the thing an app cannot fix.

- **AudioPen** — rambling speech → clean prose, style transfer. Best in class at
  the *rewrite*.
- **Voicenotes** — native iOS/Android, unlimited recording on paid, 100+ languages.
- **VoiceScriber** — **$49.99 lifetime, fully on-device iPhone transcription**,
  100+ languages, no uploads. This is the privacy bar Jota's v2 has to clear.
- **Apple Voice Memos**, **Pixel Recorder** — genuine on-device transcription,
  free, already on the phone.
- Otter and the meeting-notes crowd — different job entirely.

---

## 4. Journaling / pattern apps — the real competitor for the *reading* half

### Rosebud — study this one
- Voice journaling in 20 languages.
- **After 7–10 entries it generates pattern reports**: recurring themes,
  emotional trends, behavioural cycles.
- AI applies **CBT reframing, ACT acceptance prompts, IFS parts work** depending
  on content. Prompt sequences designed by therapists, grounded in Pennebaker's
  expressive-writing research.
- This is exactly the "coming back is the hard part" job — done well, and with
  no capture device.

Also: **Reflection.app**, **Mindsera**.

**Read:** Jota's `insights.dart` word-frequency stand-in is not competitive with
this, and Gemma-on-phone is a small model. If patterns are the point of the
product, this is where the hard work is.

---

## 5. DIY — the direct ancestor

### Pala Note — Paul Lagier / `thegilbertchan/pala-note`
- **Same Waveshare ESP32-S3 1.54" e-paper board**, 500 mAh LiPo, SD card,
  snap-fit 3D-printed case with no screws.
- Records to SD, then **uploads over WiFi to OpenAI Whisper**, writes the
  transcript back to the card as text files. Scheduled or manual sync.
- Tag system, speaker feedback, deep sleep, local WiFi transfer mode, minimal
  **web interface** for reading notes. Open-source firmware.
- **No LICENSE file** on the repo = all rights reserved. Behavioural/visual
  reference only.

Every meaningful difference from Jota is architectural:

| | Pala Note | Jota |
|---|---|---|
| Link | WiFi on the device | BLE to the phone |
| Credentials | WiFi + API path on device | none, ever |
| Transcription | Whisper, device-initiated | phone-initiated |
| Reading | web page + text files on SD | Flutter app, summaries, patterns |
| Ownership | — | pairing code, stored owner, possession beats bond |
| Language | English | Sudanese Arabic + English first |
| Sorting | none | Gemma on-phone |

Also out there: **Stavros' DIY voice note taker** and assorted ESP32 recorder
builds. No enclosure discipline, no companion app.

---

## The board

Waveshare **ESP32-S3-ePaper-1.54**: **$26.63–$27.99** direct. Also a `G`
(red/yellow/black/white) variant. This is the entire cost story — against $159
plus minutes for the nearest commercial equivalent.
