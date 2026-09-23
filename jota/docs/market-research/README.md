# Market research

What already exists, and where Jota is actually different.
Read [problem.md](../problem.md) first — the differences only matter against that.

**Scanned August 2026.** This category moves fast — Limitless went from shipping
to shut down in a single announcement. Treat every price and status here as a
snapshot with a date on it, not a fact.

| File | What |
|---|---|
| this page | the summary — read this |
| [competitors.md](competitors.md) | every product, with specs, prices and dates |
| [stt-options.md](stt-options.md) | the finding that should change [`solution.md`](../solution.md) |
| [sources.md](sources.md) | every link, grouped |

## The five categories

### 1. Button-press AI voice recorders — the closest commercial shape

| Product | Hardware | Model |
|---|---|---|
| **Plaud Note** | credit-card, 30 h record, 64 GB | $159 + subscription for minutes (300/mo free, Pro ~$99/yr) |
| **Plaud NotePin** | clip capsule, 4–6 h real-world | same subscription |
| **Mobvoi TicNote** | $159.99, 64 GB | 300 credits/mo free, then paid |
| **UMEVO Note Plus** | 3 mm, 40 h, magnetic | unlimited transcription year 1, then top-ups |

All four: no screen, cloud transcription, minute quotas, and aimed at **meetings,
calls and lectures**. Plaud can record phone calls. Their summary is one-shot —
you get a tidy record of a meeting, not a picture of your month.

### 2. Always-on ambient wearables — the opposite philosophy

- **Limitless Pendant** — acquired by Meta, Dec 2025. Sales stopped the same day,
  EU/UK service withdrawn, user data deleted. Existing users supported "at least
  a year."
- **Bee Pioneer** — $49.99, acquired by Amazon; the $19/mo was dropped. iOS only.
- **Omi** (Based Hardware) — $89, open source hardware and software, 1,200 cloud
  min/mo free. Picked up ex-Limitless users specifically because of lock-in.
- **Friend** — ads vandalised in public. That is the category's reputation.

These listen continuously. That is a different product with a different consent
problem, and it is the half of the market that keeps getting bought and shut down.

### 3. Phone apps

**AudioPen** (rambling → clean prose), **Voicenotes**, Otter, Apple Voice Memos,
**VoiceScriber** ($49.99 lifetime, fully on-device iPhone transcription).
Cheap, good, and irrelevant to the actual problem: they all begin with unlocking
the phone.

### 4. Journaling / pattern apps — the closest thing to the *reading* half

**Rosebud** is the real one. Voice journaling in 20 languages, and after 7–10
entries it produces pattern reports surfacing recurring themes and emotional
cycles, using CBT / ACT / IFS framing. Also Reflection.app, Mindsera.

This is the only category that takes "coming back" seriously — and none of them
have a capture device.

### 5. DIY — the direct ancestor

**Pala Note** (Paul Lagier / thegilbertchan). Same Waveshare ESP32-S3 e-paper
board, same one-button pocket shape, same snap-fit printed case, tag system,
speaker feedback. Records to SD, then **uploads over WiFi to OpenAI Whisper** and
writes the transcript back to the card; read through a small web interface.

Also: assorted ESP32 recorders and one-off blog builds. No enclosure discipline,
no companion app.

## Where Jota is genuinely different

**1. No WiFi, no account, no server, no subscription.**
Everything in category 1 sells you minutes. Jota's audio crosses BLE to a phone
that already has internet; there is no credential on the device and nothing to
cancel. Pala Note — the nearest sibling — puts WiFi and an API path on the device
itself. Jota deliberately does not.

**2. One voice, over weeks — not a meeting.**
Category 1 optimises the one-shot summary. Jota's success test is *"do repeating
topics show up on their own."* Nobody with a device does this. Rosebud does it
without a device.

**3. Deliberate capture, on a screen that cannot distract.**
Same button-press consent model as Plaud, but with e-paper state feedback the
screenless recorders lack — and unlike a phone, the screen has nothing on it to
fall into. There is no notes list on the device on purpose.

**4. Sorting never leaves the phone.**
Gemma on-device does the summarising and clustering. Only STT is remote, and
that's a stated v1 compromise with a v2 exit. Compare Omi (open source but
cloud-processed) and Amazon quietly removing Alexa's "do not send voice
recordings" option.

**5. Dialect-first.**
Everyone advertises 100–120 languages, which means MSA. Sudanese Arabic mixed with
English is the hard case, and it is Jota's *primary* case, not an edge one.

**6. Cost.** ~$27 board + battery + a few grams of PETG. Against $159 + minutes.

## Where the competition is plainly better

- **Battery.** Plaud 30 h, UMEVO 40 h. Jota's 500 mAh is unmeasured, and the
  battery gauge is switched off in firmware.
- **Transcription quality** is bought, not built. Their accuracy is a product; ours
  is an API call and an untested one.
- **Phone-call recording** — Plaud and TicNote do it; Jota can't.
- **Remembering to press.** Always-on wearables exist because people forget.
- **Patterns.** Rosebud's is mature and clinically framed. Jota's is currently a
  word-frequency stand-in (`lib/insights/insights.dart`) and Gemma is small.
- Everything on the market has a shipping microphone. Jota's is still simulated.

## One finding that should change the plan

[`solution.md`](../solution.md) picks Google Cloud STT for Sudanese Arabic. Two better-looking
options appeared in 2026:

- **Deepgram Nova-3 Arabic** (Jan 2026) explicitly lists **Sudanese Arabic
  (`ar-SD`)**.
- **Speechmatics** handles Arabic↔English **code-switching mid-sentence** natively.

Both should go in the same bake-off as Google before the `Transcriber` interface
is wired to anything. The Google choice was made for the article, not for the
language.

## Honest summary

Jota is not competing with Plaud. It is Pala Note's shape, pointed at Rosebud's
job, with the privacy posture neither of them has and the language none of them
handle. The riskiest claim in the whole product is not the hardware — it is that
Gemma-on-phone can find real patterns in dialectal Arabic transcripts.

## Next time this is opened

Three things to re-check before trusting any of it:

1. **Is Omi still alive and still open source?** It is the only values-competitor.
2. **Did anyone put a screen on a button-press recorder?** That is Jota's
   remaining shape advantage in category 1.
3. **TicNote Pods** ($299, 4G, no phone needed) — the one architecture that
   removes the phone from the loop entirely.

All links in [sources.md](sources.md).
