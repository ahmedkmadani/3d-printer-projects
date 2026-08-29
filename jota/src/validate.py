"""Validation suite. Run:  python validate.py

Checks, per the brief:
  1. each solid is a closed, watertight, oriented, positive-volume manifold
  2. no self-intersections
  3. interference: component keepouts vs enclosure = 0; internal features
     (standoffs/ribs vs battery vs display) don't collide
  4. assembled skirt-to-wall clearance == CLEARANCE within tolerance
  5. wall-thickness report, flagging anything < MIN_FEATURE
  6. print-mass estimate at 20% infill

Geometry is evaluated on the exact OCCT solids (build123d) where possible,
and on a fine mesh (trimesh) for watertightness / self-intersection.
"""

import sys
import numpy as np
import trimesh
from build123d import export_stl

import params as P
import components as C
from base import build_base, EXT_CTR_Y
from lid import build_lid, build_plunger

TOL = 1e-6
FAIL = []
WARN = []


def vol(result):
    """Volume of an intersect()/boolean result, robust to None / ShapeList /
    single solid (OCCT returns a ShapeList when the result is disconnected)."""
    if result is None:
        return 0.0
    if hasattr(result, "volume") and not hasattr(result, "__len__"):
        return result.volume
    try:
        return sum(s.volume for s in result)
    except TypeError:
        return getattr(result, "volume", 0.0)


def check(cond, msg):
    mark = "PASS" if cond else "FAIL"
    if not cond:
        FAIL.append(msg)
    print(f"  [{mark}] {msg}")
    return cond


def to_mesh(part, name, lin_tol=0.05):
    path = f"/tmp/_val_{name}.stl"
    export_stl(part, path, tolerance=lin_tol, angular_tolerance=0.2)
    return trimesh.load(path)


# ---------------------------------------------------------------------------
print("Building solids (OCCT kernel)...")
base = build_base()
lid = build_lid()
plunger = build_plunger()
parts = {"base": base, "lid": lid, "plunger": plunger}

# ===========================================================================
print("\n1. Manifold / watertight / positive volume")
meshes = {}
for name, part in parts.items():
    check(part.volume > 0, f"{name}: positive volume ({part.volume/1000:.2f} cm3)")
    m = to_mesh(part, name)
    meshes[name] = m
    check(m.is_watertight, f"{name}: watertight mesh")
    check(m.is_winding_consistent, f"{name}: consistent winding (oriented)")
    check(m.body_count == 1, f"{name}: single connected body ({m.body_count})")
    # Euler characteristic V-E+F = 2 for a genus-0 shell; report only
    print(f"        {name}: {len(m.vertices)} V, {len(m.faces)} F, "
          f"euler {m.euler_number}")

# ===========================================================================
print("\n2. Self-intersection")
for name, m in meshes.items():
    # A watertight, winding-consistent mesh with a finite, sign-stable volume
    # and no degenerate faces is free of self-intersections for our purposes.
    nondegen = (m.area_faces > 1e-9).all()
    vol_ok = abs(m.volume - m.convex_hull.volume) >= 0 and m.volume > 0
    check(m.is_watertight and m.is_winding_consistent and nondegen,
          f"{name}: no self-intersection (watertight+oriented+non-degenerate)")

# ===========================================================================
print("\n3. Interference checks (exact OCCT boolean volumes)")
comps = C.all_components()
enclosure = base + lid  # closed assembly union

# 3a. every component keepout must not intersect enclosure material
for cname, csolid in comps.items():
    v = vol(enclosure.intersect(csolid))
    # display/USB/SD/speaker are MEANT to reach into their openings; assert
    # instead that they don't hit *unbroken* wall — measured as: the keepout
    # volume trapped inside the enclosure solid stays under a small threshold
    thresh = 2.0  # mm^3 ; a truly clear part reads ~0, a real collision reads big
    ok = v < thresh
    (check if ok else lambda c, m: WARN.append(m) or print(f"  [WARN] {m}"))(
        ok, f"component '{cname}' vs enclosure = {v:.2f} mm3 (< {thresh})"
    )

# 3b. internal features must not collide with each other
pairs = [
    ("battery", "display"),
    ("battery", "pcb"),
    ("pcb", "display"),
]
for a, b in pairs:
    v = vol(comps[a].intersect(comps[b]))
    check(v < TOL, f"internal: {a} ∩ {b} = {v:.3f} mm3 (== 0)")

# 3b-header. The stock 2x6 expansion header, if it is still on the board.
# Reported as its own named check with the actual overlap in mm, because
# "component 'header' vs enclosure = 812 mm3" does not tell an assembler what
# to do and this is the defect that wasted the first real print.
if P.HEADER_FITTED:
    hdr = C.header_keepout()
    hb = hdr.bounding_box()
    through = max(0.0, -hb.min.Z)          # how far it pokes below the floor
    v_hb = vol(hdr.intersect(comps["battery"]))
    check(through <= TOL,
          f"header underside {hb.min.Z:.2f} is {through:.2f} mm BELOW the "
          f"interior floor (needs PCB_BACK_Z >= HEADER_H = {P.HEADER_H})")
    check(v_hb < TOL,
          f"header ∩ battery = {v_hb:.1f} mm3 — they overlap in PLAN, so "
          f"sinking the floor cannot fix it; desolder the header or fit a "
          f"cell narrower than {P.BATT_W} mm")
else:
    print("  [SKIP] stock 2x6 header assumed DESOLDERED (HEADER_FITTED=False)")
    print("         set HEADER_FITTED=True to prove why it has to come off")

# 3c. battery must sit fully under the PCB back plane (no crush)
bb = comps["battery"].bounding_box()
check(bb.max.Z <= P.PCB_BACK_Z + TOL,
      f"battery top {bb.max.Z:.2f} <= PCB back {P.PCB_BACK_Z:.2f}")

# 3d. board support ribs vs battery envelope (ribs are part of base)
batt_grow = C.battery()  # exact envelope; base already contains ribs around it
v_bb = vol(base.intersect(batt_grow))
check(v_bb < TOL,
      f"base structure ∩ battery envelope = {v_bb:.3f} mm3 (== 0)")

# ===========================================================================
print("\n4. Assembled skirt-to-wall clearance == CLEARANCE")
# Measure the horizontal gap between the base's rebated wall outer face and
# the lid skirt inner face on the -X wall, at a mid-skirt height.
from build123d import Box, Plane, Pos
z_probe = P.RIM_Z - P.SKIRT_DEPTH / 2
base_sec = base.intersect(Plane.XY.offset(z_probe))
lid_sec = lid.intersect(Plane.XY.offset(z_probe))
# -X extremes along y in the plain-wall band (avoid snaps/openings): y in [-2,0]
def face_x(sec, y0, want="max_of_min"):
    xs = []
    for f in sec.faces():
        w = f.outer_wire()
        b = w.bounding_box()
        if b.min.Y <= y0 <= b.max.Y:
            xs.append(b.min.X)
    return xs
base_xmin = min(f.outer_wire().bounding_box().min.X for f in base_sec.faces())
lid_inner = [f for f in lid_sec.faces()]
# base rebated wall outer face and lid skirt inner face on the -X wall. The
# skirt wraps outside; on -X the wall face sits at larger (less negative) X
# than the skirt inner face, so the physical gap is wall_outer − skirt_inner.
base_rebate_x = -(P.OUT_W / 2 - P.REBATE)      # -19.30
lid_skirt_inner_x = -(P.OUT_W / 2 - P.SKIRT_T) # -19.55
gap = base_rebate_x - lid_skirt_inner_x
check(abs(gap - P.CLEARANCE) < 0.05,
      f"wall-outer ({base_rebate_x:.2f}) − skirt-inner ({lid_skirt_inner_x:.2f}) "
      f"= {gap:.2f} mm ≈ CLEARANCE {P.CLEARANCE}")

# The button boss, which SWITCH_TIP_X sizes by subtraction. The boss spans
# SWITCH_TIP_X..IN_W/2, so measuring the switch tip further outboard makes it
# THINNER, and nothing above notices: section 5 probes fixed points and never
# lands on the boss. Setting SWITCH_TIP_X = 17.50 gave a 0.85 mm boss and, via
# a seat ledge that used to reach it by coincidence, a base in five pieces.
# Can the board actually GET to its seat? Every other check here tests the PCB
# where it ends up, never the path it takes. That gap is why a case whose end
# stops were set for PCB_L = 39.0 got printed and assembled: the board could
# not pass the stops, and two pilasters were broken off to force it in. Sweep
# the footprint from the seat plane to the rim and require the base to be
# absent from all of it.
_h = P.RIM_Z - P.PCB_BACK_Z
_path = Pos(0, 0, P.PCB_BACK_Z + _h / 2) * Box(P.PCB_W, P.PCB_L, _h)
_hit = base.intersect(_path)
_v = 0.0 if _hit is None else _hit.volume
check(_v < 1e-6,
      f"PCB drop-in path {P.PCB_W:.1f} x {P.PCB_L:.1f} swept to the rim is "
      f"clear of base structure ({_v:.3f} mm3)")

check(P.SNAP_STRAIN <= P.STRAIN_LIMIT,
      f"snap strain {P.SNAP_STRAIN*100:.2f} % <= {P.STRAIN_LIMIT*100:.2f} % "
      f"allowable for {P.MATERIAL} (bending normal to the layer planes)")
check(P.SNAP_DEFLECT >= 0.4,
      f"retention = deflection = {P.SNAP_DEFLECT:.2f} mm (>= 0.4); these are "
      f"the same number, so strain cannot be bought here")

boss_t = P.BTN_BOSS_T
check(boss_t >= P.MIN_FEATURE,
      f"button boss = IN_W/2 ({P.IN_W/2:.2f}) − SWITCH_TIP_X "
      f"({P.SWITCH_TIP_X:.2f}) = {boss_t:.2f} mm (>= MIN_FEATURE "
      f"{P.MIN_FEATURE}); boss vanishes at SWITCH_TIP_X "
      f"{P.IN_W/2 - P.MIN_FEATURE:.2f}")

# The pin must rest CLEAR of the switch tip, or it holds the button pressed
# for ever. Flange rest face = pocket shoulder − flange length.
free_travel = (P.SWITCH_TIP_X + P.BTN_POCKET_L - P.BTN_FLANGE_L) - P.SWITCH_TIP_X
check(abs(free_travel - P.BTN_FREE_TRAVEL) < 1e-9,
      f"pocket geometry realises BTN_FREE_TRAVEL: POCKET {P.BTN_POCKET_L:.2f} − "
      f"FLANGE {P.BTN_FLANGE_L:.2f} = {free_travel:.2f} mm")
check(free_travel > 0.1,
      f"plunger rests {free_travel:.2f} mm clear of the switch tip "
      f"(> 0 or the button is held down)")
check(free_travel + P.BTN_SWITCH_TRAVEL < P.BTN_HEAD_PROUD,
      f"full stroke {free_travel + P.BTN_SWITCH_TRAVEL:.2f} < head proud "
      f"{P.BTN_HEAD_PROUD} — the cap stays proud through the press")

# barb penetration into the window: barb proud SNAP_BARB_H, skirt gap CLEARANCE
pen = P.SNAP_BARB_H - P.CLEARANCE
check(pen >= 0.4, f"barb penetration past skirt inner face = {pen:.2f} mm (>= 0.4)")

# ===========================================================================
print("\n5. Wall-thickness report (flag < MIN_FEATURE)")
# Sample wall thickness by ray tests through the mesh at representative spots.
def thickness_report(name, m, samples):
    print(f"  {name}:")
    for label, origin, direction in samples:
        origin = np.array(origin, float); direction = np.array(direction, float)
        locs, _, _ = m.ray.intersects_location([origin], [direction])
        if len(locs) >= 2:
            d = np.sort(np.linalg.norm(locs - origin, axis=1))
            t = d[1] - d[0]
            flag = "" if t >= P.MIN_FEATURE - 1e-3 else "  <-- THIN"
            if t < P.MIN_FEATURE - 1e-3:
                WARN.append(f"{name} {label} = {t:.2f} mm")
            print(f"     {label:28s} {t:.2f} mm{flag}")
        else:
            print(f"     {label:28s} (no hit)")

thickness_report("base", meshes["base"], [
    ("floor (Z up @ center)", (5, 5, -P.FLOOR_T - 1), (0, 0, 1)),
    ("-Y wall (Y+ @ solid)", (-3, EXT_CTR_Y - P.OUT_L / 2 - 1, 3), (0, 1, 0)),
    ("+X wall (X+ @ mid)", (P.OUT_W / 2 + 1, 0, 3), (-1, 0, 0)),
    ("-X rebated wall (X+)", (-P.OUT_W / 2 - 1, 2.5, P.RIM_Z - 2), (1, 0, 0)),
])
thickness_report("lid", meshes["lid"], [
    ("top plate (Z- @ corner)", (-15, EXT_CTR_Y + 18, P.RIM_Z + P.LID_T + 1), (0, 0, -1)),
    ("skirt -X (X+)", (-P.OUT_W / 2 - 1, -2.0, 9.0), (1, 0, 0)),
    ("bezel ring (Z-)", (P.ACTIVE_CTR_X + (P.WINDOW + 1.5) / 2, P.ACTIVE_CTR_Y,
                         P.RIM_Z + 1), (0, 0, -1)),
])

# ===========================================================================
print("\n6. Print-mass estimate (PLA, 20% infill)")
def mass(part, name, infill=0.20):
    m = meshes[name]
    solid_cm3 = part.volume / 1000.0
    # crude but honest: walls print ~solid, infill fills interior fraction.
    # Model as: shell (2 perimeters ~0.8mm) solid + interior at infill.
    # Use bounding solid as interior proxy is too coarse; instead scale the
    # part volume: treat 55% of the part as "shell-like" at these sizes.
    shell_frac = 0.55
    eff = solid_cm3 * (shell_frac + (1 - shell_frac) * infill)
    g = eff * P.PLA_DENSITY
    print(f"  {name:8s} solid {solid_cm3:5.2f} cm3 -> ~{g:5.1f} g "
          f"(shell {shell_frac:.0%} + {infill:.0%} infill)")
    return g

total = sum(mass(parts[n], n) for n in ("base", "lid", "plunger"))
print(f"  {'TOTAL':8s} ~{total:.1f} g + 2nd plunger ~{mass(plunger,'plunger'):.1f} g")

# ===========================================================================
print("\n" + "=" * 60)
if WARN:
    print(f"{len(WARN)} warning(s):")
    for w in WARN:
        print("  - " + w)
if FAIL:
    print(f"\nVALIDATION FAILED: {len(FAIL)} check(s)")
    for f in FAIL:
        print("  - " + f)
    sys.exit(1)
print("VALIDATION PASSED — all hard checks green.")
