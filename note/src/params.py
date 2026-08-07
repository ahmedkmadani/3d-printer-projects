"""All enclosure parameters in one place. Units: mm.

Target hardware (Pala Note BOM): Waveshare ESP32-S3-ePaper-1.54 board
(1.54" 200x200 e-paper AIoT board: mic, speaker header, SD slot, LiPo
charger) + 3.7 V 503035 LiPo.

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
CLEARANCE = 0.25          # per-side clearance wherever a part meets a component
NOZZLE = 0.4
LAYER_H = 0.2
MIN_FEATURE = 0.8
PLA_DENSITY = 1.24        # g/cm^3

# ---------------------------------------------------------------------------
# Board: Waveshare ESP32-S3-ePaper-1.54
# Published data: case 39.8 x 53.0 x 16.9, window 27.8 sq @ 14.3 from bottom,
#   screws 28.1 apart (https://docs.waveshare.com/ESP32-S3-ePaper-1.54);
#   1.54" V2 panel active area 27.00 x 27.00
#   (https://files.waveshare.com/wiki/common/1.54inch_e-paper_V2_Datasheet.pdf)
# Everything about the bare PCB below is [case-meas] unless marked.
# ---------------------------------------------------------------------------
PCB_W = 33.0              # [case-meas] front cavity 33.4 minus fit
PCB_L = 39.0              # [case-meas] front cavity 39.4 minus fit
PCB_T = 1.6               # GUESS: standard FR4, not published

PANEL_W = 31.8            # [datasheet] 1.54" V2 panel outline
PANEL_L = 37.32           # [datasheet]
PANEL_T = 1.18            # [datasheet]
ACTIVE = 27.0             # [datasheet] active area, square

# Display module front face sits raised above the PCB front (panel + spacer
# + connector): window seat -4.8 minus PCB seat -9.0 in the reference case.
DISPLAY_RAISE = 4.2       # [case-meas] PCB front face -> panel front face

# Window / active-area center relative to PCB center. [case-meas]:
# case window center (-1.45,-11.7); PCB center in case frame (-2.0,-14.7).
ACTIVE_CTR_X = 0.55
ACTIVE_CTR_Y = 3.0

# Back-side components (SD holder, USB-C shell, RTC...) — keepout depths
# below the PCB back face:
BACK_CLEAR_MID = 1.5      # GUESS: small parts over the battery zone
BACK_CLEAR_EDGE = 3.5     # GUESS: USB shell / SD holder at the bottom/right edges
# NOTE: the stock 2x6 female header (~8.5 tall) does NOT fit — the Pala
# reference case leaves only ~7.9 behind the PCB. It must be desoldered
# (the Pala Note build evidently does). Documented in README.

# Interfaces, PCB-frame positions [case-meas]:
BTN1_CTR_Y = -14.0        # PWR/BOOT tactile switches on the +X (right) edge
BTN2_CTR_Y = -3.0
BTN_CAP_W = 7.0           # reference cap size (Y) — ours match
BTN_CAP_H = 4.8           # reference cap size (Z)
SD_CTR_Y = 10.5           # SD slot center on the right edge
SD_SLOT_L = 12.2          # [case-meas] slot length (Y)
SD_SLOT_H = 2.8           # [case-meas] slot height (Z)
USB_CTR_X = 0.8           # USB opening center on the -Y (bottom) edge
USB_OPEN_W = 9.0          # [case-meas] core opening width (fits plug overmolds)
USB_OPEN_H = 7.0          # opening height; generous like the reference
MIC_CTR_X = -8.15         # mic pinhole on the bottom edge
LED_CTR_X = 8.8           # LED light-pipe hole on the bottom edge
PINHOLE = 2.0             # [case-meas] 2x2 square in reference; we use round d=2
SPK_CTR_X = 0.8           # speaker pocket center (X), just beyond the +Y PCB edge
SPK_CTR_Y = 23.75         # speaker seated against the grille wall, behind the rib
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

# Board support: PCB has NO usable mounting holes (Pala case screws pass
# OUTSIDE the PCB outline — the board is clamped, not screwed). Ours:
# four corner posts with seat ledges under the PCB back + side locating
# nubs; the lid bezel presses the display stack down = same clamp concept.
POST_SEAT_Z = PCB_BACK_Z
POST_W = 5.0              # square posts at the four PCB corners
PCB_CORNER_GRIP = 2.5     # how far the seat ledge reaches under the PCB edge

# Interior: PCB + posts behind each edge + speaker bay beyond +Y edge
IN_W = PCB_W + 2 * CLEARANCE + 2 * 1.6     # side nub/post structure per side
SPK_BAY = SPK_W + 2.0                      # speaker pocket depth beyond PCB edge
IN_L = PCB_L + 2 * CLEARANCE + SPK_BAY + 1.6
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
SKIRT_T = 1.2
SKIRT_DEPTH = 10.0        # >= SNAP_ENGAGE_DEPTH + 1.0
REBATE = SKIRT_T + CLEARANCE
REBATED_WALL = WALL_T - REBATE            # 0.95 >= MIN_FEATURE

# Deflection is a FIRST-CLASS parameter, not a by-product of CLEARANCE.
# It used to be (SNAP_BARB_H - CLEARANCE), which meant loosening a sliding fit
# silently reduced both snap deflection and retention.
SNAP_DEFLECT = 0.50                       # skirt deflection during insertion
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
SNAP_ENGAGE_DEPTH = 9.0

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
# +Y positions must satisfy |c| + SNAP_BARB_L/2 <= SKIRT_X_LIMIT (= OUT_W/2 -
# EDGE_FILLET_R = 12.75). At EDGE_FILLET_R 8.0 the old +-11.0 put the outer
# 2.25 mm of each +Y barb into solid wall where no skirt exists, so it
# retained nothing.
SNAPS = [("-X", -7.0), ("-X", 12.0), ("+Y", -6.5), ("+Y", 6.5)]

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
BTN_POCKET_L = 1.3
BTN_FREE_TRAVEL = 0.30    # pin motion before it meets the switch
BTN_SWITCH_TRAVEL = 0.25  # tactile switch actuation

BTN_BOSS_T = 3.2          # local wall thickening for the bore tiers
BTN_CTR_Z = PCB_BACK_Z - 1.0   # GUESS: switch bodies on the PCB back edge
SWITCH_TIP_X = 17.05      # GUESS: side-switch plunger tip ~0.55 beyond PCB edge.
                          # Drives plunger pin length — adjust after a test fit.

# Derived opening heights (interfaces live relative to the PCB planes)
MIC_CTR_Z = 9.0           # [case-meas] pinhole straddles the PCB front plane
LED_CTR_Z = 9.0           # [case-meas]
SD_CTR_Z = PCB_BACK_Z - 0.8    # [case-meas] SD holder on the PCB back face

# Interior Y extents (asymmetric: speaker bay beyond the +Y PCB edge)
IN_Y_MIN = -(PCB_L / 2 + CLEARANCE + 1.6)
IN_Y_MAX = PCB_L / 2 + CLEARANCE + SPK_BAY
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
