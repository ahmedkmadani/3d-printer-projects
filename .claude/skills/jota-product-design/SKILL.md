---
name: jota-product-design
description: Design and change Jota as a physical product — the 3D-printed enclosure, how it feels in the hand, how it prints, and how the case relates to the device UI. Use whenever the work touches jota/src (build123d CAD), the enclosure, part fit, printability, the button, the e-paper window, the battery, or a new board revision. Also use when judging whether a change to the case is worth making.
---

# Jota as an object

Jota is a pocket voice recorder: press once, speak, press again. The case
exists to make one button findable without looking, hold a 1.54" e-paper panel
where you can read it, and survive being in a pocket with keys.

Read `jota/docs/problem.md` before proposing anything. If a change to the case
cannot be traced to something on that page, it is decoration.

## The pipeline — never skip a step

```bash
cd /home/ahmedk/Desktop/3d-printer-projects
.venv/bin/python jota/src/validate.py     # MUST pass before exporting
.venv/bin/python jota/src/export.py       # -> models/stl, models/step, .3mf
.venv/bin/python jota/src/render.py       # -> renders/*.png
```

`validate.py` is the gate, not a formality. Export without it and you can
produce a case that cannot be assembled, which costs hours of print time to
discover.

## Where the numbers live

Every dimension is a named constant in `jota/src/params.py`. Never write a
number into `base.py` or `lid.py` — a magic number there is a dimension nobody
can find again.

Each constant carries its provenance:

- `[datasheet]` — from the panel or component datasheet. Trust it.
- `[case-meas]` — measured off the real board or the reference case.
- `GUESS:` — **not verified**. Treat as a risk, not a fact.

When you add a constant, mark it the same way. When you verify a `GUESS:`,
change the marker and say what you measured it with.

## Standing risks — check these before touching geometry

- **`SWITCH_TIP_X = 17.05` is still a guess**, and it drives BOTH the button
  travel and the PCB's +X datum. Measure it before any final print. If the
  button feels wrong on real hardware, suspect this first.
- **`validate.py` has no minimum-feature-width check and no overhang check.**
  Three real defects got past it: flat 90° overhangs at the PCB seat, an
  86%-blocked speaker grille, and 0.1 mm skirt slivers a slicer flagged as
  floating regions. Adding those two checks is the highest-value work on the
  CAD side — see `jota/docs/decisions.md`.
- **PETG is required, not preferred.** The snap cantilevers bend normal to the
  layer planes, the weak direction, at 1.11% strain after redesign. PLA will
  crack.

## Rules the geometry already obeys — break them only deliberately

- **Two snaps, not four.** Four could not be released without breaking the
  case, which also meant the battery could never be replaced. Two on the long
  `-X` wall with a 30° release angle. (decisions.md #7)
- **Rim edges are chamfers, not fillets.** Both faces print on the bed, where a
  fillet flares from a horizontal tangent — at R=2 the first 0.2 mm layer
  overhangs by ~0.87 mm and droops. A true pillowed edge needs supports.
- **The plunger goes in from inside, before the board.** Retention has to be
  inboard, so the board traps it. As a dumbbell it could not be fitted from
  either direction; deleting the flange gave zero travel because the switch's
  own spring ejects it.
- **Keep 4 px clear of every screen edge.** The lid window crops the 27 mm
  active area, so anything closer is cropped in the hand even though it renders
  fine on the contact sheet.

## The physical design language

It is the same language as the screens (`jota/docs/brand.md`), in plastic:

- It reads as a **pebble** — an 8 mm vertical corner radius is what does that.
  Protect it.
- Nothing sharp, nothing that catches in a pocket.
- One button you can find by touch, without looking. That is the product.
- Warm, matte, quiet. PETG in bone, espresso, clay or sage — the palette in
  `brand.md`, in filament.

## Radio, because plastic hides it

The ESP32-S3 antenna is a PCB trace and the LiPo sits beside it. A battery
pouch is a metal bag: over the antenna it detunes and shadows it. **If range
disappoints, check battery placement before blaming firmware.** PETG itself is
nearly transparent at 2.4 GHz and costs almost nothing.

## Judging a proposed change

Ask, in this order:

1. Which line of `problem.md` does this serve?
2. Does it survive a pocket, and can it still be printed without supports?
3. Does it keep the battery replaceable?
4. Does it change a `GUESS:` number into a dependency? If so, measure first.
5. Can `validate.py` prove it, or is it only true in the render?

If a change is only defensible in a render, it is not yet true.

## Renders are for review, not proof

`render.py` uses matplotlib, which sorts whole triangles by average depth. On
interlocking geometry that ordering is simply wrong — the base painted over the
lid and a closed case came out looking like an open tray. For product shots use
the z-buffer renderer pattern in `jota/app/tool/` (per-pixel depth), and
remember a picture is not a fit check: `validate.py` is.

## Board revision notes

Collected from real use, for whenever the board is revisited:

- **No reset button.** Every flash is hold-BOOT-press-PWR, and "is it even on?"
  is hard to answer.
- **No battery-sense pin.** The gauge is built and switched off; everything
  downstream reports *unknown* rather than a figure.
- **You cannot tell a powered device from a dead one by looking.** E-paper holds
  its last frame forever, so a screen showing a pair code proves nothing. Cost
  an hour once already.
- **USB power alone does not start it** — the soft latch needs a PWR press.
