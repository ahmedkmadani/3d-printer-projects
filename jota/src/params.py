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
PCB_CLEARANCE = 0.40      # [print-derived 2026-08-29] was CLEARANCE (0.25)
NOZZLE = 0.4
LAYER_H = 0.2
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
HOLE_PITCH_X = 27.0       # [measured] H1-H2 across
HOLE_PITCH_Y = 43.0       # [measured] H3-H1 down
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
HEADER_FITTED = False     # True = model a board with the stock header still on
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
SD_CTR_Y = 10.5           # GUESS: was [case-meas] against a 39 mm board, so
                          # it no longer means anything. M29 is still blank.
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
BATT_L = 37.0             # [datasheet] envelope, along Y
BATT_W = 30.5             # [datasheet] envelope, along X
BATT_T = 5.3              # [datasheet] envelope
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
