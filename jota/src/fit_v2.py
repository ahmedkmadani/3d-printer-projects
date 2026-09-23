"""Does the board fit the v2 front frame? Run: .venv/bin/python jota/src/fit_v2.py

Two kinds of check, and the second is the one that matters. Scalar checks
compare numbers. The path check builds the swept solid the board sweeps on
its way in and asks the frame whether it is in the way — because v1 passed
every scalar check it had and still produced a case the board could not be
put into.
"""

import math
import os
import sys

from build123d import Box, Pos

import params as P
from frame import build_frame

FAIL = []


def check(cond, msg):
    print(f"  [{'PASS' if cond else 'FAIL'}] {msg}")
    if not cond:
        FAIL.append(msg)


def vol(r):
    if r is None:
        return 0.0
    if hasattr(r, "volume") and not hasattr(r, "__len__"):
        return r.volume
    try:
        return sum(s.volume for s in r)
    except TypeError:
        return getattr(r, "volume", 0.0)


print("Building the frame...")
frame = build_frame()
bb = frame.bounding_box()
print(f"  {bb.size.X:.2f} x {bb.size.Y:.2f} x {bb.size.Z:.2f} mm, "
      f"{frame.volume/1000:.2f} cm3\n")

# ---------------------------------------------------------------------------
print("0. What each drawn fit BECOMES once printed")
# The check that did not exist when the first coupon was drawn, and the only
# reason it could be drawn at zero clearance without anything complaining.
FITS = [
    ("panel in its recess", P.PANEL_FIT, 1),
    ("board pocket X",      (P.F_IN_W - P.PCB_W) / 2, 1),
    ("board pocket Y",      P.POCKET_CLEAR_Y, 1),
    ("cover in the wall",   P.COVER_FIT, 2),
]
for name, drawn, faces in FITS:
    real = drawn - faces * P.PROCESS_PROUD
    check(real >= 0.15,
          f"{name}: drawn {drawn:.2f} - {faces} x {P.PROCESS_PROUD} proud "
          f"= {real:+.2f} mm per side")

print("\n1. The XY datum — panel into its recess")
fx = (P.PANEL_RECESS_W - P.PANEL_W) / 2
fy = (P.PANEL_RECESS_L - P.PANEL_L) / 2
check(abs(fx - P.PANEL_FIT) < 1e-9 and abs(fy - P.PANEL_FIT) < 1e-9,
      f"panel {P.PANEL_W} x {P.PANEL_L} in recess {P.PANEL_RECESS_W} x "
      f"{P.PANEL_RECESS_L}: {fx:.2f} drawn, {fx - P.PROCESS_PROUD:.2f} printed")
wander = fx - P.PROCESS_PROUD
check(wander + P.ACTIVE / 2 < P.WINDOW / 2,
      f"window wander +/-{wander:.2f} keeps the {P.ACTIVE} active area inside "
      f"the {P.WINDOW} window, with {P.WINDOW/2 - P.ACTIVE/2 - wander:.2f} spare")

# ---------------------------------------------------------------------------
print("\n2. The Z datum — PCB front on the seat ledge, glass carrying nothing")
panel_front_z = P.SEAT_Z - P.DISPLAY_RAISE
gap = panel_front_z - P.FACE_T
check(abs(gap - P.PANEL_GLASS_RELIEF) < 1e-9 and gap > 0,
      f"glass front sits at Z {panel_front_z:.2f}, face underside at "
      f"{P.FACE_T:.2f} — {gap:.2f} mm of air, so the glass takes no clamp load")

slab = 0.10
ring = Pos(0, 0, P.SEAT_Z - slab / 2) * Box(P.PCB_W, P.PCB_L, slab)
seat_area = vol(frame.intersect(ring)) / slab
check(seat_area > 200,
      f"PCB front bears on {seat_area:.0f} mm2 of seat ledge "
      f"({seat_area / (P.PCB_W * P.PCB_L) * 100:.0f}% of the board face)")

led_x = P.PCB_W / 2 - P.PANEL_RECESS_W / 2
led_y = P.PCB_L / 2 - P.PANEL_RECESS_L / 2
check(led_x > 0 and led_y > 0,
      f"ledge reaches under the board by {led_x:.2f} mm at the sides and "
      f"{led_y:.2f} mm at the ends")

# ---------------------------------------------------------------------------
print("\n3. The board pocket — loose on purpose, and locating nothing")
px = (P.F_IN_W - P.PCB_W) / 2
py = P.PCB_L / 2 - abs(P.F_IN_Y_MIN)
check(px > 0.5 and abs(py) > 0.5,
      f"pocket clearance {px:.2f} mm per side in X, {abs(py):.2f} mm at -Y")
check(P.F_IN_W / 2 - P.SWITCH_TIP_X >= P.MIN_FEATURE,
      f"X is set by the SWITCH, not the board: wall inner face "
      f"{P.F_IN_W/2:.2f} - SWITCH_TIP_X {P.SWITCH_TIP_X:.2f} = "
      f"{P.F_IN_W/2 - P.SWITCH_TIP_X:.2f} mm of button boss "
      f"(>= MIN_FEATURE {P.MIN_FEATURE})")

# ---------------------------------------------------------------------------
print("\n4. Can it REACH the seat? (the check v1 did not have until too late)")
h_pcb = P.F_H - P.SEAT_Z
path = Pos(0, 0, P.SEAT_Z + h_pcb / 2) * Box(P.PCB_W, P.PCB_L, h_pcb)
h_pan = P.F_H - panel_front_z
path += Pos(0, 0, panel_front_z + h_pan / 2) * Box(P.PANEL_W, P.PANEL_L, h_pan)
hit = vol(frame.intersect(path))
check(hit < 1e-6,
      f"board + panel swept from the back opening down to the seat is clear "
      f"of frame structure ({hit:.4f} mm3)")

# how much room is actually left on that path, per side
for grow, label in ((0.0, "as drawn"), (px - 0.05, "grown to the wall")):
    p2 = Pos(0, 0, P.SEAT_Z + h_pcb / 2) * Box(P.PCB_W + 2 * grow,
                                               P.PCB_L + 2 * grow, h_pcb)
    print(f"      +{grow:.2f} per side ({label}): {vol(frame.intersect(p2)):.3f} mm3")

# ---------------------------------------------------------------------------
print("\n5. The window still frames the screen")
check(P.WINDOW < P.PANEL_W and P.WINDOW < P.PANEL_L,
      f"window {P.WINDOW} sq inside panel {P.PANEL_W} x {P.PANEL_L}: bezel "
      f"overlap {(P.PANEL_W - P.WINDOW)/2:.2f} mm per side")
check(P.WINDOW > P.ACTIVE,
      f"window {P.WINDOW} clears the {P.ACTIVE} active area by "
      f"{P.WINDOW_REVEAL:.2f} mm per side")

# ---------------------------------------------------------------------------
print("\n6. Against v1")
v1 = P.OUT_W * P.OUT_L * P.OUT_H / 1000
v2 = P.F_OUT_W * P.F_OUT_L * P.F_H / 1000
print(f"      v1  {P.OUT_W:.2f} x {P.OUT_L:.2f} x {P.OUT_H:.2f}  = {v1:.1f} cm3")
print(f"      v2  {P.F_OUT_W:.2f} x {P.F_OUT_L:.2f} x {P.F_H:.2f}  = {v2:.1f} cm3"
      f"   ({(v2/v1 - 1) * 100:+.0f}%)")
check(P.TAB_STRAIN <= P.STRAIN_LIMIT,
      f"cover tab strain {P.TAB_STRAIN*100:.2f}% <= {P.STRAIN_LIMIT*100:.2f}% "
      f"for {P.MATERIAL} — and this one bends ALONG the layers")

# ---------------------------------------------------------------------------
print("\n7. What the corner relief cost")
# outer pebble arc and pocket arc are concentric at the -Y corners
arc_cx = P.F_OUT_W / 2 - P.EDGE_FILLET_R
arc_cy = P.F_IN_Y_MIN - P.WALL_T + P.EDGE_FILLET_R
d = math.hypot(P.PCB_W / 2 - arc_cx, -P.PCB_L / 2 - arc_cy)
left = P.EDGE_FILLET_R - (d + P.PCB_CORNER_RELIEF_R)
check(left >= P.MIN_FEATURE,
      f"wall left outboard of the -Y corner relief = {left:.2f} mm "
      f"(>= MIN_FEATURE {P.MIN_FEATURE}); relief vanishes the wall at "
      f"R {P.EDGE_FILLET_R - d - P.MIN_FEATURE:.2f}")
check(d + P.PCB_CORNER_RELIEF_R > d + (d - P.F_IN_R),
      f"relief R {P.PCB_CORNER_RELIEF_R:.2f} covers the "
      f"{d - P.F_IN_R:.2f} mm the board corner penetrated the pocket arc")

# ---------------------------------------------------------------------------
print("\n8. The cover, and whether its tabs found room in the walls")
from build123d import Circle, Plane, extrude          # noqa: E402
from cover import build_cover, X_EDGE                 # noqa: E402
from frame import tab_geometry                        # noqa: E402

OPENINGS = {
    "+X": [("PWR bore", P.BTN1_CTR_Y - P.BTN_BORE_D / 2, P.BTN1_CTR_Y + P.BTN_BORE_D / 2),
           ("BOOT bore", P.BTN2_CTR_Y - P.BTN_BORE_D / 2, P.BTN2_CTR_Y + P.BTN_BORE_D / 2)],
    "-X": [("SD slot", P.SD_CTR_Y - P.SD_SLOT_L / 2, P.SD_CTR_Y + P.SD_SLOT_L / 2)],
}
worst = 9e9
for wall, root, sign in P.TAB_SPECS:
    b0, b1 = tab_geometry(root, sign)
    for name, o0, o1 in OPENINGS[wall]:
        gap = o0 - b1 if b1 <= o0 else (b0 - o1 if b0 >= o1 else -1.0)
        worst = min(worst, gap)
        if gap < P.TAB_OPENING_MIN:
            print(f"      {wall} barb {b0:.2f}..{b1:.2f} vs {name}: {gap:.2f}")
check(worst >= P.TAB_OPENING_MIN,
      f"every tab pocket clears every opening in its wall; worst gap "
      f"{worst:.2f} mm (>= {P.TAB_OPENING_MIN})")

check(abs(P.TAB_BARB - (P.COVER_FIT + P.TAB_ENGAGE)) < 1e-9,
      f"barb {P.TAB_BARB:.2f} proud = fit {P.COVER_FIT:.2f} it must span + "
      f"engagement {P.TAB_ENGAGE:.2f} it must keep")
check(P.TAB_POCKET_D > P.TAB_ENGAGE,
      f"pocket {P.TAB_POCKET_D:.2f} deep swallows a {P.TAB_ENGAGE:.2f} barb "
      f"with {P.TAB_POCKET_D - P.TAB_ENGAGE:.2f} to spare")
check(P.TAB_LIP >= P.MIN_FEATURE,
      f"back lip that actually stops the cover = {P.TAB_LIP:.2f} mm "
      f"(>= MIN_FEATURE {P.MIN_FEATURE})")
lead = math.degrees(math.atan(P.TAB_ENGAGE / P.TAB_LIP))
check(lead <= 35.0,
      f"lead-in angle {lead:.1f} deg — deflect {P.TAB_ENGAGE:.2f} over the "
      f"{P.TAB_LIP:.2f} of travel there is (<= 35, or it is a fight)")
check(P.TAB_STRAIN <= P.STRAIN_LIMIT,
      f"tab strain {P.TAB_STRAIN*100:.2f}% <= {P.STRAIN_LIMIT*100:.2f}% for "
      f"{P.MATERIAL}; finger shortens to {P.TAB_L*(P.TAB_STRAIN/P.STRAIN_LIMIT)**0.5:.1f} "
      f"before it is at the limit")

print("\n9. Does the cover go into the frame at all?")
cover = build_cover()
clash = vol(frame.intersect(cover))
check(clash < 1e-6, f"cover seated in the frame: {clash:.4f} mm3 of interference")
cb = cover.bounding_box()
print(f"      cover {cb.size.X:.2f} x {cb.size.Y:.2f} x {cb.size.Z:.2f}, "
      f"{cover.volume/1000:.2f} cm3")

print("\n10. The clamp arithmetic")
so_top = P.F_COVER_Z - P.STANDOFF_H
check(abs((so_top - P.F_PCB_BACK_Z) - P.PAD_T) < 1e-9,
      f"standoff tops stop at Z {so_top:.2f}, PCB back at {P.F_PCB_BACK_Z:.2f} "
      f"— {so_top - P.F_PCB_BACK_Z:.2f} mm for the foam to fill")
for x, y in P.STANDOFF_CTRS:
    on = abs(x) + P.STANDOFF_D / 2 <= P.PCB_W / 2 and abs(y) + P.STANDOFF_D / 2 <= P.PCB_L / 2
    if not on:
        print(f"      standoff ({x}, {y}) overhangs the board")
check(all(abs(x) + P.STANDOFF_D / 2 <= P.PCB_W / 2
          and abs(y) + P.STANDOFF_D / 2 <= P.PCB_L / 2 for x, y in P.STANDOFF_CTRS),
      f"all four standoffs land inside the {P.PCB_W} x {P.PCB_L} board")

print("\n11. What the standoffs and the battery have to miss")
def keep(w, d, h, cx, cy):
    return Pos(cx, cy, P.F_PCB_BACK_Z + h / 2) * Box(w, d, h)
sd = keep(15.0, 14.0, 2.0, P.PCB_W / 2 - 15.0 / 2 + 2.0, P.SD_CTR_Y)
usb = keep(9.2, 7.5, 3.4, P.USB_CTR_X, -P.PCB_L / 2 + 7.5 / 2 - 1.4)
batt = Pos(P.F_BATT_CTR_X, P.F_BATT_CTR_Y,
           (P.F_BATT_FRONT_Z + P.F_BATT_BACK_Z) / 2) * Box(P.BATT_W, P.BATT_L, P.BATT_T)
posts = None
for x, y in P.STANDOFF_CTRS:
    pil = extrude(Plane.XY.offset(P.F_PCB_BACK_Z) * Pos(x, y)
                  * Circle(P.STANDOFF_D / 2), P.F_COVER_Z - P.F_PCB_BACK_Z)
    posts = pil if posts is None else posts + pil
for name, solid in (("SD holder", sd), ("USB shell", usb), ("battery", batt)):
    v = vol(posts.intersect(solid))
    check(v < 1e-6, f"standoffs clear the {name} ({v:.3f} mm3)")
check(vol(batt.intersect(cover)) < 1e-6,
      f"battery clears the cover's tab slots and standoffs "
      f"({vol(batt.intersect(cover)):.3f} mm3)")
check(vol(batt.intersect(frame)) < 1e-6,
      f"battery {P.BATT_W} x {P.BATT_L} x {P.BATT_T} sits inside the frame "
      f"({vol(batt.intersect(frame)):.3f} mm3)")

print("\n" + "=" * 62)
if FAIL:
    print(f"{len(FAIL)} FAILED:")
    for f in FAIL:
        print("  -", f)
    sys.exit(1)
print("THE BOARD FITS — every check green.")

# The coupon: everything above the first few mm of the pocket is irrelevant
# to the fit and is most of the print time, so it is cut away.
from build123d import Mesher, export_stl  # noqa: E402
from frame import seat_coupon

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "models", "next")
os.makedirs(OUT, exist_ok=True)
c = seat_coupon()
export_stl(c, os.path.join(OUT, "seat_v2.stl"), tolerance=0.012,
           angular_tolerance=0.1)
m = Mesher()
m.add_shape(c)
m.write(os.path.join(OUT, "seat_v2.3mf"))
cm3 = c.volume / 1000
print(f"\nwrote models/next/seat_v2.stl + .3mf — {cm3:.2f} cm3, "
      f"~{cm3 * (0.55 + 0.45 * 0.20) * 1.24:.1f} g PLA")
print("  it carries: front face, window, panel recess, seat ledge,")
print("  the first 4.0 mm of the board pocket and both -Y corner reliefs.")
print("  it cannot tell you about: the wall openings or the cover tabs,")
print("  neither of which is modelled yet.")
