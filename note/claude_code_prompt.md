# Prompt for Claude Code

Copy everything below the line into Claude Code. Optionally drop `case.py`
into the repo first and mention it — it's a working but kernel-less version
of the same design and is useful as a dimensional reference.

---

Build me a parametric 3D-printable enclosure for a DIY voice-note device. I
want a real CAD-kernel implementation, validated STLs, and a preview render.

## Environment

Use **build123d** (preferred) or **CadQuery** — both wrap the OCCT kernel, so
you get real boolean operations, fillets and chamfers. Set up a venv, pin
versions in `requirements.txt`, and commit a working `README.md`. Do not
hand-roll triangle meshes; if OCCT won't install, stop and tell me rather
than falling back to a mesh hack.

Also install `trimesh` for mesh validation and `manifold3d` if available.

## The device

A pocket voice recorder: press a button, talk, audio is written to SD and
later synced over WiFi for transcription. Components:

- **MCU**: Seeed XIAO ESP32S3 Sense (21 × 17.5 mm board, ~13 mm tall with the
  expansion board stacked). USB-C on one short edge.
- **Display**: Waveshare 2.13" e-paper module — 65.0 × 30.2 × 1.18 mm PCB,
  48.55 × 23.7 mm active area, FPC ribbon exiting one long edge.
- **Battery**: 503035 LiPo, 35 × 30 × 5 mm.
- **Button**: single 6 × 6 mm tactile switch, side-mounted.
- **Status LED**: 3 mm, and a mic port opening.

Before you cut geometry: **search for the current datasheet dimensions of
each part and cite what you find.** My numbers above are from memory and may
be wrong. If a real dimension contradicts them, use the real one and tell me
what changed.

## Requirements

**Structure**
- Two parts: base tray + lid. Snap-fit closure, no screws.
- Every dimension a named constant in one `params.py` or a leading PARAMETERS
  block. I will be editing these.
- Fillet the outer vertical edges and chamfer the top and bottom rims. This
  is the main thing a kernel buys me over the mesh version — use it.

**Fit and clearances**
- Parameterise `CLEARANCE` (default 0.25 mm/side) and apply it everywhere a
  part meets a component, not as magic numbers scattered through the code.
- Snap barbs with a ramped lead-in and a flat catch face. Compute peak
  cantilever strain (eps = 1.5*t*y/L^2) and show the arithmetic. If it exceeds
  **2 %**, redesign — lengthen the beam, thin it, or shrink the barb. Do not
  hand me a design that fails this check. A previous attempt came out at
  8.6 % because the skirt was too short, so treat it as a real risk.
- A continuous unbroken lip is a hoop, not a cantilever, and is far stiffer
  than the formula assumes. Slot the lid skirt into discrete flexing panels
  so the cantilever model actually applies.
- Board mounting: standoffs sized for M2 self-tapping screws, positioned from
  the *real* XIAO hole pattern you looked up.

**Openings**
- USB-C cutout aligned to the connector's actual height above the PCB, given
  the standoff height. Show me the arithmetic.
- Side button opening with a printed-in-place flexure actuator, or a separate
  printed plunger — your call, but justify it.
- Display window sized to the active area plus a small bezel overlap so the
  panel edge and driver IC are hidden.
- Mic port and LED hole.
- FPC ribbon must have a routing path from the display down to the board that
  doesn't crush the cable at its minimum bend radius. This is the detail most
  likely to be wrong — check it explicitly.

**Print constraints**
- Both parts must print with **no supports**. Every overhang above 45° must
  be self-supporting, bridged under 10 mm, or teardrop-shaped.
- Orient each part for printing in the exported STL and say which face is on
  the bed.
- Target 0.4 mm nozzle, 0.2 mm layers. No feature thinner than 0.8 mm.

## Validation — do this, don't skip it

Write `validate.py` and make it pass before you tell me it's done:

1. Each solid is a closed, watertight, oriented manifold with positive volume.
2. No self-intersections.
3. **Interference check**: build simple bounding solids for the board,
   battery, display and connectors at their intended positions, and assert
   the intersection volume with the enclosure is zero. Assert the same
   between internal features (standoffs vs battery pocket vs display
   supports). I hit exactly this bug in an earlier attempt.
4. Assert the assembled clearance between lid skirt and cavity wall equals
   `CLEARANCE` within tolerance.
5. Report wall thicknesses and flag anything under 0.8 mm.
6. Print mass estimates at 20% infill.

Run it and paste the output.

## Deliverables

- `base.stl`, `lid.stl`, print-oriented
- `.step` exports of both, so I can open them in FreeCAD
- An isometric render PNG of each part plus an exploded assembly
- `README.md`: dimensions, print settings, filament recommendation, assembly
  order, and a table of every parameter with what it controls
- A short section listing **which dimensions you guessed vs. sourced**

## How to work

Commit in logical steps: parameters → base → lid → closure → validation.
Don't write the whole thing in one file dump.

Where a real dimension is unavailable, pick a reasonable value, mark it
`# GUESS:` in the code, and collect all of them in the README. I would much
rather have an honest list of guesses than a model that looks authoritative
and doesn't fit. If something in this spec is contradictory or won't print,
push back instead of quietly working around it.
