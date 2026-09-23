# Speech-to-text — the one finding that should change the plan

[solution.md](../solution.md) picks **Google Cloud STT** and says the choice was
made partly because "this gets published as a Google article." That is a
publishing reason, not a language reason. Two 2026 options look better for the
language Jota actually has to handle.

## The requirement

Sudanese Arabic, mixed with English **inside a single sentence**, one speaker,
informal, often in a car. `problem.md` calls this the only open question that
changes the build.

Everyone advertises 100–120 languages. In Arabic that overwhelmingly means
**MSA** — training corpora skew to broadcast and lecture audio, so dialectal
voice notes and proper nouns degrade badly. "Arabic supported" is not an answer.

## The three candidates

| | Sudanese | Code-switching | Notes |
|---|---|---|---|
| **Deepgram Nova-3 Arabic** | **`ar-SD` listed explicitly** (Jan 2026) | not stated | monolingual Arabic model covering major dialects |
| **Speechmatics** | not stated | **handles Arabic↔English mid-sentence natively** | Gulf, Egyptian, Levantine, Maghrebi |
| **Google Cloud STT** | dialect coverage unclear | most engines pick one language | the current plan |

Neither newcomer solves both halves on paper. Deepgram names the dialect;
Speechmatics names the code-switching. That is exactly why it needs a test
rather than a spec-sheet decision.

## The test

Unchanged from `solution.md`, just run against three engines instead of one:

1. Record **2 minutes of normal Sudanese speech with English mixed in**.
   (There is no recording in the repo; make a fresh one.)
2. Send the same file to Google, Deepgram Nova-3 Arabic, and Speechmatics.
3. Read all three. Judge readability, not WER.

`jota/tools/stt_test.py` is where this goes. The app's `Transcriber` interface
means the winner is a one-file swap — but pick it **before** wiring anything.

## If all three are unreadable

`solution.md` is explicit: the product stops and the plan changes. Worth
holding to. Note that the fallback is not "ship it anyway" — it is either
English-only capture, or a different reading model that does not depend on clean
transcripts.

## Knock-on for v2

The v2 goal is on-device STT so nothing leaves the phone at all. Whisper-class
models on-device are English-strong and dialect-weak, so v2 is *harder* in
Arabic than v1, not easier. **VoiceScriber** ($49.99 lifetime, fully on-device
iPhone transcription, 100+ languages) is the proof the engineering is possible
and the bar to beat.
