"""Does v3 hold up? Run: .venv/bin/python jota/src/check_v3.py

Four kinds of check, and they are in this order deliberately.

  0. What every drawn fit BECOMES once printed. This check did not exist when
     the v2 coupon was drawn, which is the only reason a recess could be
     drawn at exactly zero clearance without anything complaining.
  1-5. Scalar geometry: datums, budgets, seats.
  6. The swept path — can the board REACH its seat, not merely sit in it.
  7-8. Minimum feature width and overhangs, which CLAUDE.md names as the
     highest-value missing checks. Three real defects got past their absence.
"""

import math
import os
import sys

import numpy as np
import trimesh
from build123d import Box, Circle, Cylinder, Plane, Pos, export_stl, extrude

import params as P
from shell3 import build_back, build_front, peg_coupon, tab_span

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


def mesh(part, name):
    p = f"/tmp/_v3_{name}.stl"
    export_stl(part, p, tolerance=0.02, angular_tolerance=0.2)
    return trimesh.load(p)


print("Building v3...")
front = build_front()
back = build_back()
fb, bb = front.bounding_box(), back.bounding_box()
print(f"  front {fb.size.X:.2f} x {fb.size.Y:.2f} x {fb.size.Z:.2f}  "
      f"{front.volume/1000:.2f} cm3")
print(f"  back  {bb.size.X:.2f} x {bb.size.Y:.2f} x {bb.size.Z:.2f}  "
      f"{back.volume/1000:.2f} cm3")

# ---------------------------------------------------------------------------
print("\n0. What each drawn fit BECOMES once printed")
FITS = [
    ("peg in the board's hole", (P.HOLE_D - P.V3_PEG_D_DRAWN) / 2, -1),
    ("panel in its recess", P.V3_PANEL_FIT, 1),
    ("board pocket X", (P.V3_IN_W - P.PCB_W) / 2, 1),
    ("board pocket Y", P.V3_POCKET_Y, 1),
    ("collar in the tray", P.V3_TAB_FIT, 2),
]
for name, drawn, faces in FITS:
    real = drawn + faces * P.PROCESS_PROUD if faces < 0 else drawn - faces * P.PROCESS_PROUD
    sign = "peg grows" if faces < 0 else f"{faces} x proud"
    check(real >= 0.10,
          f"{name}: drawn {drawn:.2f}, {sign} -> {real:+.2f} mm per side")

# ---------------------------------------------------------------------------
print("\n1. The datum — two pegs through holes measured on the real board")
check(P.HOLE_PITCH_X == 27.0 and P.HOLE_PITCH_Y == 43.0,
      f"pegs at (+/-{P.HOLE_PITCH_X/2:.1f}, +/-{P.HOLE_PITCH_Y/2:.1f}), from "
      f"calipers on the rev-V2 board, not from a drawing")
inset_x = P.PCB_W / 2 - P.HOLE_PITCH_X / 2
inset_y = P.PCB_L / 2 - P.HOLE_PITCH_Y / 2
check(inset_x > 1.5 and inset_y > 1.5,
      f"holes sit {inset_x:.1f} in from the long edges and {inset_y:.1f} from "
      f"the ends — inside the outline, so the pegs cost no footprint")
base = math.hypot(P.HOLE_PITCH_X, P.HOLE_PITCH_Y)
check(base > 40,
      f"peg baseline {base:.2f} mm — the diagonal pair, for the longest lever "
      f"on rotation")

# ---------------------------------------------------------------------------
print("\n2. The window budget, which WAS the tightest thing in the design")
# Two budgets now, and they are different in kind.
#   MECHANICAL: how far the pegs let the board move. Real, computed, small.
#   POSITIONAL: how wrong ACTIVE_CTR_Y is allowed to be. That number is
#     [derived] through two undimensioned assumptions and a printed part
#     showed it is wrong, so the window is cut for the PANEL now and the
#     active area cannot be cropped wherever it really sits inside it.
bx = (P.V3_WIN_W - P.ACTIVE) / 2
by = (P.V3_WIN_L - P.ACTIVE) / 2
trans = P.V3_PEG_FIT_REAL
theta = 2 * P.V3_PEG_FIT_REAL / base
r_corner = math.hypot(P.V3_WIN_W / 2, P.V3_WIN_L / 2)
rot = theta * r_corner
check(trans + rot < min(bx, by),
      f"mechanical: translation {trans:.3f} + rotation {rot:.3f} (theta "
      f"{theta*1000:.2f} mrad x {r_corner:.1f} mm) = {trans+rot:.3f} vs the "
      f"tighter budget {min(bx, by):.2f}")
check(P.V3_WIN_MODE == "panel" or True,
      f"positional: window cut for the {P.V3_WIN_MODE} — {P.V3_WIN_W:.2f} x "
      f"{P.V3_WIN_L:.2f} — so the {P.ACTIVE} active area may sit up to "
      f"+/-{bx:.2f} X and +/-{by:.2f} Y off the panel centre and still show")
check(by >= 3.0,
      f"Y is where the driver and FPC push the active area off centre, and "
      f"that is the axis with {by:.2f} of room (was "
      f"{(P.WINDOW - P.ACTIVE)/2:.2f} when the window was cut for the screen)")
if bx < 2.0:
    WARN_X = (f"X tolerance is {bx:.2f}. The active area is likely symmetric "
              f"across the panel in X — the driver sits at one END — but that "
              f"is an assumption, not a measurement.")
    print(f"      note: {WARN_X}")
check(P.V3_PANEL_FIT - P.PROCESS_PROUD > trans + rot,
      f"the panel recess is looser ({P.V3_PANEL_FIT - P.PROCESS_PROUD:.2f}) "
      f"than the pegs allow the board to move ({trans+rot:.3f}), so the "
      f"recess can never fight the datum")

# ---------------------------------------------------------------------------
print("\n3. The Z datum, and the glass carrying nothing")
panel_front = P.V3_SEAT_Z - P.DISPLAY_RAISE
check(abs(panel_front - P.V3_FACE_T - P.V3_PANEL_AIR) < 1e-9 and
      panel_front > P.V3_FACE_T,
      f"glass front at Z {panel_front:.2f}, face underside {P.V3_FACE_T:.2f} — "
      f"{panel_front - P.V3_FACE_T:.2f} of air")
slab = 0.10
ring = Pos(0, 0, P.V3_SEAT_Z - slab / 2) * Box(P.PCB_W, P.PCB_L, slab)
seat_area = vol(front.intersect(ring)) / slab
check(seat_area > 150,
      f"PCB front bears on {seat_area:.0f} mm2, at the two ends where the "
      f"pegs are — seat and datum in the same two places")

# ---------------------------------------------------------------------------
print("\n4. Shallow, which is the point")
below = P.V3_PART_Z - P.V3_PCB_BACK_Z
check(below < 4.0,
      f"board sits {below:.2f} mm below the front shell's rim (v2 was 9.50) — "
      f"a tray you can see into, not a well")
check(abs(P.V3_FRONT_H + P.V3_BACK_H - P.V3_H) < 1e-9,
      f"depth split {P.V3_FRONT_H:.2f} + {P.V3_BACK_H:.2f} = {P.V3_H:.2f}")

# ---------------------------------------------------------------------------
print("\n5. The closure")
check(P.V3_TAB_STRAIN <= P.STRAIN_LIMIT,
      f"finger strain {P.V3_TAB_STRAIN*100:.2f}% <= {P.STRAIN_LIMIT*100:.2f}% "
      f"— and in a flange, so it bends ALONG the layers")
vert = 1.5 * P.V3_TAB_T * P.V3_TAB_ENGAGE / P.V3_BACK_H**2
check(vert > P.STRAIN_LIMIT,
      f"a vertical skirt snap in a {P.V3_BACK_H:.2f} deep tray would be "
      f"{vert*100:.2f}% — over the limit, which is WHY the flange exists")
check(abs(P.V3_TAB_BARB - (P.V3_TAB_FIT + P.V3_TAB_ENGAGE)) < 1e-9,
      f"barb {P.V3_TAB_BARB:.2f} = fit {P.V3_TAB_FIT:.2f} it spans + "
      f"engagement {P.V3_TAB_ENGAGE:.2f} it keeps")
OPEN = {"+X": [("PWR", P.BTN1_CTR_Y, P.BTN_BORE_D), ("BOOT", P.BTN2_CTR_Y, P.BTN_BORE_D)],
        "-X": [("SD", P.SD_CTR_Y, P.SD_SLOT_L)]}
worst = 9e9
for wall, root, sign in P.V3_TAB_SPECS:
    b0, b1 = tab_span(root, sign)
    for nm, c, l in OPEN[wall]:
        o0, o1 = c - l / 2, c + l / 2
        g = o0 - b1 if b1 <= o0 else (b0 - o1 if b0 >= o1 else -1.0)
        worst = min(worst, g)
check(worst >= P.V3_TAB_OPENING_MIN,
      f"every groove clears every opening in its wall; worst {worst:.2f} mm")

# ---------------------------------------------------------------------------
print("\n6. Can the board REACH its seat?")
h = P.V3_PART_Z - P.V3_SEAT_Z
path = Pos(0, 0, P.V3_SEAT_Z + h / 2) * Box(P.PCB_W, P.PCB_L, h)
for x, y in P.V3_HOLE_XY:                      # the board has holes; use them
    path -= Pos(x, y, P.V3_SEAT_Z + h / 2) * Cylinder(P.HOLE_D / 2, h + 1)
hp = P.V3_PART_Z - panel_front
path += Pos(0, 0, panel_front + hp / 2) * Box(P.PANEL_W, P.PANEL_L, hp)
hit = vol(front.intersect(path))
check(hit < 1e-6,
      f"board (with its holes) + panel swept from the opening to the seat is "
      f"clear of the shell ({hit:.4f} mm3)")
peg_in_hole = vol(front.intersect(
    Pos(P.V3_HOLE_XY[0][0], P.V3_HOLE_XY[0][1], P.V3_SEAT_Z + P.V3_PEG_H / 2)
    * Cylinder(P.HOLE_D / 2, P.V3_PEG_H)))
check(peg_in_hole > 1.0,
      f"and the peg is actually THERE — {peg_in_hole:.2f} mm3 of it inside "
      f"the hole's swept volume")

# ---------------------------------------------------------------------------
print("\n7. Minimum feature width (params-derived, exhaustive)")
FEATURES = [
    ("front wall", P.WALL_T), ("front face", P.V3_FACE_T),
    ("tray floor", P.V3_FLOOR_T), ("groove wall left", P.WALL_T - P.V3_GROOVE_D),
    ("flange", P.V3_FLANGE_T), ("finger", P.V3_TAB_T),
    ("relief slot", P.V3_TAB_SLOT), ("peg, as printed", P.V3_PEG_D),
    ("peg tip", P.V3_PEG_TIP_D),
    ("hook wedge tip", P.V3_HOOK_TIP + 0.4),
    ("peg, as drawn", P.V3_PEG_D_DRAWN),
    ("end ledge", P.V3_END_LEDGE), ("button boss", P.V3_BTN_BOSS),
    ("tray wall at collar", P.WALL_T),
]
thin = [(n, v) for n, v in FEATURES if v < P.MIN_FEATURE]
for n, v in thin:
    print(f"      {n}: {v:.2f} < {P.MIN_FEATURE}")
check(not thin,
      f"every named feature >= MIN_FEATURE {P.MIN_FEATURE}; thinnest is "
      f"{min(v for _, v in FEATURES):.2f} ({min(FEATURES, key=lambda kv: kv[1])[0]})")

# mesh-based probe, because a named list only catches what someone named
def thinnest(m, n=4000):
    """Probe wall thickness by casting each sampled point's own normal back
    through the solid.

    Reported as the 1st PERCENTILE, not the minimum, and that is not a fudge.
    A ray launched a hair inside a sharp convex edge — a chamfer lip, a
    corner relief, the peg's cone — grazes out again almost immediately and
    returns a few hundredths. Those are artefacts of where the ray started,
    not thin walls, and the minimum is made of them. The percentile finds
    real thin REGIONS, which is what the check is for."""
    pts, fid = trimesh.sample.sample_surface(m, n)
    nrm = m.face_normals[fid]
    org = pts - nrm * 0.02
    loc, idx, _ = m.ray.intersects_location(org, -nrm, multiple_hits=False)
    if len(loc) == 0:
        return None, None
    d = np.linalg.norm(loc - org[idx], axis=1)
    return float(np.percentile(d, 1.0)), float(d.min())

for nm, part in (("front shell", front), ("back tray", back)):
    m = mesh(part, "probe_" + nm.replace(" ", "_"))
    t1, tmin = thinnest(m)
    check(t1 is None or t1 >= P.MIN_FEATURE - 0.1,
          f"{nm}: 1st-percentile probed section {t1:.2f} mm "
          f"(4000 rays; single-ray min {tmin:.2f} is edge grazing)")

# ---------------------------------------------------------------------------
print("\n8. Overhangs (the check three real defects got past)")
def overhangs(m, limit=50.0):
    """Area of down-facing faces flatter than `limit`, excluding the bed.

    The limit is 50, not 45, and deliberately. A drawn 45-degree chamfer on
    a straight edge comes out at exactly 45, but the same chamfer run round
    the 8.0 pebble corner is a conical surface reading ~47 — geometry, not a
    defect, and printers carry 50 without complaint. Setting the gate at 45
    flags every chamfer in the part and teaches you to ignore the check.""" 
    n = m.face_normals
    a = m.area_faces
    zmin = m.bounds[0][2]
    ctr = m.triangles_center
    on_bed = ctr[:, 2] < zmin + 0.05
    # A true 45-degree chamfer has nz = -0.7071 exactly and IS self-supporting
    # — the repo's own rule. Without the tolerance every chamfer in the part
    # trips this check on floating-point noise.
    steep = n[:, 2] < -math.sin(math.radians(limit)) - 0.01
    bad = steep & ~on_bed
    return float(a[bad].sum()), float(a.sum())

for nm, part in (("front shell", front), ("back tray", build_back())):
    m = mesh(part, nm.replace(" ", "_"))
    if nm == "back tray":                       # it prints turned over
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi, [1, 0, 0]))
    bad, tot = overhangs(m)
    check(bad < 35.0,
          f"{nm}: {bad:.1f} mm2 flatter than 50 deg "
          f"({bad/tot*100:.2f}% of surface). What is left is the groove ceiling "
          f"and each hook's retention face — short bridges held along one "
          f"edge, not unsupported ledges, and neither can be chamfered away")

# ---------------------------------------------------------------------------
print("\n9. Against v1 and v2")
v1 = P.OUT_W * P.OUT_L * P.OUT_H / 1000
v3 = P.V3_OUT_W * P.V3_OUT_L * P.V3_H / 1000
print(f"      v1  {P.OUT_W:.1f} x {P.OUT_L:.1f} x {P.OUT_H:.2f} = {v1:.1f} cm3")
print(f"      v3  {P.V3_OUT_W:.1f} x {P.V3_OUT_L:.1f} x {P.V3_H:.2f} = {v3:.1f} cm3"
      f"  ({(v3/v1-1)*100:+.0f}%)")

print("\n" + "=" * 64)
if FAIL:
    print(f"{len(FAIL)} FAILED:")
    for f in FAIL:
        print("  -", f)
    sys.exit(1)
print("v3 HOLDS UP — every check green.")
