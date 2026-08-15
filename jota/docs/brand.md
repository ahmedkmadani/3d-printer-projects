# Brand

How Jota looks and sounds. The app and the device share one language.

Design lock: the artifact **Jota Design Lock**. If this doc and that page
disagree, the page is newer — fix this doc.

## Name

**Jota** — Sudanese Arabic for *many thoughts, all at once*.

That is the whole product in one word. Your head is full of jota. The device
catches them.

Capital J always. The device shows its id as `JOTA-91C4`.

## Feel

Warm paper, not tech. Calm, quiet, a bit old-fashioned.
It holds private thoughts — a notebook, not a gadget.

Not: neon, glass, gradients, startup blue.

## Voice

- Short sentences. Plain words.
- Never cheerful. No "Oops!", no exclamation marks.
- Say what happened: *"Saved."* *"2 notes waiting."*
- Never pretend to understand feelings.

## Colours

**Light**

| Role | Hex | Use |
|---|---|---|
| `ink` | `#23201C` | all text |
| `bg` | `#F6F1E8` | paper |
| `inkMuted` | `#8B8177` | secondary text |
| `rule` | `#E4DCD0` | hairlines |
| `field` | `#EFE8DC` | cards, inputs |
| `signal` | `#A8452C` | clay — see rule below |

**Dark**

| Role | Hex |
|---|---|
| `ink` | `#EDE6DA` |
| `bg` | `#16130F` |
| `inkMuted` | `#968C7E` |
| `rule` | `#302A22` |
| `field` | `#1E1A15` |
| `signal` | `#DD6D4C` |

**The accent rule.** `signal` means **live or dangerous**. Nothing else.
The connected dot, recording, Erase. Never a link, never a heading, never
decoration. It was doing three jobs at once and read as random.

Also: no gradients. No shadows except the floating nav bar. Colour never
carries meaning alone — always with a word or a shape.

## Type — IBM Plex, one family

Plex covers serif, sans, mono **and Arabic**, drawn together. That is why it
won: half the notes are Arabic, and nothing else made both languages look like
the same product.

| Role | Face | Use |
|---|---|---|
| display | **Plex Serif** | headlines, the wordmark |
| ui | **Plex Sans** | labels, buttons, prose |
| figure | **Plex Mono** | every number and id |
| arabic | **Plex Sans Arabic** | Arabic note text |

Rules:
- All numbers monospace and zero-padded: `00:47`, `N-012`, `004/005`.
- Prose is never mono. Numbers are never serif.
- Never pick a face by size. Pick it by job.
- Type scale ratio ~1.6 (21px headline against 13px body).

**Replaces** Fraunces, Inter and JetBrains Mono — those are gone from
`assets/fonts/`. Plex Sans is a static instance baked from the variable
original with fonttools; iOS/CoreText would not load the variable file.

## Arabic and right-to-left

**Only the note's own words flip.** Dates, tags, buttons and every other piece
of chrome follow the **app** language.

So an Arabic note inside an English app keeps an English date. Switch the app
to Arabic and the chrome flips too — the note never decides that.

## Shapes

- **Stadiums and circles only.** No square corners.
- Rounded rects r=8 for rows, full pills (r = h/2) for tags.
- **Selected = inverted.** Filled ink, knocked-out text. The only selection
  signal — no ticks, no arrows.
- One hairline and one status line is the whole chrome.

## The device screen

200×200, **1-bit. Black and white only.** No grey, no dithering.

- 12px margin, nothing touches the edge
- `SPACED CAPS` for modal screens, `lowercase + rule` for normal ones
- Keep 4px clear of every edge — the case window crops to 27 mm
- No animation. E-paper redraws, it does not animate.

## Logo

**A circle with `Jota` inside it.** The circle is your head, the word is the
thoughts.

- **Device idle screen** — the ring with `Jota` in it. No label, nothing else.
- **App icon** — same ring, in colour.
- **Wordmark** — `Jota` in Plex Serif, no circle, for text.

Never add a microphone, a soundwave, or a dot-matrix. The circle is enough.

## Motion

Quiet and quick. Motion confirms, it never entertains.

- Fast 120ms — selection, taps
- Normal 220ms — screen changes
- Curve `easeOutCubic`. No bounce, no spring, no parallax.
- **Onboarding** is the one place with ambient motion: circles drifting and
  jostling, one leaving, one breathing. Slow, 3–7s loops.
- Everything stops under `prefers-reduced-motion`.

## Sound

The device has a speaker and no vibration motor. Two beeps only:

- **Recording started** — one short beep
- **Saved** — two short beeps, lower

Nothing else ever makes a sound.

## Open

- App icon not exported yet.
- **Arabic is bundled but not yet used.** `JotaFonts.arabic` exists and Plex
  Arabic ships, but no screen picks it per note yet, and nothing flips a note
  to right-to-left. Needs script detection on the note text.
- The app screens still use the old layout — only the tokens have moved to
  this doc's values. Home, Bluetooth-off and Tags do not exist in the app yet.
