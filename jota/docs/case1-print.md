# Case 1 — printing and assembly

Generated from `jota/src/case1.py`. Run the gate first; it is not a formality:

```bash
.venv/bin/python jota/src/check_case1.py     # must pass
.venv/bin/python jota/src/export_case1.py    # -> models/next/case1_*.{stl,3mf}
.venv/bin/python jota/src/render_case1.py    # -> renders/case1/*.png
```

`check_case1.py` re-reads `jota/ref/refcase_*.stl` on every run and compares
against it, so the numbers cannot drift away from the object they came from.

## Parts

Two sets of halves; pick one. `jota/models/next/` holds nothing else.

| | volume | mass @ 20% | bed orientation | supports |
|---|---|---|---|---|
| `case1_front` | 4.83 cm³ | ~3.8 g | window face **down** | none |
| `case1_back` | 8.29 cm³ | ~6.6 g | floor **down** | none |
| `case1_front_sd_card` | 4.73 cm³ | ~3.8 g | window face **down** | none |
| `case1_back_sd_card` | 8.21 cm³ | ~6.5 g | floor **down** | none |
| `case1_front_header` | — | — | window face **down** | none |
| `case1_back_header` | — | — | floor **down** | none |
| `case1_back_header_sd_card` | 9.15 cm³ | ~7.3 g | floor **down** | none |
| `case1_pin_pwr` | 0.06 cm³ | — | flange **down** | none |
| `case1_pin_rec` | 0.06 cm³ | — | flange **down** | none |

`case1_front`/`case1_back` are the halves as first printed and approved — no
SD opening. The `_sd_card` pair adds the card slot in the back's +X skin and
the tongue relief behind it in the front. Halves must match: a plain front
with an SD back leaves the card blocked by the tongue.

Assembled **42.0 × 57.0 × 13.49 mm** — 1.0 mm a side more than the reference's
40 × 55, because the R8 pebble corner needs it to keep a full lap joint
behind the board pocket's R1.8 corners. See the CASE 1 block in `params.py`. Both files are already in their print
orientation — do not rotate them.

Neither half has a single flat unsupported ceiling: the checker measures
0.00 mm² on both. That is what lets them print without support, and it is why
the side openings run all the way through to the tongue rather than stopping
short.

## Material

**PLA works for a first build; PETG for a case that is opened often.** The
snap fingers run at 1.48 % strain (see Snaps). Screws are gone.

Colour: bone, espresso, clay or sage, per `jota/docs/brand.md`.

## Printer and nozzle

The printer is a **Bambu Lab A1 mini** with a **0.4 mm nozzle** (confirmed
2026-08-31). `params.NOZZLE = 0.4` matches it; every minimum-feature check is
derived from that value.

Bambu Studio was last left on the **"A1 mini 0.2 nozzle"** preset. Opening a
project sliced for 0.4 with that preset active is what produces the "nozzle
diameter does not match" warning. The fix is on the slicer side: pick the
machine preset that matches the hotend that is physically fitted, then
re-slice. Our `.3mf` files carry no printer settings, so they never trigger
the warning themselves — only the preset does.

**The geometry is the same for 0.2 and 0.4.** Both pass `check_case1.py`; the
only thing that changes is the slicer profile. Set `NOZZLE` in `params.py` to
whichever is fitted so the checker enforces the right limits:

| nozzle | machine preset | process preset | layer | walls |
|---|---|---|---|---|
| 0.4 (stock) | A1 mini 0.4 nozzle | 0.20mm Standard | 0.20 | 2 loops |
| 0.2 | A1 mini 0.2 nozzle | 0.08mm Optimal or 0.12mm Fine | ≤ 0.12 | 2 loops |

At 0.2 the checker fails until `LAYER_H` is dropped too: a 0.2 mm layer through
a 0.2 mm nozzle is over-tall and the check says so.

A **0.6 nozzle will not work** on this part — the lap joint's budget is fixed
by the reference at 2.94 mm per side and two-perimeter walls plus clearance
need 3.30.

## Slicer

- Outer skin ~2.0 mm on the flats, thinning to 1.04 at the corner diagonal;
  tongue 1.20. 2 wall loops.
- 20 % infill is plenty; nothing here is structural but the standoffs.
- No brim needed: both halves have a large flat first layer.

## The header variant

`C1_VARIANT=header` builds a back for a board that still carries its stock
2×6 header (9.0 mm tall). It is 3 mm deeper — case **16.49** instead of 13.49
— and takes a **602535** cell (6 × 25 × 35, 500 mAh) beside the header instead
of the 503035: a 30.5-wide cell cannot sit next to a header at x −15.5…−10.5,
and widening the cavity would move the tongue, i.e. a new front and longer
pins. The 25-wide cell keeps both. The cell pocket abuts the +X cavity wall;
its −X rib is 1.4 clear of the header. Foam pad under the board is 3.3.

Files: `case1_back_header`, `case1_back_header_sd_card`. **The front and
the pins are the plain ones** — they do not change.

## The pebble edge

Both rims carry a 0.8 mm seam chamfer, so the joint reads as one 1.6 mm
V-line (the front's was missing until an audit caught it).


Both outer faces have a 1.5 mm 45° facet at the bed blended into the wall by
an R5 fillet. Nothing on either half overhangs past 45° — the checker measures
the steepest down-facing facet and it reads 45.0°. That is the most a
face-down print can carry without support (decisions.md #8); a plain fillet
would meet the bed tangent-horizontal and droop. The middle ~5 mm of the side
is straight: that band is the lap joint and cannot be rounded.

## Snaps, not screws

Two cantilever fingers on the **front's** −X wall (the solid wall, opposite
the buttons) hang down inside the back's skin. Each carries a 0.5 mm hook
that drops into a **groove cut in the skin's inner face** — nothing shows
outside. Press the halves together until they click; to open, pull them
apart firmly (the 60° catch is a detent, roughly 1 kgf). Print #4 had
windows through the skin and hooks drawn 0.15 mm — below a nozzle width, so
they never printed. Gone.

The finger is as long as its back allows: 8.7 in the header back (strain
0.79 %, PLA), 7.0 in the plain back with a 1.3 mm pocket in the floor under
each tip (1.22 %, PETG advised). So **the front is exported per back**:
`case1_front_header` for `case1_back_header`, `case1_front` for `case1_back`.

## The USB port

Sized to the USB-IF rule, not to a guess: **the surface the plug's overmould
seats on must be within 0.3 mm of the receptacle's front face**, or every
cable stops short of mating (Type-C Locking Spec Annex A; R1.3 Fig 3-73).

So: a **tight hole** (9.6 × 4.0 printed, R0.5) round the connector, the
receptacle nose sitting inside it; a **recess** (14 × 8 printed, R1.5, 4.0
deep) for the overmould nose — spec-max overmould is 12.35 × 6.5; and the
recess floor **flush with the receptacle face**, 0.7 thick, its inner face
0.3 off the PCB edge. The floor is a boss inside the back, continued above
the seam by a block in the front's shelf.

Receptacle face assumed **1.0 mm past the PCB edge** (HRO-class 16-pin
footprint). The floor works while that protrusion is **≥ 0.7**; above 1.0 the
receptacle nose simply sits inside the recess and becomes the seat itself,
which is harmless. **If a cable will not click home in the printed part**, the
receptacle is flush-mounted and the remedy is one flag: `C1_USB_NO_FLOOR=1`
cuts the recess straight through to the hole, so the receptacle face is the
seat at any protrusion. Connector at x = −0.8.

**Y stops.** Without screws the board floated 1.15 mm each way in the pocket,
and plugging a cable pushes it away from the port. The front now carries a
stop at each end of the shelf band (±23.80): 0.3 a side round a 47.0 board.

## The cord tunnel

The Design Lock's idea, done the way this case allows. Every corner has a
screw, so a tunnel through the corner meat leaves a 1.2–2.4 mm bar — instead
**the standoff is the bar**. Two 2 mm mouths low in the top-left (−X, +Y)
corner, one in the end wall and one in the side wall; the cord goes in one,
runs on the floor round the outside of the corner standoff (a 4.8 mm column
screwed to the board), and out the other. Nothing on the silhouette. The
mouths sit at z 2.5, under the front's tongue, so the front is untouched.

Cord: **1.5 mm**. A 2 mm cord will not pass under the tongue. Thread it
before the cell goes in — the path is visible with the back open.

## The buttons

The switches sit below the board's back face — below the joint — so the
openings are U-slots in the **back's** +X skin, open to the rim and capped by
the front. Each takes a pin: head out, stem through the slot, flange inboard.
The switch's own spring pushes the pin out; the flange is what stops it.

- `case1_pin_rec` — BOOT, the record button: rounded head, stands 1.2 proud,
  sits in the thumb dish.
- `case1_pin_pwr` — PWR: flat head, 0.8 proud, plain wall.

The SD card has its own U-slot in the same wall, toward the far end. It costs
joint: the +X tongue keeps 18 of 49 mm after the three reliefs; −X and both
ends carry the register. Put back at the owner's call on 2026-08-31.

The actuator height is still a guess (`C1_BTN_Z`). The slot lets the pin
ride 1.2 mm up or down and find it. If a button is dead, that is the number.

## Assembly, in order

1. Cord through the two corner mouths, round the outside of the standoff.
2. (Speaker: off by default. `C1_SPEAKER=1` restores the bay and grille for a
   15 × 6 × 3 mm "1506"; Waveshare's 2030 does not fit this case.) into its bay at the +Y end,
   between the standoffs. Then the cell into the ribs, leads out through the
   break at the +X end of the +Y rib — the BAT connector is in that corner. The ribs are 1.60 mm tall — they locate the cell, they do not grip
   it.
2. **1.0 mm foam pad on top of the cell.** This is load-bearing, not padding:
   floor 2.79 + cell 5.30 + pad 1.00 = 9.09, which is exactly the board's back
   face. Without it the cell can lift.
3. **Pins in from inside**: record pin (rounded) into the slot nearer the
   middle of the case (BOOT, in the dish), flat pin into the one nearer the USB
   end (PWR). Flange inboard. They fall out until the board is on.
4. Board down onto the four standoffs, mounting holes over them.
5. Front on. The tongue enters the back's skin — 4.50 mm of lap, 0.20 mm of
   clearance — and the two snap fingers click into their windows on the −X
   wall. Press until both click.

Screw length: the pilot starts 10.69 mm in and ends at 12.99. **M2 × 12** is
the size — 1.31 mm of thread engagement. M2 × 13 bottoms out with 0.01 mm to
spare, which is no margin at all; it will jack the halves apart before it
tightens.

## Prints that went wrong, and what now catches each

| print | fault | check added |
|---|---|---|
| front #1 | SD slot on the wrong wall | openings tested in the **assembled** frame |
| front #2 | all three openings mirrored (authored-frame X) | same, plus `AX` in `case1.py` |
| front #2 | board could not seat: pocket corners R5.06 vs PCB ~R2 | PCB outline walked round the pocket; corner-diagonal probes |
| front #3 | window cropped the top of the screen — offset copied from the reference, whose board carries the panel the other way | window sign checked against the board (away from the USB/FPC end), magnitude against the reference |
| back #2 | slicer: floating regions — two snap windows overlapped by 0.1, their gable roofs met in mid-air | layer-by-layer island scan (7c), the check CLAUDE.md asked for |
| — | no speaker bay | 16 × 5 bay in the back's +Y end, grille of four 1 × 4 slits, tongue relieved over it |

## What is still unproven

- **Thread engagement is the weakest link.** 2.30 mm of pilot in plastic is
  not much, and it is capped by the front being 2.795 mm thick at the shelf —
  going deeper breaks through the face. If a screw strips, that is the reason.
- **The button and SD positions are ours, not the reference's.** It holds a
  bare board and has no side openings at all, so `BTN1_CTR_Y`, `BTN2_CTR_Y`
  and `SD_CTR_Y` are unverified against real hardware. The openings are
  deliberately generous for exactly this reason.
- **The lap clearance is 0.20 mm as printed**, derived from the reference's
  0.203 plus our printer's 0.25-per-surface proudness. If the halves bind or
  rattle, this is the number to move, and it is one constant.

## Corner press-fit coupons (concept D), 2026-09-19

Printed the 1-notch (0.05) and 2-notch (0.10) corner pairs. Both seated
flush, neither held: the halves separate under their own weight. The
retention is a 0.33 ridge and a 0.34 lip overlapping 0.10 — below what a
0.4 nozzle prints as a feature at all. The joint asks for more precision
than the process has (0.05–0.25 growth per surface). Abandoned; not worth a
wider ladder. Next: the slide lock + key, every clearance 0.30.

## Slide-lock site coupon, 2026-09-19

`slide_front` / `slide_back` (one tab site) dropped and slid, then lifted
straight off. Expected in hindsight: the tab's underside is a 45 deg cam,
so lift pushes the strip INWARD off the tab, and only the opposite wall
(one lap clearance away) stops that. A one-site coupon has no opposite
wall. It proves the drop/slide clearances, nothing about hold. Replaced by
the `span_*` pair: a 10 mm strip across the whole case at x ~ -12, both
walls and both tongues present. That is the hold test.

## Slide-lock span coupon, 2026-09-19

`span_front` / `span_back` (both walls, both tongues, x ~ -12) also lifted
off. Root cause is the mechanism, not the print: the tab's 45 deg
underside is a cam that pushes the strip inward on lift; the far wall only
resists after one lap clearance (0.70 drawn), and the 1.20 mm tongue
flexes the remaining 0.5 of the 1.10 mm engagement. Fix: a backing rib on
the back's floor 0.30 inside each tongue at every site (C1_SLIDE_RIB_*),
top at the standoff top, trimmed to the tongue's corner arcs at both the
locked and the drop offset. Checker passes (closure sweep, heads, PCB,
cell, overhangs, islands). Span pair re-exported with the ribs.

## Pala Note case V1.0, read 2026-09-23

Owner's download at `~/Desktop/027 Pala Note` (personal-use licence: no
redistribution, modifications for personal use allowed; nothing from it
goes in this repo). Same Waveshare board; Pala's `config.h` confirms
`BAT_ADC_PIN 4`. Guide: 0.2 mm layers, no supports, PETG recommended,
"press both halves together, the snap-fit clips lock automatically", and
on the safety page "do not force printed parts together if tolerances
feel tight, light sanding usually solves the issue". Measured in the
STEP: seam at 8.0 above the back's outer floor; front legs drop 2.6–3.0
below it at the corners only, 2.0 thick, 0.10 drawn gap to the corner
block, 0.1 lip; back corner blocks rise 2.2 above the seam. So it is a
corner friction fit that depends on print growth — hand-fitted by design.
Back floor is solid (no header slot). Battery 602530. A corner coupon cut
from Pala's unmodified STEP is at `~/Desktop/027 Pala Note/coupons/` for
an A/B against concept D on the A1 mini.

## Pala case printed, 2026-09-23

Pala's own case V1.0, printed unmodified on the A1 mini: **it clicked and
held.** So a corner press-fit does work on this printer, and concept D's
failure (seated, no hold) was our copy, not the principle. Differences
between concept D as drawn and Pala's joint as measured in its STEP:
leg 2.20 vs 2.00 thick; the D coupon was a single corner with nothing
locating it, Pala's is four corners tied by full walls; and Pala's back
corner block also rises 2.2 above the seam inside the front's wall.

Using Pala's case for the MVP. First defect: its printed buttons are too
short for our Touch V2 board — the stem does not reach the switch and the
button is not held once the case is closed. Pala's button: 7.0 x 4.8 flange
2.3 thick inside the wall, 4.8 square cap through a 2.25 wall, 1.2 proud.
Ladder exported to `~/Desktop/027 Pala Note/coupons/button_plus{050..200}`
(flange face extended inward 0.5/1.0/1.5/2.0, notch count = step).
