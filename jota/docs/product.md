# The product

What Jota does. Built from [problem.md](problem.md) and [solution.md](solution.md).
Looks and feels: [brand.md](brand.md). Every screen is drawn in the
**Jota Design Lock** artifact.

If it is not here, we are not building it.

## In one line

**One button. Press to record, press to stop. Your phone picks it up, turns it
into text, and sorts it for you.**

## User stories

### Setup
- **S1** — Turn it on and connect it to my phone, so it works out of the box.
- **S2** — It reconnects on its own after that, so I never pair again.
- **S3** — Erase everything before giving it to someone else.
- **S4** — Skip the intro if I already know what this is.
- **S5** — Be told if Bluetooth is off, instead of it just failing quietly.

### Capture
- **C1** — Press one button and talk while driving, so I never touch my phone.
- **C2** — Talk for 10 minutes without stopping, so I get it all out.
- **C3** — Hear that it is recording, so I trust it without looking.
- **C4** — It saves even if I hit power or the battery dies, so I lose nothing.
- **C5** — Tag the note right after I stop, if I feel like it. Never forced.

### Arrive
- **A1** — Notes move to my phone by themselves when I am near.
- **A2** — Pull down to sync, for when my phone blocks background apps.
- **A3** — See that a note is waiting, so I know nothing is stuck.

### Read
- **R1** — Read text, not play audio, so I can skim in seconds.
- **R2** — Each note summarised into its few real points.
- **R3** — See topics that repeat across weeks, so I notice patterns.
- **R4** — Search my notes.
- **R5** — Play the original audio if I want.
- **R6** — Fix a tag or a word the AI got wrong.
- **R7** — See how my week went at a glance.

### Trust
- **T1** — Lock the app behind my face or fingerprint.
- **T2** — See clearly what leaves my phone, so I speak freely.

## The device

Five screens. No menu. No notes list.

| Screen | When |
|---|---|
| **Ready** | Idle. The ring with `Jota` in it — no label |
| **Recording** | Same ring, a second ring inside it, timer below |
| **Saved + tags** | ~10s after stop. Optional tagging |
| **Pair** | Only when it has no owner |
| **Erase?** | Only after holding both buttons |

Recording never changes the circle's size or position. Only ink is added, so it
lands instantly on a slow panel.

Buttons:

| | Short press | Long press |
|---|---|---|
| **BOOT** (round) | Start / stop / confirm | — |
| **PWR** (star) | Next tag | Power off |
| **Both** | — | Erase (5s, then confirm again) |

Sound, not vibration — the board has a speaker and no motor.
One beep on start. Two lower beeps on saved.

## The app

Ten screens, three tabs.

| Screen | Notes |
|---|---|
| **Lock** | First thing, every open. Face or fingerprint. No note preview behind it |
| **Bluetooth off** | Checked on open and on resume. Offers "turn on" *and* "keep reading offline" — never a dead end |
| **Onboarding** | Three screens, skippable. See below |
| **Connect** | First run only. Scan, tap, type the code |
| **Home** *(tab)* | This week's count and minutes → what keeps coming back → latest note |
| **Patterns** | Reached from Home. Topic, count, four weeks of bars |
| **Notes** *(tab)* | Newest first. Date, tag, summary. Pull to sync |
| **One note** | Summary above, transcript below, audio optional, edit tag |
| **Tags** | Inside Settings. Reorderable list |
| **Settings** *(tab)* | Tags, device, battery, app lock, what leaves the phone, erase |

A strip above the nav always shows: device, battery, notes waiting.

Sync is never a place you go.

### Onboarding

Three screens, **Skip** top-right on all of them:

1. **When your head is full.** — Thoughts pile up and talk over each other. That is jota.
2. **Say it, let it out.** — Press once and speak. Jota holds it for you.
3. **Feel lighter.** — It is out, it is saved, and it is yours.

No Bluetooth, no recordings, no files, no syncing. One line each.

## Tags

- The list lives in the **app**. Starts with **Work, Personal, Ideas**.
- Add, rename and **reorder** in the app.
- Only the **top 5** go down to the device — reordering is how you choose them.
- Tag on the device if you want, in the 10 seconds after saving.
- Skip it and Gemma picks a tag later.
- **If I tagged it myself, Gemma never changes it.**

## Connecting

**First time**

```
Turn on Jota  →  no owner, so it shows a code: 428 913
Open the app  →  it finds "JOTA-91C4"
Tap it, type the code  →  done
```

Only the device ever *shows* a code. The app only ever *asks* for one.

**After that**

```
Record → Jota saves it → quietly broadcasts "1 note waiting"
   → phone hears it when near → connects on its own → pulls the audio
   → Google STT → Gemma sorts → shows up in the app
```

**Another phone** is refused, unless it types the code showing on the screen
right then. Holding the device beats any saved pairing.

## Erase

1. **App** — Settings → Erase device → confirm
2. **Device** — hold both buttons 5s → *ERASE?* → hold again 3s

Wipes the owner, **all audio on the SD card**, and custom tags.
Then it boots like new.

The app must warn clearly: *this deletes all recordings on the device.*

## Rules that are easy to get wrong

- Nothing on the device ever deletes a recording except Erase.
- Recording is never interrupted. Not by sync, not by a phone connecting.
- A note only leaves the pending list after the phone confirms it.
- Tagging never blocks. Press record during the tag window and a new
  recording starts.
- The device never shows note text. It has none.
- Bluetooth being off is a notice, not a wall — synced notes still read.

## Not doing

- No notes list or reading on the device
- No tasks, checkboxes, or reminders
- No multi-speaker or meeting transcripts
- No accounts, no cloud storage of notes
- No sharing or export (yet)
- No WiFi on the device

## Later

- Move speech-to-text onto the phone, so nothing leaves at all
- Arabic app language (chrome flips; see [brand.md](brand.md))
- Export

## Built / not built

**Built:** Home, Patterns, Notes, One note, Tags (drag to reorder), Settings,
Lock, Onboarding, Connect, Bluetooth off. Arabic notes read right to left.
Three tabs. 44 tests, analyze clean.

**Not built:** everything on the device side of this doc — it still has ten
screens, not five. Recording, tagging and the erase gesture are unchanged.

**Standing in for Gemma:** "what keeps coming back" counts words that return
across separate notes (`lib/insights/insights.dart`). It is honest and local,
but it cannot tell that "my brother" and "family" are one thread. Gemma
replaces it behind the same shape.

## Open

- Which Google STT setting handles Sudanese Arabic mixed with English.
  **Test before building.**
- App icon not exported.
- The case may change — see the CAD work.
