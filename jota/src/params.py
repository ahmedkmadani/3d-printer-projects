"""All enclosure parameters in one place. Units: mm.

Target hardware: Waveshare ESP32-S3-ePaper-1.54 board (1.54" 200x200
e-paper AIoT board: mic, ES8311 codec, SD slot, LiPo charger, SHTC3,
PCF85063 RTC, ETA6098 PMIC) + 3.7 V 503035 LiPo.

The unit actually in hand is the TOUCH variant, silkscreen
"ESP32-S3-Touch-ePaper-1.54", rev V2 — the same product, same page, same
stock case, plus an FT6336 touch controller. Waveshare sells both from
https://www.waveshare.com/esp32-s3-epaper-1.54.htm . If the touch layer makes
the display stack thicker than DISPLAY_RAISE below, that is the number to
re-measure first.

Dimension provenance, three tiers:
  [datasheet]  published number, citation given
  [case-meas]  measured by OCCT section analysis of the Pala Note case STEP
               (thegilbertchan/pala-note hardware/Assembled.step), used as a
               dimensional reference only — Waveshare publishes no bare-PCB
               drawing for this board
  # GUESS:     neither of the above; also collected in README.md

Coordinate system used throughout the project:
  origin = center of the PCB outline, on the interior floor plane
  X      = board width axis; +X is the button/SD edge ("right")
  Y      = board length axis; +Y is the speaker edge ("top"),
           -Y is the USB edge ("bottom")
  Z      = up out of the base; Z=0 is the interior floor surface
           (base tray holds battery + board, lid carries the window)
"""

import math

# ---------------------------------------------------------------------------
# Global print / fit parameters
# ---------------------------------------------------------------------------
CLEARANCE = 0.25          # printed-to-printed sliding fits: lid skirt, snaps

# The board pocket is a DIFFERENT fit and now has its own number. It used to
# share CLEARANCE, which meant the only way to loosen the board was to loosen
# the lid and the snaps with it.
#
# 0.25/side was proved too tight by a print: the board fouled the locating
# rails and would not drop onto its ledges. It was not a modelling error —
# validate showed 0.000 mm3 of obstruction and exactly 0.25 of slack, with no
# margin for vertical walls printing proud, which they always do. A rigid PCB
# in a printed pocket needs room for the process, not just for the part.
# [measured off the first print 2026-08-29] The cavity came out 47.0 between
# the end stops against a 47.50 nominal, on a 47.0 board: zero slack, which is
# why it jammed and sat tilted. The print loses 0.25 PER WALL to proud vertical
# surfaces, so a nominal clearance only half buys real clearance:
#
#     0.25  the fit we actually want
#   + 0.25  what the process takes
#   = 0.50  what has to be drawn
#
# 0.40 was an intermediate guess and would have left 0.15 of real room, which
# is still not a drop-in fit. This is now derived from a measurement of a real
# printed part rather than from a tolerance table.
PCB_CLEARANCE = 0.50      # [print-derived 2026-08-29] was CLEARANCE (0.25)
# ---------------------------------------------------------------------------
# Variants. Set C1_VARIANT=header in the environment to build the case for a
# board that still carries its stock 2x6 header (owner's call, 2026-08-31:
# desoldering risks the board). Everything that differs derives from this one
# switch so the two builds cannot drift apart. The plain build is the default.
# ---------------------------------------------------------------------------
C1_VARIANT = __import__("os").environ.get("C1_VARIANT", "")
# The speaker is OFF by default (owner, 2026-08-31: "no need for the speaker
# for now"). C1_SPEAKER=1 restores the bay, the grille and the tongue relief
# over it. With it off the +Y end is a plain closed wall and the tongue runs
# the full length of that end.
C1_SPEAKER = __import__("os").environ.get("C1_SPEAKER", "0") == "1"

NOZZLE = 0.4              # SET THIS to the nozzle actually fitted. Every
                          # minimum-feature check downstream is derived from
                          # it, so a wrong value here silently passes parts
                          # the printer cannot make.
                          # The printer is a Bambu Lab A1 mini (Bambu Studio
                          # config, 2026-08-31). Stock hotend is 0.4. The
                          # slicer has been left on the "A1 mini 0.2 nozzle"
                          # preset at least once, which is where a "nozzle
                          # does not match" warning comes from when a 0.4
                          # project is opened. The hotend has its size
                          # engraved on it; the printer's own Settings screen
                          # shows it too. Confirmed 0.4 by the user on
                          # 2026-08-31, so PROCESS_PROUD (measured 08-29)
                          # stands.
LAYER_H = 0.2

# What a nozzle can and cannot resolve. Used by check_case1.py so that the
# limits move when the nozzle does, instead of being written into the checks.
EXTRUSION_W = NOZZLE * 1.125          # typical slicer default for a wall line
MIN_WALL_TRACE = NOZZLE               # one trace: printable, but weak
MIN_WALL_SOLID = 2 * EXTRUSION_W      # two perimeters, no gap fill
MIN_GAP = NOZZLE                      # a slot narrower than this fills in
MIN_FEATURE = 0.8
PLA_DENSITY = 1.24        # g/cm^3

# ---------------------------------------------------------------------------
# Material. This is not a note, it sizes the snaps: STRAIN_LIMIT is the design
# allowable for a cantilever printed so it bends NORMAL TO THE LAYER PLANES,
# which is the weak direction and far below the handbook figures for the same
# polymer moulded. Printed PLA elongates ~0.8-1.5 % in Z and PETG ~2-4 %; the
# allowables below take roughly half the low end, because the snaps are cycled
# every time the battery is changed and the 1-D beam formula ignores the stress
# concentration at the root.
#
# Set MATERIAL and validate.py gates SNAP_STRAIN against it. Switching to PETG
# does not require retuning — it just leaves margin on the table.
# ---------------------------------------------------------------------------
MATERIAL = "PLA"
STRAIN_LIMIT = {"PLA": 0.006, "PETG": 0.020}[MATERIAL]

# ---------------------------------------------------------------------------
# Board: Waveshare ESP32-S3-ePaper-1.54
# Published data: case 39.8 x 53.0 x 16.9, window 27.8 sq @ 14.3 from bottom,
#   screws 28.1 apart (https://docs.waveshare.com/ESP32-S3-ePaper-1.54);
#   1.54" V2 panel active area 27.00 x 27.00, outline 37.32 x 31.80 x 1.05
#   (https://files.waveshare.com/wiki/common/1.54inch_e-paper_V2_Datasheet.pdf)
# Everything about the bare PCB below is [case-meas] unless marked.
# ---------------------------------------------------------------------------
# [measured 2026-08-28, calipers on the rev-V2 board] --------------------
# PCB_L was 39.0, taken by sectioning the Pala Note reference STEP. The real
# board is 47. That is the whole disaster: the interior allowed the PCB 39.5
# of length, the board needed 47.5, so it sat on the rim and never seated.
# The stock 2x6 header made it worse but was never the cause.
# The measurements corroborate each other: 47 - 4 (ear) = 43 = the hole pitch
# M5, and 33 - 27 (hole pitch M4) = 6 = 3.0 in from each side.
PCB_W = 33.0              # [measured] unchanged - the old value was right
PCB_L = 47.0              # [measured] was 39.0 [case-meas]. +8.0
PCB_T = 1.6               # GUESS: standard FR4. M16 came back as 5, which is
                          # not a credible FR4 thickness - re-measure.

# Mounting holes. Now real numbers, not a claim that they do not exist.
# CORRECTED 2026-08-30 from two reference case STLs. The caliper reading of
# 27.0 disagreed with Waveshare's own drawing (SCREW_SPACING_X 28.10) by 1.10,
# and the peg datum can only absorb 0.30. A third-party printed case for this
# board puts its four screw holes at EXACTLY 28.000 x 43.200 — independent of
# both. Two sources against one: the 27.0 was a bad reading.
HOLE_PITCH_X = 28.00      # [ref-case + datasheet] was [measured] 27.0. See above.
HOLE_PITCH_Y = 43.20      # [ref-case] was [measured] 43.0 — agrees to 0.20
EAR_PROUD = 4.0           # [measured] ears stand past the body's top edge
HOLE_D = 2.2              # GUESS: not measured (M3 blank). M2 screws assumed

# Reverted to the datasheet 2026-08-28. The [measured] 29.0 claimed the bonded
# module is narrower than the bare panel, which cannot be true: 31.80 is the
# TFT outline (glass), and bonding it to a board does not shrink it. 29.0 was
# most likely the visible white area read through the stock case window.
# It mattered: the lid bezel ring is 31.00 outer / 28.00 inner, so against a
# 29.0 panel sanity() reported 0.50 mm of bearing per side with the ring
# overhanging air. Against the real 31.80 — which carries a symmetric 2.40
# border around the 27.00 active area — the ring bears 1.90 per side, landing
# centred on that border. The wrong number made the design look worse than it
# is; the interference check is 0.00 mm3 either way.
PANEL_W = 31.80           # [datasheet] TFT OD, +/-0.1
PANEL_L = 37.32           # [datasheet] TFT OD
PANEL_T = 1.05            # [datasheet] bare panel D. Unused by geometry - the
                          # modelled stack height is DISPLAY_RAISE, not this.
ACTIVE = 27.0             # [datasheet] active area, square

# Display module front face sits raised above the PCB front (panel + spacer
# + connector). Was [case-meas], sectioned off the Pala Note reference STEP -
# the same source that gave PCB_L = 39.0 against a real 47.0, so it was the
# least trustworthy number in the whole Z stack.
#
# [measured 2026-08-28] the board in hand reads ~4.0, coarse. Two things that
# buys: it is a read on the TOUCH variant, so the FT6336 layer the enclosure
# never accounted for is now inside the figure; and 4.2 is confirmed as the
# right order, not a reference-case artefact.
#
# The modelled value STAYS 4.2, deliberately. RIM_Z = PCB_FRONT_Z +
# DISPLAY_RAISE + PANEL_LID_GAP, so this number decides whether the lid bezel
# clears the panel or presses it, and the read is coarser (+/-0.2) than the
# 0.25 gap it feeds. At 4.2 the lid only touches glass if the true raise
# exceeds 4.45 - 0.45 of headroom, worst case ~0.5 of rattle. Dropping to 4.0
# moves contact to 4.25, which "about 4" could plausibly be. Rattle is
# recoverable; crushing e-paper glass with a printed bezel is not.
#
# Tighten it by measuring PCB front face -> panel front face with a depth gauge
# and setting PANEL_LID_GAP from the result, rather than by trimming this.
DISPLAY_RAISE = 4.2       # [measured ~4.0, held at 4.2 - see above]

# Window / active-area center relative to PCB center. [case-meas]:
# case window center (-1.45,-11.7); PCB center in case frame (-2.0,-14.7).
# [derived 2026-08-28 from Waveshare's published stock-case outline]
# Case 39.80 x 53.00; window 27.80 square, 14.30 up from the case bottom.
# With the real PCB at 33 x 47 the board sits 3.40 / 3.00 in from the case
# walls, so the window spans 11.30..39.10 above the PCB bottom edge — centre
# 25.20 against a PCB centre of 23.50. Supersedes the old [case-meas] pair,
# which was measured against a 39 mm board and is therefore meaningless.
# Assumes the board is centred in its case and the window centred on the
# active area; both are visible in the drawing but neither is dimensioned.
ACTIVE_CTR_X = 0.0        # [derived] window centred across the board
ACTIVE_CTR_Y = 1.7        # [derived] was 3.0

# Back-side components (SD holder, USB-C shell, RTC...) — keepout depths
# below the PCB back face:
BACK_CLEAR_MID = 1.5      # GUESS: small parts over the battery zone
BACK_CLEAR_EDGE = 3.5     # GUESS: USB shell / SD holder at the bottom/right edges
# ---------------------------------------------------------------------------
# The stock 2x6 female expansion header.
#
# This used to be a comment and nothing else, so nothing enforced it and the
# first real build was assembled with the header still fitted. The board then
# sat ON the rim instead of dropping in, and the case was blamed. It is now a
# keepout solid (components.header) that validate.py checks like any other, so
# leaving it fitted FAILS the build instead of failing the assembly.
#
# It cannot be designed around. The header stands HEADER_H off the PCB back
# face, which is more than the whole PCB_BACK_Z gap, so it must either pass
# through the floor (as it does in Waveshare's own case, which slots the back)
# or come off. Sinking the floor is not an escape either: the header's plan
# footprint is inboard of the -X wall and the 503035 battery is 30.5 of the
# 36.7 interior width, so the two overlap in plan no matter how deep the case
# gets. Set HEADER_FITTED = True and validate.py will print exactly that
# overlap rather than take this paragraph's word for it.
#
# So: desolder it, or fit a smaller cell than the 503035.
HEADER_FITTED = C1_VARIANT == "header"   # the header variant models it on
HEADER_W = 5.08           # [datasheet] 2 rows x 2.54 pitch, body across
HEADER_L = 15.24          # [datasheet] 6 ways x 2.54 pitch, body along
HEADER_H = 9.0            # [measured] M18, tallest thing on the back face
# [derived] Waveshare's outline drawing dimensions the header opening in the
# case back: 16.50 tall, 16.10 up from the case bottom, and 22.00 / 12.60 in
# from the case sides (39.80 - 22.00 - 12.60 = 5.20 ~ the 5.08 header body).
# With the board sitting 3.00 / 3.40 inside the case, the vertical figure maps
# cleanly onto the board; the horizontal one depends on which way the back
# view is mirrored, which the drawing does not say, so X stays a GUESS.
HEADER_CTR_X = -13.0      # GUESS: -X side. Drawing implies |x| ~ 4.7 if the
                          # back view mirrors, ~13 if it does not.
HEADER_CTR_Y = -2.15      # [derived] header spans 13.10..29.60 above the PCB
                          # bottom edge; PCB centre is 23.50

# Interfaces, PCB-frame positions [case-meas]:
# Waveshare's published outline drawing, stock case (not the bare PCB):
#   case 39.80 x 53.00 x 16.90, corners R4.50
#   window 27.80 square, 14.30 up from the case bottom
#   case screws 28.10 apart  <- the board really does have mounting holes
SCREW_SPACING_X = 28.10   # [datasheet] stock-case screw pitch across the board

# [measured] PWR 9.0 and BOOT 19.0 up from the bottom edge; with PCB_L 47 the
# centre is 23.5, so these are 9.0-23.5 and 19.0-23.5.
BTN1_CTR_Y = -14.5        # [measured] PWR, on the +X (right) edge
BTN2_CTR_Y = -4.5         # [measured] BOOT
BTN_CAP_W = 7.0           # reference cap size (Y) — ours match
BTN_CAP_H = 4.8           # reference cap size (Z)
SD_CTR_Y = 10.5           # [photo 2026-08-31] holder centre 9-11 mm toward
                          # +Y, ON THE +X (BUTTON) EDGE — same wall as BOOT
                          # and PWR. Kept at 10.5, inside the estimate. The
                          # 17 mm slot covers the 14 mm holder either way.
SD_SLOT_L = 14.0          # [measured] was 12.2 [case-meas]
SD_SLOT_H = 2.8           # [case-meas] slot height (Z)
USB_CTR_X = 0.8           # USB opening center on the -Y (bottom) edge
USB_OPEN_W = 9.0          # [case-meas] core opening width (fits plug overmolds)
USB_OPEN_H = 7.0          # opening height; generous like the reference
MIC_CTR_X = -8.15         # mic pinhole on the bottom edge
LED_CTR_X = 8.8           # LED light-pipe hole on the bottom edge
PINHOLE = 2.0             # [case-meas] 2x2 square in reference; we use round d=2
SPK_CTR_X = 0.8           # speaker pocket center (X), just beyond the +Y PCB edge
SPK_CTR_Y = PCB_L / 2 + 4.25   # speaker seated against the grille wall,
                          # behind the rib. Anchored on the PCB top edge so it
                          # tracks PCB_L instead of freezing at 23.75.
SPK_L = 16.0              # [case-meas] oval speaker pocket
SPK_W = 5.0
SPK_GRILL_SLOTS = 4       # [case-meas] 0.8 x 4.0 slits in the wall
SPK_SLOT_W = 1.0
SPK_SLOT_H = 4.0
SPK_SLOT_CTR_Z = 7.0      # shared by the base wall and the lid skirt
SPK_SLOT_PITCH = 2.0      # 1.64 left 0.84 mm pillars — under 2 perimeters

# ---------------------------------------------------------------------------
# Battery: 503035 LiPo w/ PCM (Pala build uses 500 mAh — Hackster).
# Datasheet: https://www.lipolbattery.com/LiPo-Battery-Datahseet/LiPo_Battery_LP503035_3.7V_500mAh.pdf
# Pack length INCLUDING PCM/tab fold is 36+/-1 (naming says 35). Max envelope:
# ---------------------------------------------------------------------------
# Plain build: 503035. Header build: 602535 (6 x 25 x 35, also 500 mAh) —
# a 30.5-wide cell cannot sit beside a header at x -15.5..-10.5 in a 37.9
# cavity, and widening the cavity moves the tongue, i.e. a new front and
# longer pins. A 25-wide cell keeps both. [datasheet] envelopes, both.
BATT_L = 35.0 if HEADER_FITTED else 37.0     # along Y
BATT_W = 25.0 if HEADER_FITTED else 30.5     # along X
BATT_T = 6.0 if HEADER_FITTED else 5.3
BATT_CTR_X = -1.0         # biased away from the SD-holder edge
BATT_CTR_Y = 1.0          # clear of the USB edge zone (Y < -31 stays empty)

# ---------------------------------------------------------------------------
# Vertical stack (Z=0 interior floor)
#   battery on floor -> margin -> PCB back -> PCB -> display -> bezel gap
# ---------------------------------------------------------------------------
PCB_BACK_Z = BATT_T + 2.2          # 7.5: SD holder (~1.9) fits over the battery
PCB_FRONT_Z = PCB_BACK_Z + PCB_T   # 9.1
PANEL_FRONT_Z = PCB_FRONT_Z + DISPLAY_RAISE   # 13.3
PANEL_LID_GAP = 0.25
RIM_Z = PANEL_FRONT_Z + PANEL_LID_GAP         # 13.55: base rim = lid underside

# USB-C position check: the receptacle is on the PCB BACK face at the -Y
# edge; opening centered on the PCB back plane:
USB_CTR_Z = PCB_BACK_Z - 1.65      # GUESS: shell ~3.3 tall on the back face
                                   # (mid-shell). Opening is 7.0 tall, so
                                   # +/-2 of placement error is absorbed.

# ---------------------------------------------------------------------------
# Enclosure structure
# ---------------------------------------------------------------------------
WALL_T = 2.4
FLOOR_T = 2.0
# 2.8, not 2.0: RIM_CHAMFER 1.6 on a 2.0 mm plate leaves only 0.40 mm at the
# outer face — below one extrusion width, and exactly where the snap
# cantilevers root into the plate.
LID_T = 2.8
# Outer vertical edges. This is the parameter that decides whether the case
# reads as a box or as a pebble — it is ~19% of the 41.5 mm width at 8.0.
# Vertical edges print cleanly at any radius in either part's orientation.
EDGE_FILLET_R = 8.0

# Top and bottom rims. These MUST stay chamfers, not fillets: the base prints
# floor-down and the lid prints top-face-down, so both of these edges sit ON
# THE BED. A true fillet there flares outward from a horizontal tangent — at
# R=2 the first 0.2 mm layer would overhang the one below it by ~0.87 mm and
# droop. A 45 degree chamfer steps out 0.2 mm per layer and is self-supporting.
RIM_CHAMFER = 1.6

# Board support. NOTE, corrected 2026-08: an earlier comment here claimed the
# PCB has "no usable mounting holes". That was wrong. Waveshare's own outline
# drawing dimensions the stock case screws at SCREW_SPACING_X = 28.10 apart and
# the board carries four corner holes; the stock case screws INTO them. We
# still clamp rather than screw, because the hole positions relative to the PCB
# outline are not published and have not been measured — see MEASURED_TODO.
# Ours: four corner posts with seat ledges under the PCB back + side locating
# nubs; the lid bezel presses the display stack down.
POST_SEAT_Z = PCB_BACK_Z
POST_W = 5.0              # square posts at the four PCB corners
PCB_CORNER_GRIP = 2.5     # how far the seat ledge reaches under the PCB edge

# Interior: PCB + posts behind each edge + speaker bay beyond +Y edge
IN_W = PCB_W + 2 * PCB_CLEARANCE + 2 * 1.6     # side nub/post structure per side
SPK_BAY = SPK_W + 2.0                      # speaker pocket depth beyond PCB edge
IN_L = PCB_L + 2 * PCB_CLEARANCE + SPK_BAY + 1.6
IN_CTR_Y = (SPK_BAY - 1.6) / 2 + 0.0       # interior center shifted toward +Y

OUT_W = IN_W + 2 * WALL_T
OUT_L = IN_L + 2 * WALL_T
OUT_H = FLOOR_T + RIM_Z + LID_T

# ---------------------------------------------------------------------------
# Snap-fit closure (same architecture as validated for the earlier variant):
# lid skirt wraps OUTSIDE the base wall; top SKIRT_DEPTH of the base wall is
# rebated by (SKIRT_T + CLEARANCE) so the closed lid sits flush. Barbs on the
# base engage through-windows in discrete skirt panels (slotted, so each snap
# is a true cantilever, not a hoop).
# ---------------------------------------------------------------------------
# Retuned for PLA 2026-08-29. Strain goes as 1.5*t*y/L^2, so the skirt got
# thinner (t) and the engagement deeper (L, quadratic). Thinning the skirt also
# WIDENS the rebated wall, 0.95 -> 1.25, because REBATE tracks SKIRT_T — the one
# place where the PLA retune makes the base stronger rather than weaker.
SKIRT_T = 0.9             # was 1.2
SKIRT_DEPTH = 11.5        # was 10.0; >= SNAP_ENGAGE_DEPTH + 1.0
REBATE = SKIRT_T + CLEARANCE
REBATED_WALL = WALL_T - REBATE            # 1.25 >= MIN_FEATURE

# Deflection is a FIRST-CLASS parameter, not a by-product of CLEARANCE.
# It used to be (SNAP_BARB_H - CLEARANCE), which meant loosening a sliding fit
# silently reduced both snap deflection and retention.
# Deflection and retention are the SAME number: the skirt must flex past the
# barb to seat, so whatever it deflects is exactly how far the barb then sits
# past the skirt inner face. That is why this cannot simply be reduced to buy
# strain — validate.py holds it at >= 0.4. 0.42 keeps a little margin over that
# floor while taking 16 % off the strain.
SNAP_DEFLECT = 0.42                       # was 0.50
SNAP_BARB_H = SNAP_DEFLECT + CLEARANCE    # clearance is taken up first
SNAP_BARB_L = 8.0

# The window's lower edge is the retaining surface AND a printed bridge (the
# lid prints top-face-down). Bridge sag closes the gap onto the barb, so the
# window is oversized downward to give the sag somewhere to go.
SNAP_WINDOW_H = 2.3
SNAP_WINDOW_DROOP = 0.30                  # window bottom sits this far below
                                          # the barb catch face
SNAP_WINDOW_L = SNAP_BARB_L + 2 * CLEARANCE

# Cantilever length L. The lid prints top-face-down, so these beams bend
# NORMAL TO THE LAYER PLANES — the weak direction. Printed PLA elongates only
# ~0.8-1.5 % in Z and PETG ~2-4 %, so the 2 % handbook figure (moulded,
# isotropic, single assembly) is far too generous here. L 7 -> 9 takes strain
# from 1.84 % to 1.11 %, inside PETG's range with margin for the stress
# concentration at the root that the 1-D formula ignores.
# 2026-08-29: 9.0 -> 10.5 for PLA. L is the only quadratic lever, so it does
# most of the work here: 1.11 % -> 0.51 %. The cost is visible, not structural —
# the skirt now covers 11.5 of the 13.55 mm side, so the lid reads as most of
# the case. Accepted deliberately; the alternative is a case that cracks.
SNAP_ENGAGE_DEPTH = 10.5

# Panel width. Force scales with w, and at w=18/L=7 closing the lid needed an
# estimated ~150 N in PLA — you would bow the plate before the snaps deflected.
SNAP_PANEL_L = 11.0
SNAP_SLOT_W = 1.2

# Catch back-angle. A 0 degree (flat) catch cannot be cammed out at all, and
# with barbs on two perpendicular walls the case could only be opened by
# breaking it — which also meant the LiPo could never be removed. 30 degrees
# retains firmly but releases under deliberate pull.
SNAP_RELEASE_ANGLE = 30.0

SNAP_STRAIN = 1.5 * SKIRT_T * SNAP_DEFLECT / SNAP_ENGAGE_DEPTH**2

# Snap locations: (wall, center along that wall). The -Y wall gets none —
# its center belongs to the USB opening (that edge is the natural thumb-
# opening point). Positions chosen clear of the speaker grille slits.
# -X only. The +Y wall cannot carry a snap: its skirt is limited to |x| <=
# 12.75 by EDGE_FILLET_R, and the speaker grille occupies x -2.70..4.30, so a
# panel would need c >= 11.40 to clear the grille but c <= 6.65 to stay on the
# skirt. Forcing both sets of cuts onto that wall left 0.1 mm slivers of skirt
# between them — thinner than one extrusion, which is what a slicer reports as
# floating regions.
#
# Dropping them is right regardless: four catches on two perpendicular walls
# could not be released (you cannot flex +Y while lifting -X), so the case
# could only be opened by breaking it, and the LiPo could never be replaced.
# Two snaps on the long -X wall plus full skirt engagement on three sides
# retains a 30 g device and gives a defined opening motion.
#
# Follow-up: a rigid hook lip on +Y, engaged by tilting the lid in, would
# restore positive retention on that edge without a flexing cantilever.
SNAPS = [("-X", -7.0), ("-X", 12.0)]

# ---------------------------------------------------------------------------
# Lid window: opening = active area + reveal; bezel overlaps the panel border
# ((PANEL-ACTIVE)/2 ~ 2.4 sides) hiding panel edge and driver border.
# ---------------------------------------------------------------------------
WINDOW_REVEAL = 0.5
WINDOW = ACTIVE + 2 * WINDOW_REVEAL       # 28.0 square (reference case: 27.8)
WINDOW_CHAMFER = 1.0

# Button plungers through the lid skirt/base wall on the +X edge: separate
# printed pins (filament-agnostic, replaceable; a printed-in-place flexure
# would hinge across layer lines here). Same 3-tier bore as the reference.
# The plunger is a flanged pin, installed from INSIDE, before the board.
#
# History worth keeping: it was first a dumbbell (cap and flange both wider
# than the bore) which could not be fitted from either direction. "Fixing" it
# by deleting the flange and inserting from outside produced two new faults —
# the cap bottomed in its recess at the exact moment the stem met the switch,
# so there was ZERO press travel, and nothing resisted the switch's own return
# spring, so the pins ejected.
#
# The flange has to be inboard (it is what stops the switch pushing the pin
# out) and therefore the pin must go in from inside, before the board traps
# it. Everything outboard of the flange must pass through the bore.
BTN_BORE_D = 4.4
BTN_STEM_D = 3.6          # 0.40 radial nominal; a horizontally-printed bore
                          # comes out undersize and out-of-round at the crown,
                          # so the effective fit is ~0.25
BTN_HEAD_D = 4.0          # < BORE: must pass through during installation
BTN_HEAD_PROUD = 0.8      # stands proud of the wall, and stays proud through
                          # the full press stroke
BTN_FLANGE_D = 5.6        # > BORE: the outward stop
BTN_FLANGE_L = 1.0
BTN_POCKET_D = 6.0        # flange pocket bored into the boss from inside

# Free travel is the DESIGN INTENT and is now stated once. It used to be an
# accident: BTN_POCKET_L was the literal 1.3 and BTN_FREE_TRAVEL = 0.30 sat
# here driving nothing, so the real 0.30 was whatever 1.3 - 1.0 happened to be.
# Two numbers encoding one intention, with nothing keeping them agreed - edit
# the pocket and the travel silently changes.
#
# The pin rests with its flange face this far outboard of the switch tip, so
# a press is 0.30 of nothing followed by 0.25 of switch. It must be > 0, or
# the pin holds the button down for ever.
BTN_FREE_TRAVEL = 0.30    # pin motion before it meets the switch
BTN_SWITCH_TRAVEL = 0.25  # tactile switch actuation
BTN_POCKET_L = BTN_FLANGE_L + BTN_FREE_TRAVEL      # [derived] 1.30
BTN_CTR_Z = PCB_BACK_Z - 1.0   # GUESS: switch bodies on the PCB back edge
# [measured 2026-08-29] span across the board at the PWR line, far PCB edge to
# actuator tip, read ~34.0 -> 34.0 - PCB_W/2 = 17.50. Was 17.05 (GUESS), which
# put the tip 0.15 OUTBOARD of the pin's rest face: the printed pin would have
# held PWR down permanently. On a board with no reset button and an e-paper
# that keeps its last frame, that is a fault with almost no symptom.
#
# The read is coarse. The set value tolerates a true tip of 17.25..17.80
# (span 33.75..34.30): below that the stroke exceeds BTN_HEAD_PROUD and the cap
# sinks into the bore before the switch actuates; above it the free travel is
# gone. Re-measure carefully before a final print.
#
# It cannot simply be raised further. The boss spans SWITCH_TIP_X..IN_W/2, so
# it is 0.85 mm here and reaches MIN_FEATURE at 17.55. Past that the interior
# has to grow — validate.py now gates this instead of leaving it to be found
# in a print.
SWITCH_TIP_X = 17.50      # [measured ~34.0 span] tip 1.00 beyond the PCB edge

# The boss reaches inward from the wall to the switch tip and stops there - it
# cannot go further without fouling the actuator, so this is a physical ceiling,
# not a free choice. Was a dead literal 3.2 while base.py computed the real
# value by subtraction; that is why moving SWITCH_TIP_X could thin the boss to
# nothing with no constant showing it. validate.py gates it against MIN_FEATURE.
BTN_BOSS_T = IN_W / 2 - SWITCH_TIP_X               # [derived] 0.85

# Derived opening heights (interfaces live relative to the PCB planes)
MIC_CTR_Z = 9.0           # [case-meas] pinhole straddles the PCB front plane
LED_CTR_Z = 9.0           # [case-meas]
SD_CTR_Z = PCB_BACK_Z - 0.8    # [case-meas] SD holder on the PCB back face

# Interior Y extents (asymmetric: speaker bay beyond the +Y PCB edge)
IN_Y_MIN = -(PCB_L / 2 + PCB_CLEARANCE + 1.6)
IN_Y_MAX = PCB_L / 2 + PCB_CLEARANCE + SPK_BAY
BARB_CATCH_Z = RIM_Z - SNAP_ENGAGE_DEPTH   # flat catch face height on the base

def sanity() -> list[str]:
    lines = []
    ok = True

    lines.append(f"Exterior: {OUT_W:.1f} x {OUT_L:.1f} x {OUT_H:.1f} mm "
                 f"(reference case: 44.9 x 58.4 x 16.2)")
    lines.append(f"Interior: {IN_W:.1f} x {IN_L:.1f}, depth {RIM_Z:.2f} mm")

    lines.append(
        f"Snap strain eps = 1.5*t*y/L^2 = 1.5*{SKIRT_T}*{SNAP_DEFLECT}/{SNAP_ENGAGE_DEPTH}^2 "
        f"= {SNAP_STRAIN*100:.2f} %  (limit 2 %; deflection = barb {SNAP_BARB_H} "
        f"- clearance {CLEARANCE})")
    ok &= SNAP_STRAIN < 0.02

    lines.append(f"Rebated wall = {REBATED_WALL:.2f} mm (min feature {MIN_FEATURE})")
    ok &= REBATED_WALL >= MIN_FEATURE

    lines.append(
        f"Stack: battery 0..{BATT_T} | PCB back {PCB_BACK_Z} | PCB front {PCB_FRONT_Z} "
        f"| panel front {PANEL_FRONT_Z} | rim {RIM_Z}")
    ok &= PCB_BACK_Z - BATT_T >= BACK_CLEAR_MID + 0.5  # SD holder margin over battery

    lines.append(
        f"USB opening {USB_OPEN_W} x {USB_OPEN_H} centered Z={USB_CTR_Z:.2f} "
        f"(PCB back at {PCB_BACK_Z})")
    ok &= USB_CTR_Z - USB_OPEN_H / 2 > 0.5             # stays above the floor

    ok &= WINDOW < PANEL_W and WINDOW < PANEL_L
    lines.append(f"Window {WINDOW:.1f} sq vs panel {PANEL_W} x {PANEL_L}: "
                 f"bezel overlap {(PANEL_W - WINDOW)/2:.2f} per side (W)")

    batt_top = BATT_T
    lines.append(f"Battery envelope {BATT_W} x {BATT_L} x {BATT_T} at "
                 f"({BATT_CTR_X},{BATT_CTR_Y}); PCB overhang check in validate.py")
    if not ok:
        raise AssertionError("parameter sanity failed:\n" + "\n".join(lines))
    return lines


if __name__ == "__main__":
    print("\n".join(sanity()))


# ===========================================================================
# v2 — FRONT-STRUCTURAL SANDWICH
# ===========================================================================
# The case turned around. The FRONT frame carries the window, the wall and
# every opening; the board lies face-first into it; a flat back cover pushes
# in behind and is held by four tabs cut from its own edge.
#
# Why: every fit failure this project has had was the same failure — a rigid
# PCB located in XY by printed walls, so it inherited the whole clearance
# stack plus process error. Here the walls do not locate the board at all.
#
# Z = 0 is the OUTER FRONT FACE and the part grows +Z, which is also how it
# prints: window-face-down on the bed.
# ---------------------------------------------------------------------------

FACE_T = 2.0              # front face plate, window pierces it
BACK_T = 2.0              # back cover plate

# --- the two datums, deliberately separated -------------------------------
# XY comes from the PANEL, a precision glass part, dropped into a recess.
# Z comes from the PCB FRONT FACE landing on the ledge around that recess.
# Keeping them apart is what lets the board pocket be loose: it locates
# nothing, so its tolerance buys nothing and costs nothing.
# THE RULE, and it is not optional. Measured off a printed part (the base
# cavity came out 47.0 against a 47.50 nominal): every proud vertical surface
# prints 0.25 over. So a pocket loses 0.25 per wall and a peg gains 0.25 per
# wall. A drawn clearance therefore buys you:
#
#   against a BOUGHT part (glass, PCB, cell) — one printed face per side:
#       real = drawn - PROCESS_PROUD
#   against another PRINTED part — two printed faces per side:
#       real = drawn - 2 * PROCESS_PROUD
#
# The first seat coupon was drawn with PANEL_FIT = 0.25 and printed at
# EXACTLY zero: a 32.30 recess became 31.80 for a 31.80 panel. It could not
# go in. Every fit below is now written as what it must END UP as, plus what
# the process is going to take.
PROCESS_PROUD = 0.25      # [print-measured 2026-08-29]

PANEL_FIT_REAL = 0.30     # what the panel must actually have, per side
PANEL_FIT = PANEL_FIT_REAL + PROCESS_PROUD                   # 0.55 drawn
PANEL_RECESS_W = PANEL_W + 2 * PANEL_FIT      # 32.90
PANEL_RECESS_L = PANEL_L + 2 * PANEL_FIT      # 38.42
# A printed internal corner is never sharp — the nozzle leaves a radius there
# — so a sharp-cornered pane meets plastic at four points long before its
# edges touch anything. Same defect the board pocket had, and it has to be
# relieved the same way.
PANEL_CORNER_RELIEF_R = 0.9
# Lead-in at the mouth, so the pane is guided rather than aimed. It opens the
# recess past the board's side edges, which means the board now seats on its
# two -Y/+Y ENDS only. That is deliberate: the sides carried 0.35 of ledge
# before and 0.05 after the fit correction, which was never a seat.
PANEL_LEADIN = 0.5
# Recess DEEPER than the panel stands proud, so the glass never bottoms out
# and never carries clamp load. The load path is plastic on FR4.
PANEL_GLASS_RELIEF = 0.30
PANEL_RECESS_D = DISPLAY_RAISE + PANEL_GLASS_RELIEF          # 4.50
SEAT_Z = FACE_T + PANEL_RECESS_D                             # 6.50

# --- interior --------------------------------------------------------------
# X is NOT set by the board. It is set by the side switches: the wall has to
# stand off SWITCH_TIP_X far enough to leave a button boss. That is why the
# case does not get narrower in v2 however loose the board pocket becomes.
F_IN_W = 2 * (SWITCH_TIP_X + 1.10)            # 37.20, as v1 — switch-driven
POCKET_CLEAR_Y = 0.75     # per end, and deliberately loose: locates nothing
F_IN_Y_MIN = -(PCB_L / 2 + POCKET_CLEAR_Y)                   # -24.25
F_IN_Y_MAX = PCB_L / 2 + POCKET_CLEAR_Y + SPK_BAY            # +31.25
F_IN_L = F_IN_Y_MAX - F_IN_Y_MIN                             # 55.50
F_IN_CTR_Y = (F_IN_Y_MIN + F_IN_Y_MAX) / 2                   # +3.50
F_IN_R = max(EDGE_FILLET_R - WALL_T, 0.6)                    # 5.60

# Corner relief. The pocket corners are concentric with the 8.0 pebble, so
# they carry a 5.60 radius, and a sharp-cornered 33 x 47 board does not fit
# inside that arc at the -Y end — it penetrates by 0.38. Clearing it by
# moving the wall would cost 0.96 mm of case length; a relief costs 1.02 mm
# of wall at a corner that is 2.40 thick. The real board's corners are
# rounded, but by an amount nobody has measured, so this is sized to work
# even if they are perfectly sharp.
PCB_CORNER_RELIEF_R = 1.0

F_OUT_W = F_IN_W + 2 * WALL_T                                # 42.00
F_OUT_L = F_IN_L + 2 * WALL_T                                # 60.30

# --- the rest of the stack behind the seat --------------------------------
F_PCB_FRONT_Z = SEAT_Z                                       # 6.50
F_PCB_BACK_Z = F_PCB_FRONT_Z + PCB_T                         # 8.10
BACK_COMPONENT_GAP = 2.20     # SD holder is 2.0 tall; 0.2 of margin
F_BATT_FRONT_Z = F_PCB_BACK_Z + BACK_COMPONENT_GAP           # 10.30
F_BATT_BACK_Z = F_BATT_FRONT_Z + BATT_T                      # 15.60
F_COVER_Z = F_BATT_BACK_Z                                    # cover inner face
F_H = F_COVER_Z + BACK_T                                     # 17.60 overall

# --- cover retention: four tabs, no hardware ------------------------------
# The tabs are fingers cut from the flat-printed cover's own edge, so they
# flex WITHIN the layer plane. The old skirt snaps flexed normal to it, which
# is the direction PLA splits, and is the whole reason PETG was mandatory.
#
# Retention and deflection are the SAME number here, exactly as they were for
# the v1 barbs: the finger only has to retract far enough to clear the wall,
# and whatever is left over is what holds the cover in. Strain cannot be
# bought by making the barb proud — only by making the finger longer.
COVER_FIT_REAL = 0.20     # what the cover must actually have, per side
COVER_FIT = COVER_FIT_REAL + 2 * PROCESS_PROUD               # 0.70 drawn
                          # printed-to-printed: BOTH faces come out proud, so
                          # this fit pays PROCESS_PROUD twice. Drawn at 0.40
                          # it was -0.10 — an interference fit by accident.
TAB_L = 12.0              # finger length. The only lever on strain.
TAB_T = 0.80              # finger thickness — the dimension that flexes
TAB_ENGAGE = 0.45         # retention past the wall face = deflection to fit
TAB_BARB = COVER_FIT + TAB_ENGAGE                            # 0.85 proud
TAB_BARB_L = 6.0          # barb length, at the finger's free tip
TAB_BARB_H = 0.80         # barb height in Z
TAB_SLOT_W = 0.80         # relief slot that makes the finger a cantilever
TAB_Z_INSET = 0.20        # barb sits this far behind the cover's front face
TAB_POCKET_D = 0.90       # pocket depth into the wall (> TAB_ENGAGE)
TAB_POCKET_Z0 = F_COVER_Z + TAB_Z_INSET - 0.10
TAB_POCKET_H = TAB_BARB_H + 0.20
TAB_LIP = F_H - (TAB_POCKET_Z0 + TAB_POCKET_H)               # 0.90 back stop
TAB_STRAIN = 1.5 * TAB_T * TAB_ENGAGE / TAB_L**2             # 0.00375

# Where the four tabs go. NOT symmetric, and not a style choice: the pockets
# are cut into walls that already carry openings, so each one has to sit in a
# gap between them. +X has both button bores, -X has the SD slot. The finger
# on the cover may run past an opening; only the POCKET has to miss it.
#   (wall, finger root Y, direction the finger runs)
TAB_SPECS = [
    ("+X",  -6.00,  +1),      # tip at  +6.00, barb   0.00 ..  6.00
    ("+X",  25.00,  -1),      # tip at +13.00, barb  13.00 .. 19.00
    ("-X", -18.00,  +1),      # tip at  -6.00, barb -12.00 .. -6.00
    ("-X",  13.65,  +1),      # tip at +25.65, barb  19.65 .. 25.65
]
TAB_NOTCH_L = 4.0         # release-notch length in Y
TAB_OPENING_MIN = 1.0     # pocket must clear any wall opening by this much

# --- cover standoffs: they carry the clamp, the pad takes up the slop -----
STANDOFF_D = 4.0
PAD_T = 0.60              # foam tape, compresses; absorbs stack error
STANDOFF_H = F_COVER_Z - F_PCB_BACK_Z - PAD_T                # 6.90
STANDOFF_CTRS = [(-10.0, 21.0), (10.0, 21.0),
                 (-10.0, -21.0), (10.0, -21.0)]

# The battery re-centres in v2. In v1 it was biased -1.0 in X to dodge the SD
# holder; here the tab slots run down both long edges and the standoffs sit
# at both ends, and centring is what clears all four.
F_BATT_CTR_X = 0.0
F_BATT_CTR_Y = 0.0


# ===========================================================================
# v3 — LOCATE ON THE BOARD'S OWN HOLES
# ===========================================================================
# Two topologies have now failed on the printer, both for the same reason:
# a rigid bought part was asked to enter a printed feature with a tight
# tolerance. v1 dropped the PCB into a pocket between end stops. v2 dropped
# the PANEL into a close recess, drawn at 0.25/side and therefore printed at
# EXACTLY zero. Neither failure was a modelling error; both were a strategy
# error. A printed pocket is the worst possible precision feature: it is
# blind, it has four walls each carrying PROCESS_PROUD, it cannot be filed,
# and its failure mode is "will not assemble" rather than "sits a bit off".
#
# So stop making pockets do location. The board has four mounting holes and
# they were measured with calipers on 2026-08-28 — HOLE_PITCH_X / _Y above.
# The stock case screws into them. We cannot screw, but we can put two
# PRINTED PEGS through them, and a peg is everything a pocket is not:
#
#   - one feature, not four walls, so one compensation instead of a stack
#   - a peg is compensated by drawing it SMALLER, which is trivial and safe;
#     a pocket is compensated by growing it, which loses the location it was
#     there to provide in the first place
#   - it can carry a lead-in cone, so it GUIDES the board rather than being
#     aimed at, and prints self-supporting
#   - if it comes out tight you can file a 1.9 mm cylinder, or run a drill
#     through the board's hole. You cannot file a blind pocket.
#   - failure is graceful: too tight and the board rests high on the cone,
#     which you can SEE; too loose and it wanders a little further.
#
# Everything else — the panel recess, the board pocket — is now deliberately
# loose, because it locates nothing and its tolerance therefore costs nothing.
# ---------------------------------------------------------------------------

# --- the stack. Z = 0 is the outer front face; the part grows +Z, which is
# --- also how the front shell prints: window-face-down on the bed.
V3_FACE_T = 2.0
V3_PANEL_AIR = 0.30       # glass never touches the face and never carries load
V3_RECESS_D = DISPLAY_RAISE + V3_PANEL_AIR                   # 4.50
V3_SEAT_Z = V3_FACE_T + V3_RECESS_D                          # 6.50 PCB front
V3_PCB_BACK_Z = V3_SEAT_Z + PCB_T                            # 8.10
V3_BACK_GAP = 2.20        # SD holder is 2.0 tall; 0.2 of margin
V3_PART_Z = V3_PCB_BACK_Z + V3_BACK_GAP                      # 10.30 parting line
V3_BATT_BACK_Z = V3_PART_Z + BATT_T                          # 15.60
V3_FLOOR_T = 2.0
V3_H = V3_BATT_BACK_Z + V3_FLOOR_T                           # 17.60

# The depth SPLIT. v2 put all 17.60 in one shell and the board went 11.1 mm
# down a well to reach its seat. Splitting at the battery plane leaves the
# board only 3.8 mm below the front shell's rim — a shallow tray you can see
# into, which is what the stock case looks like and what was asked for.
V3_FRONT_H = V3_PART_Z                                       # 10.30
V3_BACK_H = V3_H - V3_PART_Z                                 # 7.30

# --- locating pegs, through the board's own measured holes -----------------
# ---------------------------------------------------------------------------
# The window, rewritten 2026-08-30 after a real print showed the screen
# sitting entirely outside it.
#
# WINDOW (28.0 sq) was cut for the ACTIVE AREA and positioned by
# ACTIVE_CTR_Y = 1.7. That number is [derived] through two assumptions the
# Waveshare outline drawing does not dimension: that the board is centred in
# its stock case, and that the case window is centred on the active area.
# It drives a hole whose entire error budget is (WINDOW - ACTIVE)/2 = 0.50.
#
# The active area is 27.0 square inside a 31.80 x 37.32 panel, so it may
# legitimately sit anywhere within +/-2.40 X and +/-5.16 Y of the panel
# centre. A derived guess cannot be trusted to 0.50 against that.
#
# So the window is now cut for the PANEL, not the active area. Whatever the
# active area's real offset turns out to be, it is inside the panel by
# definition, so it cannot be cropped. The cost is that the panel's white
# inactive border shows; the alternative is a screen you cannot see.
#
# To go back to a tight bezel, measure board-edge-to-image-edge on all four
# sides with the device powered, set ACTIVE_CTR_X/Y from it, and drop
# V3_WIN_MODE to "active".
# ---------------------------------------------------------------------------
# Measured off two third-party case STLs for this board, 2026-08-30. Somebody
# else's solved problem, and the first hard numbers we have for the window.
# Marked [ref-case]: measured off a real design, but a design we have not
# ourselves verified against the board.
#
# Case A (a 40.00 x 55.00 two-half clamshell) is the informative one; case B is
# a plain 55 x 35 box that locates nothing.
REF_SCREW_PITCH = (28.00, 43.20)     # [ref-case] four holes, 2.50 clearance
REF_WINDOW = (27.80, 27.55)          # [ref-case] cut for the ACTIVE area, tight
REF_WINDOW_CTR = (-0.10, -2.875)     # [ref-case] *** relative to the board centre ***
REF_PANEL_RECESS = (33.00, 39.00)    # [ref-case] centred on the board — which
                                     # CONFIRMS the panel is centred on the PCB,
                                     # until now only a docstring assertion
REF_BOARD_POCKET = (33.60, 50.30)    # [ref-case] 0.30/side on a 33 board
REF_WALL = 3.20                      # [ref-case] vs our WALL_T 2.40
#
# The consequence: our ACTIVE_CTR_Y = 1.7 [derived] against a reference that
# says 2.875 the other way. If the sign is opposite that is 4.575 mm of error
# on a window whose entire budget was 0.50 — which is exactly "the whole screen
# is outside the window". The sign is not confirmed, so the window stays cut
# for the PANEL below, which is sign-agnostic.
V3_WIN_MODE = "panel"     # "panel" = cannot crop | "active" = tight, needs the measurement
V3_WIN_OVERLAP = 1.2      # bezel bite onto the panel, per side
V3_WIN_W = PANEL_W - 2 * V3_WIN_OVERLAP if V3_WIN_MODE == "panel" else WINDOW
V3_WIN_L = PANEL_L - 2 * V3_WIN_OVERLAP if V3_WIN_MODE == "panel" else WINDOW
# centred on the PANEL (which is centred on the board), not on the active area
V3_WIN_CTR_X = 0.0 if V3_WIN_MODE == "panel" else ACTIVE_CTR_X
V3_WIN_CTR_Y = 0.0 if V3_WIN_MODE == "panel" else ACTIVE_CTR_Y

V3_HOLE_XY = [(-HOLE_PITCH_X / 2, -HOLE_PITCH_Y / 2),        # (-13.5, -21.5)
              (HOLE_PITCH_X / 2, HOLE_PITCH_Y / 2)]          # (+13.5, +21.5)
# The diagonal pair, for the longest baseline and so the best control of
# rotation. Two ROUND pegs on a diagonal would over-constrain — both would
# fix X and Y — so the second is relieved along the line joining them and
# constrains only across it. Textbook round-and-diamond.
V3_PEG_FIT_REAL = 0.15    # per side, and this IS the window wander budget
V3_PEG_D = HOLE_D - 2 * V3_PEG_FIT_REAL                      # 1.90 as printed
V3_PEG_D_DRAWN = V3_PEG_D - 2 * PROCESS_PROUD                # 1.40 as drawn
V3_PEG_FLAT = 0.60        # how much the diamond peg is narrowed along the join
V3_PEG_LAND = PCB_T + 0.6                                    # 2.20 of land
V3_PEG_TIP = 1.40         # lead-in cone above the land; guides, not aims
V3_PEG_H = V3_PEG_LAND + V3_PEG_TIP                          # 3.60 above seat
V3_PEG_BASE_D = 3.60      # short conical foot, so a 1.9 pin is not a matchstick
V3_PEG_BASE_H = 0.60

# --- panel recess: loose on purpose, and a datum for nothing ---------------
V3_PANEL_FIT_REAL = 0.50  # per side. Three times v2's, because it no longer
V3_PANEL_FIT = V3_PANEL_FIT_REAL + PROCESS_PROUD             # 0.75 drawn
V3_RECESS_W = PANEL_W + 2 * V3_PANEL_FIT                     # 33.30
V3_RECESS_L = PANEL_L + 2 * V3_PANEL_FIT                     # 38.82
V3_RECESS_RELIEF_R = 1.0  # printed internal corners are never sharp
V3_RECESS_LEADIN = 0.5
# Note the recess is WIDER than the 33.0 board. That is deliberate and it
# means the board seats on its two +Y/-Y ends only. Good: those are where the
# pegs are, so seat and location are the same two places.
V3_END_LEDGE = PCB_L / 2 - (V3_RECESS_L / 2 + V3_RECESS_LEADIN)   # 3.59

# --- interior. X is set by the SWITCH, not the board ----------------------
V3_BTN_BOSS = 1.10        # plastic between switch tip and wall inner face
V3_IN_W = 2 * (SWITCH_TIP_X + V3_BTN_BOSS)                   # 37.20
V3_POCKET_Y = 0.75        # per end, loose: locates nothing
V3_IN_Y_MIN = -(PCB_L / 2 + V3_POCKET_Y)                     # -24.25
V3_IN_Y_MAX = PCB_L / 2 + V3_POCKET_Y + SPK_BAY              # +31.25
V3_IN_L = V3_IN_Y_MAX - V3_IN_Y_MIN                          # 55.50
V3_IN_CTR_Y = (V3_IN_Y_MIN + V3_IN_Y_MAX) / 2                # +3.50
V3_IN_R = max(EDGE_FILLET_R - WALL_T, 0.6)                   # 5.60
V3_OUT_W = V3_IN_W + 2 * WALL_T                              # 42.00
V3_OUT_L = V3_IN_L + 2 * WALL_T                              # 60.30
V3_PCB_RELIEF_R = 1.0     # sharp board corners vs a filleted pocket corner

# --- closure: in-plane fingers, in a flange, because depth is short -------
# A vertical cantilever cannot work in a split case and the arithmetic says
# so plainly. The back tray is 7.30 deep, so a skirt snap is at most 7.30
# long, and 1.5*t*y/L^2 at t=1.2, y=0.4 gives 1.35% — over even the
# un-derated PLA limit, before any derate for bending across the layers.
# Lengthening it is impossible; the case is only as deep as it is.
#
# So the beam is turned on its side. The tray's rim carries an inward FLANGE,
# a flat annulus lying in the XY plane, and the fingers are cut from THAT.
# A finger in a horizontal flange runs along the wall and flexes radially:
# its beam axis lies in the layer plane, so it loads the extrusion rather
# than the bond between layers. No derate is needed and the length is free —
# it is limited by the wall's length, not the case's depth.
#
# The flange is a 4.0 mm inward ledge at the top of a printed wall, i.e. an
# overhang, so it is carried on a 45-degree gusset and prints unsupported.
V3_FLANGE_W = 4.0         # how far the flange reaches inward
V3_FLANGE_T = 1.6         # flange thickness, in Z
V3_FLANGE_GUSSET = V3_FLANGE_W                # 45 degrees, self-supporting
V3_TAB_L = 16.0           # finger length, along the wall
V3_TAB_T = 1.20           # finger thickness, radial — the dimension that bends
V3_TAB_SLOT = 0.80        # relief slot that makes it a cantilever
V3_TAB_ENGAGE = 0.40      # retention past the wall face = deflection to fit
V3_TAB_FIT = 0.20 + 2 * PROCESS_PROUD                        # 0.70 drawn
V3_TAB_BARB = V3_TAB_FIT + V3_TAB_ENGAGE                     # 1.10 proud
V3_TAB_BARB_L = 7.0
V3_TAB_STRAIN = 1.5 * V3_TAB_T * V3_TAB_ENGAGE / V3_TAB_L**2 # 0.0028
# Two on each long wall, clear of every opening those walls already carry.
V3_TAB_SPECS = [("+X", -6.0, +1), ("+X", 24.0, -1),
                ("-X", -18.0, +1), ("-X", 12.0, +1)]
V3_TAB_OPENING_MIN = 1.0

# The joint itself. The two shells butt at V3_PART_Z so the outside is one
# continuous pebble with a single chamfered line round it; underneath, the
# front shell continues as a thin COLLAR that the tray's wall wraps beside.
# The tray's flange sits below the collar and its fingers hook UNDER the
# collar's end face — a hook rather than a side barb, because at the collar's
# own Z the tray has no material to grow a flange from.
# The joint. The shells BUTT at V3_PART_Z so the outside stays one pebble
# with a single chamfered line round it. Retention is a flange on the TRAY
# that reaches up past the parting line into the front shell's pocket, with
# hooks on its fingers catching a groove in the front shell's wall.
#
# An earlier draft gave the FRONT shell a collar hanging down into the tray.
# It does not work: hung inside the wall it leaves 0.50 of tray wall, under
# MIN_FEATURE; hung inside the interior line it is a 1.20 ledge appearing in
# mid-air at the very end of the front shell's print. Putting the reach on
# the tray instead costs nothing — the tray's flange has to exist anyway to
# carry the fingers.
V3_HOOK_Z0 = V3_PCB_BACK_Z + 0.30                            # 8.40
V3_HOOK_Z1 = V3_HOOK_Z0 + 1.00                               # 9.40
V3_GROOVE_D = 0.90        # groove into the front shell's wall inner face
V3_FLANGE_Z0 = V3_HOOK_Z1                                    # 9.40
V3_FLANGE_Z1 = V3_FLANGE_Z0 + V3_FLANGE_T                    # 11.00
V3_JOINT_CHAMFER = 0.6    # both rims, so a 0.2 misalignment reads as a line
V3_PEG_TIP_D = 0.80       # a cone tapering to nothing is not printable
V3_HOOK_TIP = 0.40        # residual tip on the hook wedge. base.py learned
                          # this the hard way: a wedge run to zero leaves a
                          # feather edge the last 0.6 mm of which cannot print

# --- clamp ---------------------------------------------------------------
V3_STANDOFF_D = 5.0
V3_PAD_T = 0.60           # foam tape; absorbs whatever the stack really is
V3_STANDOFF_CTRS = [(-13.5, -18.0), (13.5, -18.0),
                    (-13.5, 18.0), (13.5, 18.0)]
V3_STANDOFF_H = V3_H - V3_FLOOR_T - V3_PCB_BACK_Z - V3_PAD_T # 6.90
V3_BATT_CTR_X = 0.0
V3_BATT_CTR_Y = 0.0


# ===========================================================================
# CASE 1 — reference interior, our exterior
# ===========================================================================
# Rebuilt 2026-08-31 by reading the reference case's own STL rather than
# transcribing numbers from it. `jota/src/ref_extract.py` harvests every
# figure below straight off `jota/ref/refcase_{top,bottom}.stl`; re-run it and
# these numbers come back. Marked [ref-stl] to say exactly that.
#
# The first transcription got four things wrong, and the printed part showed
# all four. They are recorded here because each one is a trap worth not
# falling into twice:
#
#  1. THE WALL IS TWO WALLS. `C1_OUT_W - C1_POCKET_W = 3.20` was read as one
#     solid wall. In the reference those 3.20 mm are an outer skin of 1.50 on
#     the back, an inner tongue of 1.49 on the front, and 0.20 of clearance
#     between them — a lap 4.50 mm deep that telescopes. That lap IS the
#     register. Copied as a solid wall it became two flat rims butting on a
#     plane, located by nothing but four screws in clearance holes.
#  2. THE AXIS FLIP WAS APPLIED TO THE END OPENING BUT NOT TO THE WINDOW.
#     The end opening was flipped to our -Y correctly. The window was not: it
#     kept the reference's own sign, +2.87 instead of -2.87. Both cases have
#     a display pocket centred on 0 and an open end at -Y, so this is a
#     straight 5.75 mm error — the reference offsets its window TOWARD the
#     connector end, ours offsets it away. The panel's active area is not
#     centred on its glass, so getting this backwards crops the display.
#     (The board pocket is centred on 0 in the reference and has no sign to
#     get wrong. An earlier reading of this file had it at 0.75 off-centre,
#     which is what made the -Y wall budget come out impossible.)
#  3. THE CONNECTOR OPENING IS 20.51 WIDE, NOT 31.50. Where 31.50 came from is
#     unknown; the mesh says 20.51. At 31.50 the opening eats 32 of the 40 mm
#     end, and with our 8 mm corner radius almost nothing is left to carry the
#     joint at that end.
#  4. THE SCREWS BEAR ON THE BACK. The reference puts a clearance hole through
#     the back's floor and a blind pilot in the front. Ours had it inverted —
#     a 3.00 clearance hole straight through the front — which puts four screw
#     heads on the face you read.
#
# Frame. our_x = ref_z, our_y = -ref_x, our_z = -ref_y + 10.49. A proper
# rotation (det = +1, it does not mirror), and it lands the reference's open
# connector end at our -Y, where our USB is. EVERY number below has been put
# through it, which is the correction item 2 describes.
#
# The one deliberate deviation, and the reason two prints failed: the
# reference's clearances were drawn for a printer that achieves them. Ours
# prints proud. So POSITIONS are copied exactly and every SIZE that has to
# clear something is opened up by our compensation. Draw 28.32, print 27.82.
C1_C = 2 * PROCESS_PROUD   # 0.50 on every hole and pocket dimension

# --- the shell ------------------------------------------------------------
C1_REF_OUT_W = 40.00      # [ref-stl] x, +-19.999
C1_REF_OUT_L = 55.00      # [ref-stl] y, +-27.496
# One number to make the case deeper. It raises the back's rim, the board's
# seat, the standoffs and the cell pad together, so the joint, the window and
# the front stay exactly as they are. The reference values below are for 0;
# the checker compares against the reference AFTER subtracting this. Use it
# if the speaker (height still a GUESS) stands taller than the 6.30 under
# the board — the extra is the amount it pokes above the standoffs.
# Plain build carries 0.80 of extra depth for the SNAPS, not for contents:
# band-max snap deflection (0.80) at PETG's 1.6 % strain limit needs a
# finger >= 7.75 long, the reference-depth interior gives 5.70 free plus at
# most 1.39 of floor pocket (1.40 must stay under it) = 7.09. The 0.80 of
# rim buys the missing length; the header build (9.0 + 0.3 - 6.3 = 3.0 for
# the header block itself) already has 8.70 and needs none of it.
C1_EXTRA_DEPTH = float(__import__("os").environ.get(
    "C1_EXTRA_DEPTH", 3.0 if HEADER_FITTED else 0.80))

C1_H = 13.49 + C1_EXTRA_DEPTH        # [ref-stl] 13.49 assembled, -0.01 .. 13.488
C1_BACK_H = 8.99 + C1_EXTRA_DEPTH    # [ref-stl] 8.99 back rim, floor outer at z=0
C1_FRONT_H = 9.00         # [ref-stl] face outer to the tongue's free end
C1_FLOOR_T = 2.79         # [ref-stl] back floor. Was 1.60 — 43% under.
C1_REF_CORNER_R = 4.00    # [ref-stl] the reference's corner. Ours is not this.

# Ours, and the only thing about the part that is not copied: the pebble.
#
# It is also the reason the footprint is not the reference's. The reference
# gets away with 40 x 55 because its outer corner is R4.0. At R8.0 the outer
# arc cuts diagonally across the board pocket's corner: pocket corner point
# to pebble arc centre is 6.86 mm on a 40 x 55 body, leaving 1.14 mm for a
# joint that needs skin + clearance + tongue. So the body grows by C1_GROW a
# side, derived below from that one triangle, and the checker probes the
# diagonal to prove it.
#
# What the first print taught: every inner rectangle had been given the
# pebble radius minus its inset, so the board pocket's corners came out at
# R5.06. The PCB's corners are ~R2. That is 1.27 mm of interference on
# every diagonal — the board rode up on all four corners and could not
# reach its seat. The straight-run probes in the checker never saw it.
C1_EDGE_R = EDGE_FILLET_R                                    # 8.0
C1_POCKET_R = 1.80        # [ref-stl] board pocket corner. The wall starts
                          # curving 1.3 mm before the corner; fitted R1.8.
C1_TONGUE_T = 1.20        # fixed, so the growth goes to the skin, which is
                          # the wall that thins at the corner
# Pocket corner extreme point is r(1-1/sqrt2) = 0.527 inside the corner.
# Distance from it to the pebble arc centre must leave C1_EDGE_R minus
# (clearance + tongue + skin-minimum) — solved for the growth, rounded up.
C1_GROW = 1.00            # per side; proven by the corner-diagonal check
C1_OUT_W = C1_REF_OUT_W + 2 * C1_GROW                         # 42.0
C1_OUT_L = C1_REF_OUT_L + 2 * C1_GROW                         # 57.0
# The pebble edge, printable. A fillet cannot meet the bed: its tangent is
# horizontal there and the first layers droop (decisions.md #8). But the
# rule only forbids the last 45 degrees. So: a short 45 deg facet at the
# bed, and above it a large fillet that runs from the facet's angle up to
# the vertical wall — never steeper than 45 deg from vertical anywhere. It
# reads as a rounded edge; the facet is 1.5 mm and disappears in the hand.
# The fillet's tangent length R*tan(22.5) must fit on the facet, which is
# c*sqrt(2) long: R <= 3.41 c.
C1_FACE_CHAMFER = 1.50    # the 45 deg facet at the bed, both outer faces
C1_FACE_FILLET = 5.00     # blends the facet into the wall; 5.0 <= 3.41*1.5
C1_JOINT_CHAMFER = 0.80   # [ref-stl] both rims chamfer away from the joint,
                          # so the seam reads as a deliberate line rather than
                          # as a mismatch. Back 27.49 -> 26.7 at its rim, front
                          # 26.71 at the joint back out to 27.49 by z = 10.0.

# --- the lap joint --------------------------------------------------------
# Back carries the outer skin, front nests inside it, exactly as the reference
# has it. The clearance is the one number our printer forces us to change:
# the female recess prints 0.25 proud inward and the male tongue 0.25 proud
# outward, so a drawn 0.20 would interfere by 0.30. Same arithmetic as
# COVER_FIT above.
C1_LAP_D = 4.50           # [ref-stl] overlap depth, z 4.49 .. 8.99
C1_LAP_CLEAR_REAL = 0.20  # [ref-stl] 0.203 measured
C1_LAP_CLEAR = C1_LAP_CLEAR_REAL + 2 * PROCESS_PROUD         # 0.70 drawn
C1_SKIN_MIN = 0.90        # neither the skin nor the tongue may go below this
# The tongue is C1_TONGUE_T; the skin is whatever is left between the outer
# and the pocket after tongue and clearance, computed in case1.py so it cannot
# drift. On the flats that is ~2.0; at the corner diagonal it thins toward
# C1_SKIN_MIN, and that corner is what sets C1_GROW.

# --- the board ------------------------------------------------------------
C1_POCKET_W = 33.62 + C1_C       # [ref-stl] tongue inner faces at +-16.808
C1_POCKET_L = 48.80 + C1_C       # [ref-stl] tongue inner faces at +-24.402
C1_POCKET_CTR_Y = 0.00           # [ref-stl] centred, constant z 4.49..10.69
C1_SEAT_Z = 10.69 + C1_EXTRA_DEPTH   # [ref-stl] 10.69 board seating face
C1_DISP_W = 33.02 + C1_C  # [ref-stl] 33.018
C1_DISP_L = 39.02 + C1_C  # [ref-stl] 39.018
C1_DISP_D = 1.50          # [ref-stl] deep, z 10.693 .. 12.193
C1_FACE_T = 1.295         # [ref-stl] 13.488 - 12.193. Was 1.25 with a 1.20
                          # chamfer, which left 0.05 mm of window wall — a
                          # quarter of one layer, standing on a 0.90 mm flat
                          # ledge printed over air.

# --- the window -----------------------------------------------------------
# The reference does NOT counterbore this. It tapers: 27.82 at the display
# side opening out to ~29.4 at the outer face over the full 1.295 of face.
# Drawn as a chamfer on the window's outer edge, so there is no flat ledge.
C1_WIN_W = 27.82 + C1_C   # [ref-stl] 27.817
C1_WIN_L = 27.57 + C1_C   # [ref-stl] 27.574
C1_WIN_CTR_X = +0.10      # [ref-stl] +0.100
C1_WIN_CTR_Y = +2.87      # [photo 2026-08-31] TOWARD +Y, AWAY from the USB.
                          # The reference has it at -2.87, toward its
                          # connector end, and that was copied faithfully —
                          # and the first print cropped the top of the
                          # screen while showing 2 mm of panel border and
                          # the FPC at the USB end. On THIS board the FPC is
                          # at the USB end (measure drawing, and the photo),
                          # and a 1.54" panel's active area sits away from
                          # its FPC. So the reference's board must carry its
                          # panel the other way round. Magnitude kept — it
                          # is the panel's own asymmetry — sign from the
                          # board in hand. The photo beats the reference.
C1_WIN_FLARE = 0.85       # [ref-stl] 0.90; trimmed so the straight
                          # window wall clears two layers, not 1.98
C1_WIN_STRAIGHT_MIN = 0.30       # face left un-chamfered below the flare

# --- the connector end ----------------------------------------------------
# In the back only, floor to rim, capped by the front's skirt once closed.
C1_END_OPEN_W = 20.51 + C1_C     # [ref-stl] 20.51. Was 31.50 — see 3.
C1_END_OPEN_H = C1_BACK_H - C1_FLOOR_T   # [ref-stl] 6.20: floor to rim,
                          # derived so it stays floor-to-rim if the case deepens

# --- screws ---------------------------------------------------------------
# Clearance through the back's floor, blind pilot in the front, head on the
# back. Four M2 through the board's own mounting holes.
C1_SCREW_XY = [(x, y) for x in (-14.005, 14.005) for y in (-21.60, 21.60)]
C1_SCREW_CLEAR_D = 2.51 + C1_C   # [ref-stl] 2.507 through the back
C1_SCREW_PILOT_D = 1.60          # M2 self-tapping into PETG
C1_SCREW_PILOT_DEPTH = 2.30      # [ref-stl] 10.693 .. 12.992
# The screws that actually close this case go BOARD-TO-FRONT: pan head on
# the PCB's back face, shank through the board's own mounting hole, into the
# blind pilot. The 2026-09-02 print proved it the hard way: the model held
# no screw heads, the standoff tubes were drawn to touch the PCB back face
# exactly where the heads sit, and each 1.60 mm head held the halves 1.60 mm
# apart — the visible all-round seam, the dead snaps, the air over the USB.
# The reference's own path (head outside the back, down the tube) would need
# an M2x16 in the header build; nobody stocks that, so the board-to-front
# path is the one that gets used and the one the model must survive.
C1_SCREW_L = 4.00         # [measured 2026-09-02] M2 x 4 pan self-tapper.
                          # LONGEST usable: engagement past the board is
                          # 4.00 - 1.60 = 2.40 into a 2.30 pilot (the 0.10 is
                          # absorbed by the tip taper). An M2x5 bottoms by
                          # 1.10 and punches the 0.5 face skin under the pilot.
C1_SCREW_HEAD_D = 4.00    # [measured 2026-09-02] M2 pan head diameter
C1_SCREW_HEAD_H = 1.60    # [measured 2026-09-02] head height, seated on the
                          # PCB back face — cannot enter the 3.01 standoff bore
C1_SCREW_HEAD_RELIEF = C1_SCREW_HEAD_H + 0.40   # 2.00: the back must clear
                          # the head by its 1.8 checker envelope (head + 0.2)
                          # plus one 0.2 layer of pillar-top quantization.
                          # Set 0 only for a build assembled WITHOUT board
                          # screws — then the tube reaches the board again.
C1_SCREW_PAD_D = 6.00     # local floor thickening, merged into the floor —
                          # NOT a free-standing boss. The boss version left a
                          # 0.45 mm crevice between boss and wall, 7.9 deep,
                          # narrower than one extrusion pair.

# --- our openings, which the reference does not have ----------------------
# It holds a bare board and has no button or SD opening at all, so there is
# nothing to copy and these are ours.
#
# They belong to the FRONT, which is not where the first attempt put them.
# The board's front face sits on the seat at 10.69 and it is 1.60 thick, so
# it spans 9.09 .. 10.69 — and the joint is at 8.99. The whole board, and
# therefore every button and the SD slot on its edges, is above the joint and
# inside the front half. Cutting them into the back's wall put them below the
# board entirely, and broke the back's rim into four fragments doing it.
#
# Each one runs from the seat down to the joint plane. That is deliberate:
# ending it short leaves a 0.10 mm sliver of skirt below the opening, which
# is the floating-region defect a slicer already caught once. Running it to
# the joint also means no material is ever printed above the opening, so
# these need no roof and no support.
C1_BTN_D = 6.0
C1_SD_L = SD_SLOT_L + 3.0

# --- the cell, which the reference never had to hold -----------------------
# The reference's tray is empty: it closes over a bare board. Ours carries a
# 503035, and until now nothing held it — it sat loose in a 6.30 mm cavity
# with the board as its only lid.
#
# A fence on the back floor, not a pocket in it: the floor is 2.79 and cutting
# into it to seat the cell would spend the thickness the reference chose.
#
# The height is not a preference. The front's tongue comes down to assembled
# z = 4.49 and the floor's top face is at 2.79, so anything standing on that
# floor has 1.70 mm before it meets the tongue. Ribs tall enough to grip the
# cell properly would have to be narrow enough to pass INSIDE the tongue, and
# at our printer's 0.25 proud that clearance came out at 0.11 mm — which is
# not a clearance. So the ribs stay short and the board, on a foam pad, is
# what stops the cell lifting. The pad is an assembly step, not geometry.
C1_BATT_CLEAR = 0.40      # per side, cell to rib, as printed
C1_BATT_RIB_T = 1.20      # rib wall
C1_BATT_RIB_H = 1.60      # < 1.70, the gap between the floor and the tongue
C1_BATT_LEAD_W = 9.00     # break in the +Y rib for the cell's leads — the
                          # BAT connector is at the +Y (header) end
C1_BATT_LEAD_X0 = 2.00    # break from here to the rib's +X end, so it
                          # lines up with the BAT JST at the +X corner
C1_BATT_CTR_Y = 0.00
# header build: the cell sits beside the header, its -X rib 0.5 clear of it
HEADER_X1 = HEADER_CTR_X + HEADER_W / 2                     # -10.46, its +X face
# In the header build the cell's pocket abuts the +X cavity wall (the wall is
# its +X rib), which puts its -X rib 1.4 clear of the header. Computed below
# once the pocket width exists; see C1_BATT_CTR_X_HEADER.
C1_BATT_CTR_X = 0.00
C1_BATT_POCKET_W = BATT_W + 2 * C1_BATT_CLEAR + C1_C         # 31.80 drawn
C1_BATT_POCKET_L = BATT_L + 2 * C1_BATT_CLEAR + C1_C         # 38.30 drawn
if HEADER_FITTED:
    # The cell's +X limit is the FRONT'S TONGUE, not the back's cavity wall.
    # The tongue hangs from the joint down to its free end, inside the
    # cavity, and its inner face is at C1_POCKET_W/2. Placing the cell
    # against the cavity wall (1.2 further out) put 1.00 mm of cell in the
    # tongue's path: with a cell fitted the case could not close at all,
    # which is exactly what the printed part did. Found by modelling the
    # contents and intersecting, 2026-09-01.
    # The cell is squeezed between two things, and neither is the cavity
    # wall: the HEADER on -X and the FRONT'S TONGUE on +X. The budget:
    _lo = HEADER_CTR_X + HEADER_W / 2 + 0.50      # -9.96, clear of the header
    _hi = C1_POCKET_W / 2 - PROCESS_PROUD         # +16.81, the tongue's line
    C1_BATT_SPAN = _hi - _lo                                      # 26.77
    C1_BATT_CTR_X = (_lo + _hi) / 2                               # +3.43
    # No X ribs in this build: there is not room for them (a 1.2 rib on -X
    # overlapped the header by 0.23). The header and the tongue are the
    # stops; the +Y/-Y ribs and the pad still locate the cell.
    C1_BATT_RIB_PX = False
    C1_BATT_RIB_NX = False
else:
    C1_BATT_SPAN = C1_POCKET_W - 2 * PROCESS_PROUD
    C1_BATT_RIB_PX = True
    C1_BATT_RIB_NX = True
# foam between the cell and the board's back face: exactly what is left of
# the cavity once the cell is in, so the cell can never lift
C1_BATT_PAD_T = (C1_SEAT_Z - PCB_T) - C1_FLOOR_T - BATT_T     # 1.00 / 3.30
# The end ribs are segments, not a closed fence. A fence's rounded corners
# reach y = 20.35 and the screw clearance holes start at 20.095, so the corner
# hung over the hole — 1.16 mm2 of flat ceiling printed over air, which is
# exactly the defect class this checker exists to catch. Checking the screw
# CENTRE was clear of the fence passed; the hole has a radius.
C1_BATT_RIB_SPAN_X = 22.0        # end ribs, clear of the screw columns

# --- screw standoffs ------------------------------------------------------
# The tube does NOT reach the board any more, on purpose. It did — "so the
# screw clamps the board instead of spanning air" — and the 2026-09-02 print
# showed what that drawing costs once real screws exist: the four board-to-
# front pan heads sit ON the PCB back face, exactly the plane the tube tops
# were drawn to, so every tube landed on a head rim (8.72 mm3 of steel-in-
# plastic interference per screw, measured by mesh boolean) and the halves
# were held 1.60 mm apart, uniformly. An annular tube that bears AROUND the
# head is infeasible here: the counterbore must print >= 4.4, the tongue
# caps the OD at 5.60, and (5.60 - 4.90)/2 = 0.35 of wall is under one
# trace. So the whole tube top is the relief: it stops C1_SCREW_HEAD_RELIEF
# short of the board, the head owns that band, and the four M2x4 board-to-
# front screws are the clamp. The screw-from-the-back path through the tube
# is dead by design (the tube no longer clamps anything).
C1_STANDOFF_OD = C1_SCREW_CLEAR_D + 2 * MIN_WALL_SOLID       # 4.81 at 0.4
                          # [ref-stl] is 4.68, which is a 0.835 wall — one
                          # trace and a smear, on the one feature that takes
                          # screw torque. Derived from the nozzle instead, so
                          # it follows if the nozzle changes.
C1_STANDOFF_H = C1_SEAT_Z - PCB_T - C1_FLOOR_T - C1_SCREW_HEAD_RELIEF
                          # 7.30 header / 5.10 plain: top stops 2.00 under
                          # the PCB back face — the screw head's band

# --- the speaker, which the reference does not have -----------------------
# 16 x 5 oval [case-meas, Pala], standing on edge with its face against the
# +Y end wall, exactly as the old case had it. Height was never measured;
# the bay is the full cavity height and the board caps it.
#
# It sits between the two +Y standoffs, behind the cell's +Y rib. The
# tongue is relieved over it, as it is over the USB, because a grille with
# a tongue behind it is the 86%-blocked grille CLAUDE.md remembers. Slits
# go in the back's skin only, below the joint, with 45 deg tops.
C1_SPK_CTR_X = 0.0
C1_SPK_CLEAR = 0.30       # per side, speaker to rib, as printed
C1_SPK_POCKET_W = SPK_L + 2 * C1_SPK_CLEAR + C1_C             # 17.10
C1_SPK_POCKET_T = SPK_W + C1_C                                # 5.50
# The speaker itself, best guess 2026-08-31 with the evidence there is:
#  - Pala's pocket is 16 x 5 with a grille 4 mm tall (old [case-meas]).
#    That is a 15 x 6 x 3 micro speaker on edge, face to the wall.
#  - This case has 16.6 x 5.7 x 6.3 to give it. A 15 x 6 x 3 fits with 0.3
#    of height to spare. Waveshare's own 2030 accessory (20 x 30 x 5.5)
#    fits nowhere in this case, on edge or flat — do not buy that one.
#  - The 1.54 kit ships no speaker; the board's SPK header is MX1.25 2-pin.
# So: buy a "1506" 15 x 6 x 3 mm, 8 ohm, 0.5-1 W. If a taller one arrives,
# C1_EXTRA_DEPTH takes the difference and only the back reprints.
SPK_FACE_W = 15.0         # GUESS-founded: 1506 class, across the grille
SPK_FACE_H = 6.0          # its height standing on edge
SPK_T = 3.0               # its thickness, against the wall
C1_SPK_H = C1_STANDOFF_H  # bay height = cavity under the board, 6.30
C1_SPK_RIB_T = 1.20
C1_SPK_RIB_H = C1_BATT_RIB_H
C1_SPK_RELIEF_W = C1_SPK_POCKET_W + 2 * C1_SPK_RIB_T + 1.0    # 20.50
C1_SPK_SLOT_Z0 = C1_FLOOR_T + 0.25                            # slit bottoms;
                          # the gable tops must stay under the rim chamfer

# --- the buttons: pins through the BACK's skin ----------------------------
# Print #3 taught this: the switch actuators sit below the board's back face,
# which is BELOW the joint, behind the back's skin — and the openings were in
# the front. With the back on, both buttons were behind solid plastic.
#
# The pin is the old case's, whose numbers are measured: head outboard,
# stem through the wall, flange INBOARD so the switch's own spring cannot
# eject it, fitted from inside before the board closes over it. What is new
# is the opening: a U-slot open to the rim, capped by the front, because the
# actuator height (BTN_CTR_Z) is still a GUESS. In a slot the pin can ride
# 1.2 mm up or down and find the actuator itself; in a bore it cannot.
C1_BTN_Z = C1_SEAT_Z - PCB_T - 1.90      # GUESS 7.19: actuator centre, assembled
C1_BTN_SLOT_W = BTN_BORE_D + C1_C        # 4.90 drawn, 4.40 printed: head 4.0 passes
C1_BTN_SLOT_Z0 = C1_BTN_Z - BTN_BORE_D / 2                    # 4.99
C1_BTN_FRONT_NOTCH = 1.20 # into the front's wall above the joint, so the
                          # head can sit up to 1.2 above the rim if it must
C1_PIN_HEAD_D = BTN_HEAD_D               # 4.0
C1_PIN_STEM_D = BTN_STEM_D               # 3.6
C1_PIN_FLANGE_D = 6.00                   # > printed slot + 0.8; was 5.6 on a 4.4 bore
C1_PIN_FLANGE_L = BTN_FLANGE_L           # 1.0
C1_PIN_HEAD_PROUD = BTN_HEAD_PROUD       # 0.8 outside the skin
C1_BTN_RELIEF_W = C1_PIN_FLANGE_D + 1.0  # tongue relieved behind the flange
# The SD slot. Removed once (a 17 mm slot plus two button slots take 27 of
# the 49 mm of +X joint) and put back 2026-08-31 at the owner's call: the
# card should be reachable without four screws. The joint keeps -X and both
# ends whole; +X carries the openings. A U-slot in the back's skin, open to
# the rim, capped by the front; the front's tongue relieved behind it.
C1_SD_SLOT_Z0 = C1_SEAT_Z - PCB_T - SD_SLOT_H                 # 6.29 to the rim

# --- the pebble in the hand: the thumb finds record without looking -------
# One sphere, cut across both halves in the assembled frame, dished into the
# +X wall around BOOT — the record button (firmware README). PWR is plain.
# Depth is bounded by the skin: 2.04 - 0.80 leaves 1.24, above two perimeters.
C1_DISH_DIA = 11.0        # dish opening on the wall
C1_DISH_DEPTH = 0.80
C1_DISH_R = (C1_DISH_DIA ** 2 / 4 + C1_DISH_DEPTH ** 2) / (2 * C1_DISH_DEPTH)  # 19.3
C1_DISH_Y = BTN2_CTR_Y    # BOOT = record
C1_DISH_Z = C1_BTN_Z
# The record pin is told apart by shape and reach, not size — every head
# must still pass the 4.4 mm slot from inside.
C1_PIN_REC_PROUD = 1.20   # record stands 0.4 further out than PWR
C1_PIN_REC_DOME = 0.80    # rim rounded to this radius; PWR is flat-edged

# --- the cord tunnel -------------------------------------------------------
# The Design Lock's idea, done the way this case allows. A tunnel through the
# corner meat is out: every corner has a screw, and the bar left outside it
# is 1.2-2.4 mm. So the STANDOFF is the bar. Two mouths low in the (-X,+Y)
# corner — one in the end wall, one in the side wall — and the cord runs
# inside, on the floor, round the outside of the corner standoff, a 4.8 mm
# column screwed to the board. Nothing on the silhouette; a bail and a tab
# were both rejected. The (-X,+Y) corner is the SPK JST's, the quieter one.
#
# The mouths sit at floor level, BELOW the front's tongue (free end at
# z 4.49), so the front is untouched and the cord lies under the tongue.
C1_CORD_D = 1.50          # GUESS: a thin lanyard cord. 2.0 will not pass
                          # under the tongue; the mouth tops must stay < 4.49
C1_TUN_HOLE_D = 2.00 + C1_C    # 2.0 printed
C1_TUN_Z = 2.50           # mouth centre: gable apex 4.27 stays under the
                          # tongue's free end 4.49; 1.25 of floor under it
C1_TUN_SX, C1_TUN_SY = -1, +1  # the corner
C1_TUN_A_X = 12.0         # mouth A: in the +Y end wall, this far from centre
                          # (on the flat; the corner arc starts at 13)
C1_TUN_B_Y = 20.5         # mouth B: in the -X side wall, this far from
                          # centre — past the end of the cell's side rib (19.4)

# --- the USB port -----------------------------------------------------------
# Print #4 taught two things. A window sized for a plug's overmould, cut in
# a wall 4 mm off the connector, reads as a hole with a connector lost in it.
# And the connector sat left of the window: USB_CTR_X was measured from the
# other face, so its sign is mirrored here.
#
# The rule that sizes this, from the USB-IF Type-C spec (Locking Connector
# Spec Annex A; Type-C R1.3 Fig 3-73): the surface the plug's OVERMOULD
# seats against must be no more than 0.3 mm outboard of the receptacle's
# front face, and a fully mated plug's overmould stands 0.45 +-0.1 in front
# of that face. Any wall further out short-mates every cable. So the recess
# floor sits FLUSH with the receptacle face, the receptacle nose sits inside
# the tight hole, and the wall is only as thick as the gap between the PCB
# edge and that face allows.
#
# Receptacle: 16-pin top-mount (HRO TYPE-C-31-M-12 class), shell 8.94 x
# 3.26 x 7.35, front face ~1.0 past the PCB edge per its recommended
# footprint. GUESS that it is that part and not a flush GCT-style one; if
# the face is flush with the PCB edge the seat is 1.0 outboard and plugs
# sit 0.55 short of full mating — measure M23 to settle it.
# Plug: shell 8.25 x 2.40, exposed 6.65; overmould <= 12.35 x 6.5 by spec.
C1_USB_CTR_X = -USB_CTR_X    # -0.8: photo 2026-08-31, connector left of centre
C1_USB_CTR_Z = C1_SEAT_Z - PCB_T - 1.63     # top-mount receptacle, 3.26 tall
C1_USB_PROTRUDE = 1.00    # GUESS: HRO-class footprint puts the face 1.0 past the edge
C1_USB_FACE_Y = -(PCB_L / 2 + C1_USB_PROTRUDE)                  # -24.50
# The floor works while the receptacle protrudes 0.7-1.5 past the PCB edge:
#   seat is (1.0 - protrusion) outboard of the face, and the spec allows 0.3.
#   p >= 0.7  -> mates. p = 1.0 (assumed) -> flush, ideal.
#   p > 1.0   -> the receptacle nose sits INSIDE the recess and becomes the
#               seat itself. Harmless: the hole is 9.6 round an 8.94 shell.
#   p < 0.7   -> plugs stop (0.7 - p) short. There is no room for a floor at
#               all in that case, so the remedy is to delete it:
#               C1_USB_NO_FLOOR=1 cuts the recess straight through to the
#               hole. One flag, no re-derivation. Do that if a cable will
#               not click home in the printed part.
C1_USB_NO_FLOOR = __import__("os").environ.get("C1_USB_NO_FLOOR", "0") == "1"
C1_USB_SEAT_OUTBOARD = 0.0    # recess floor flush with the receptacle face (spec: <= 0.3)
C1_USB_FLOOR_Y1 = C1_USB_FACE_Y - C1_USB_SEAT_OUTBOARD         # -24.50, the seat
C1_USB_FLOOR_Y0 = -(PCB_L / 2) - 0.30                           # -23.80, 0.3 off the PCB edge
# Without screws nothing held the board in Y: 1.15 of slack each way in the
# reference's 48.8 pocket, and plugging a cable pushes the board AWAY from
# the port — straight into short-mating. So the front carries a Y stop at
# each end of the shelf band: the USB block at -23.80 and a block at +23.80.
# 0.30 a side round a 47.0 board; a 47.5 board still fits.
C1_Y_STOP = PCB_L / 2 + 0.30                                    # 23.80
C1_Y_STOP_W = 12.0
# The stops face the BOARD'S EDGE, so they start at the board's back face —
# not at the joint. Starting at the joint put them 0.10 mm under the -Y
# standoffs, whose tops stand that far proud of the rim: a hard stop that
# held the halves apart. Found by a closure sweep, 2026-09-01.
C1_Y_STOP_Z0 = C1_SEAT_Z - PCB_T                                # board back face
# The -Y stop must not BE the USB floor: in the no-floor variant there is no
# floor, and the board lost its stop. So it is a pair of blocks flanking the
# recess, clear of it, present in every variant.
C1_USB_WALL_T = 0.0 if C1_USB_NO_FLOOR else (C1_USB_FLOOR_Y0 - C1_USB_FLOOR_Y1)   # 0.70: all the room there is
# THE OPENING THE USER COULD STILL SEE AIR THROUGH (prints of 2026-09-01
# and 09-02). Every size below used to carry +C1_C (0.50) or +PROCESS_PROUD:
# growth allowances measured on a deep POCKET, spent on a free-wall opening
# where the 2026-09-01 print measured growth at ~C1_WALL_PROUD (0.05)/side.
# So the mouth printed essentially as drawn — 13.3 x 7.5, 69.5 mm2 of air
# round a 29.1 mm2 shell — and read as a hole with a connector lost in it.
# Redrawn tight: sizes are DRAWN geometry, print growth in [0, 0.25]/side is
# an uncertainty band that only eases entry, never a resource.
C1_USB_HOLE_W = 9.90   # prints 9.4-9.9 over the band; >= 0.23/side round the
                       # 8.94 shell — leans on CTR_X = -0.8 [photo], confirm at M23
C1_USB_HOLE_H = 4.30   # prints 3.8-4.3 round the 3.26 shell
C1_USB_HOLE_R = 0.60
C1_USB_REC_W = 12.10   # mouth budget: prints 11.6-12.1; admits overmoulds
                       # <= 11.2 wide guaranteed, 11.6 at measured growth.
                       # Spec-max 12.35 bricks NO LONGER MATE — deliberate,
                       # the port must read closed. Caliper daily cables at M23.
C1_USB_REC_H = 6.30    # prints 5.8-6.3; admits <= 5.4 tall guaranteed, 5.8 at
                       # measured growth; top lip lands at assembled 13.61,
                       # where the pebble roll-off is 0.05 — an edge, not a feather
C1_USB_REC_R = 1.60
C1_Y_STOP_X0 = C1_USB_REC_W / 2 + 0.6   # inner edge of each -Y stop block
C1_Y_STOP_X1 = 16.0                     # outer edge, inside the pocket wall
C1_USB_BOSS_W = C1_USB_REC_W + 2 * 1.2                          # the boss round the recess
C1_USB_BOSS_Z0 = C1_FLOOR_T - 0.1   # from the floor: a boss that starts
                          # mid-air is a 29 mm2 ceiling in the deeper build
C1_USB_FRONT_NOTCH = C1_USB_CTR_Z + C1_USB_REC_H / 2 - C1_BACK_H   # recess above the seam
C1_USB_HOLE_NOTCH = C1_USB_CTR_Z + C1_USB_HOLE_H / 2 - C1_BACK_H   # hole above the seam

# --- the slide-lock ---------------------------------------------------------
# Closure #3. History, so nobody circles back:
#   #1 cantilever snaps, hooks 0.15 proud: under a nozzle width, never printed.
#   #2 cantilever snaps, real hooks into blind grooves: three printed
#      iterations, none clicked in the assembled case even after a coupon of
#      the same drawing clicked in the hand — a 57 mm wall flexes away from
#      the hook and a 0.3 mm engagement dies inside the process error band.
# The mechanism is now RIGID: no part bends on purpose anywhere.
#
# It is a battery-door slide-lock. The front drops onto the back offset
# C1_SLIDE_T toward -X, slides +X to lock, and a printed KEY plugs the
# travel gap through the -X skin so it cannot slide back. Five rigid TABS
# on the back's +-Y inner walls pass through tip-open notches in the
# front's tongue during the drop, and the slide moves each tab over a
# STRIP of tongue left under its window — pure interlock, engagement is
# the tongue's own thickness, and every clearance is ~0.3 mm where the
# snaps lived on 0.05.
#
# Print direction is what sizes the tab: the back prints floor-down, so
# the tab's underside is a 45 deg chamfer (self-supporting) and its top —
# the working face — prints flat and clean. The strip that rides under
# that chamfer is backed by the back's own wall 0.20 away (printed), so
# lift-off cams the strip into the wall and stops. Nothing to tune.
C1_SLIDE_T = 2.20         # travel, -X to +X. Also the strip length per tab.
C1_TAB_FLAT = 1.00        # flat crown under the tab's top face
C1_TAB_E = C1_LAP_CLEAR + C1_TONGUE_T - 0.10   # 1.80: through the tongue,
                          # 0.10 shy of its inner face — nothing enters the
                          # board pocket band (the board itself lives above
                          # the seam and is never near a tab)
C1_TAB_H = C1_TAB_FLAT + C1_TAB_E              # 2.80 with the 45 deg chamfer
C1_TAB_TOP = 1.00         # tab top this far under the seam: 1.0 of wall
                          # inner face stays above the window band
C1_WIN_C = 0.30           # window clearance per side, x and z — sliding-fit
                          # territory, an order looser than the dead snaps
C1_STRIP_H = 1.40         # tongue left under each window; the working strip
# Tab sites: (assembled x of the tab centre at LOCKED, tab width). The mesh
# sweep in check_case1.py is the proof, but the neighbours that sized them:
#   * USB boss solid over x -8.65..+7.05 on the -Y wall, full height, so the
#     tongue is relieved there and a strip must live outside [-8.95, +9.55]
#     counting the drop offset;
#   * the tongue's corner arcs: solid added at the tongue band survives only
#     |x| <= ~14.4 ONCE OFFSET by the travel toward -X (drop position);
#   * the standoffs (|x| 11.6..16.4, |y| 19.2..24.0) under the swept path.
C1_SLIDE_SITES_NY = ((-12.3, 2.6), (+12.0, 2.6))
C1_SLIDE_SITES_PY = ((-11.6, 4.0), (+0.5, 5.0), (+11.5, 4.0))
# The tongue's -X run is deleted from assembled -C1_TONGUE_XCUT outward:
# the drop offset would drive it into the -X wall, and its absence is the
# slide clearance. Chosen so the surviving +-Y runs (and their windows'
# strips) clear the back's corner arcs at the DROP offset.
C1_TONGUE_XCUT = 14.50
# The window floor hugs the tab's 45 deg underside WHERE IT CROSSES THE
# TONGUE BAND, not the tab's lowest point at the wall — the wall-side part
# of the wedge never meets the tongue (it lives in the lap clearance). Set
# to the tab's lowest, the floor sat 1.05 low and the case lifted 1.05 mm
# before anything touched: the snap's axial-slack disease, rebuilt rigid.
# Free lift is C1_WIN_C, then the strip rides the chamfer into the wall.
_win_bot = C1_TAB_TOP + C1_TAB_FLAT + C1_TAB_E - C1_LAP_CLEAR + C1_WIN_C  # 3.40 under the seam
C1_SEG_EXTRA = _win_bot + C1_STRIP_H - C1_LAP_D                # 0.31
C1_SEG_MARGIN = 0.80      # segment continues this far past the roofed span
# The key: a flat pin pushed through the -X skin ACROSS the seam into a
# matching slot in the front's shelf. Its one job is blocking the slide:
# the front cannot move back toward -X while the pin fills its path.
# (Lift needs no key anywhere: the front is a rigid tray, so lifting any
# edge is a rotation that lands on the far tabs.) Friction-held, nail
# groove to pry it out. Fit lives in the KEY: loose or tight, reprint IT
# at +-0.1, never the case.
# The backing rib. Coupon evidence 2026-09-19: a full-width strip with both
# walls and both tongues dropped, slid, and still lifted off. The tab's
# 45 deg underside is a cam — lift pushes the strip INWARD, off the tab —
# and the only thing resisting that was the far wall, one lap clearance
# (0.70 drawn) away, plus a 1.20 mm tongue that flexes the rest. Tab
# engagement into the tongue is 1.10, so the margin was nil. Each site now
# gets a rib on the back's floor C1_SLIDE_RIB_C inside the tongue's inner
# face: the tongue is sandwiched (wall / rib) and the cam has nowhere to go.
# Lift is then C1_WIN_C + C1_SLIDE_RIB_C drawn, less as printed.
C1_SLIDE_RIB_T = 1.50     # rib thickness, y
C1_SLIDE_RIB_C = C1_WIN_C # rib face to tongue inner face
C1_SLIDE_RIB_MARGIN = 0.40  # rib runs this far past the tab (locked) in x
# top = standoff top, so the rib merges into a standoff where they meet and
# never reaches the screw head relief above it
C1_KEY_W = 10.0           # along Y, drawn slot size
C1_KEY_ZB = 2.20          # slot reach below the seam (in the back's skin)
C1_KEY_ZA = 1.80          # slot reach above the seam (in the front's shelf)
C1_KEY_DEPTH = 3.50       # from the outer face inward; stops 0.4 short of
                          # the board pocket wall, board clear by ~0.45
C1_KEY_FIT = 0.30         # key drawn this much under the slot each way
C1_KEY_NAIL = 1.00        # pry groove in the key's outer face
C1_WALL_PROUD = 0.05      # [print-derived 2026-09-01] per-surface growth on
C1_WALL_PROUD_MAX = 0.10  # free vertical walls (vs 0.25 on deep pockets);
                          # kept: the USB section and the checker cite it
