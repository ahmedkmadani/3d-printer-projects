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
SPK_L = 16.0              # [case-meas] oval speaker pocket
SPK_W = 5.0
SPK_GRILL_SLOTS = 4       # [case-meas] 0.8 x 4.0 slits in the wall
SPK_SLOT_W = 0.8
SPK_SLOT_H = 4.0
SPK_SLOT_PITCH = 1.64

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
LID_T = 2.0
EDGE_FILLET_R = 3.0
RIM_CHAMFER = 0.8

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
SKIRT_DEPTH = 8.0
REBATE = SKIRT_T + CLEARANCE
REBATED_WALL = WALL_T - REBATE            # 0.95 >= MIN_FEATURE

SNAP_BARB_H = 0.75        # barb proudness off the rebated wall face
SNAP_DEFLECT = SNAP_BARB_H - CLEARANCE    # 0.5 — skirt clearance eats the rest;
                                          # barb still penetrates the window 0.5
SNAP_BARB_L = 8.0
SNAP_WINDOW_H = 1.8
SNAP_WINDOW_L = SNAP_BARB_L + 2 * CLEARANCE
SNAP_ENGAGE_DEPTH = 7.0                   # cantilever length L
SNAP_PANEL_L = 18.0
SNAP_SLOT_W = 1.2
SNAP_STRAIN = 1.5 * SKIRT_T * SNAP_DEFLECT / SNAP_ENGAGE_DEPTH**2

# Snap locations: (wall, center along that wall). The -Y wall gets none —
# its center belongs to the USB opening (that edge is the natural thumb-
# opening point). Positions chosen clear of the speaker grille slits.
SNAPS = [("-X", -7.0), ("-X", 12.0), ("+Y", -11.0), ("+Y", 11.0)]

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
BTN_BORE_D = 4.0
BTN_STEM_D = 3.4
BTN_CAP_D = 6.0
BTN_CAP_RECESS_D = 6.6
BTN_CAP_RECESS_DEPTH = 1.0
BTN_FLANGE_D = 5.2
BTN_FLANGE_RECESS_D = 5.8
BTN_FLANGE_RECESS_DEPTH = 0.8
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
