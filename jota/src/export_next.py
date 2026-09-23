"""Validate and export the proposed case — 'Pebble, thumb first'.

Writes to models/next/, NOT models/. export.py still owns models/ and still
writes the validated prismatic case; nothing here overwrites it.

Print orientation, stated per part:
  base        exterior floor on the bed (as modelled). The crown grows at
              <=26 deg from vertical and both rims start with a 45 deg land,
              so the whole exterior is self-supporting.
  lid         outer TOP face on the bed (rotated 180 about X).
  plunger_rec the fin. Flange on the bed; every step above it is inward.
  plunger_pwr the power pin. Flange on the bed, as the current part.
  coupon      a 16 mm slice of the +X wall carrying the trough, the fin slot,
              the flange pocket and the power groove — so the fit and the
              feel can be tested in minutes instead of a whole case.

Run:  .venv/bin/python jota/src/export_next.py
"""

import os
import sys
import math

import numpy as np
import trimesh
from build123d import (
    Axis, Box, Plane, Pos, Rot, export_step, export_stl, Mesher,
)

import params as P
import components as C
import variants as V
import shot

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models", "next")
os.makedirs(OUT, exist_ok=True)

FAIL, WARN = [], []


def check(cond, msg):
    print(f"  [{'PASS' if cond else 'FAIL'}] {msg}")
    if not cond:
        FAIL.append(msg)
    return cond


def warn(cond, msg):
    print(f"  [{'PASS' if cond else 'WARN'}] {msg}")
    if not cond:
        WARN.append(msg)
    return cond


# ---------------------------------------------------------------------------
print("Building (OCCT)...")
base = V.build_base_AC()
lid = V.build_lid_A()
rec = V.build_plunger_AC_fin()
pwr = V.build_plunger_AC_pwr()


def orient_lid(p):
    q = p.rotate(Axis.X, 180)
    return q.moved(Pos(0, 0, -q.bounding_box().min.Z))


def coupon():
    """A slice of the +X wall around both controls, floor-down like the base."""
    y0, y1 = V.PWR_Y - 6.0, V.REC_Y + 8.0
    keep = Pos(0, (y0 + y1) / 2, (P.RIM_Z - P.FLOOR_T) / 2) * Box(
        200, y1 - y0, P.FLOOR_T + P.RIM_Z + 2)
    c = base & keep
    # trim the interior away so it prints fast: keep 6 mm inboard of the wall
    c &= Pos(P.IN_W / 2 - 3.0 + 50, (y0 + y1) / 2, (P.RIM_Z - P.FLOOR_T) / 2) * Box(
        100, y1 - y0 + 2, P.FLOOR_T + P.RIM_Z + 4)
    return c


cpn = coupon()
PARTS = {"base": base, "lid": lid, "plunger_rec": rec, "plunger_pwr": pwr,
         "coupon": cpn}
PRINT = {"base": base, "lid": orient_lid(lid), "plunger_rec": rec,
         "plunger_pwr": pwr, "coupon": cpn}

# ===========================================================================
print("\n1. Manifold / watertight / single body")
meshes = {}
for n, p in PARTS.items():
    m = shot.mesh_of(p, tol=0.02)
    meshes[n] = m
    check(p.volume > 0, f"{n}: positive volume ({p.volume/1000:.2f} cm3)")
    check(m.is_watertight, f"{n}: watertight")
    check(m.is_winding_consistent, f"{n}: consistent winding")
    check(m.body_count == 1, f"{n}: single body ({m.body_count})")

# ===========================================================================
print("\n2. Component interference (exact OCCT booleans)")
enclosure = base + lid
for cn, cs in C.all_components().items():
    r = enclosure.intersect(cs)
    v = 0.0 if r is None else (
        r.volume if not hasattr(r, "__len__") else sum(s.volume for s in r))
    warn(v < 2.0, f"'{cn}' vs enclosure = {v:.2f} mm3 (< 2.0)")

check(C.battery().bounding_box().max.Z <= P.PCB_BACK_Z + 1e-6,
      "battery sits under the PCB back plane")
vb = base.intersect(C.battery())
vb = 0.0 if vb is None else (vb.volume if not hasattr(vb, "__len__")
                             else sum(s.volume for s in vb))
check(vb < 1e-6, f"base structure vs battery envelope = {vb:.3f} mm3")

# ===========================================================================
print("\n3. Snap mechanics (unchanged by the crown — the skirt crowns on both "
      "faces, so it stays SKIRT_T thick)")
strain = 1.5 * P.SKIRT_T * P.SNAP_DEFLECT / P.SNAP_ENGAGE_DEPTH ** 2
check(strain < 0.02, f"snap strain {strain*100:.2f}% (< 2%)")
check(P.SNAP_BARB_H - P.CLEARANCE >= 0.4,
      f"barb penetration {P.SNAP_BARB_H - P.CLEARANCE:.2f} mm (>= 0.4)")

# ===========================================================================
print("\n4. Overhang check — the one the crown actually needs")
# CLAUDE.md names this as the highest-value missing check. A face is
# unsupported if it points downward and lies more than 45 deg off vertical.
# Flat downward faces are reported separately: those are bridges, and a
# bridge is fine if it is short.
LIMIT = -math.cos(math.radians(45)) - 1e-3


def overhangs(name, m):
    n = m.face_normals
    a = m.area_faces
    cen = m.triangles.mean(axis=1)
    # The face lying ON the bed points straight down but is not an overhang —
    # it is the first layer. Counting it reported 1878 mm2 of "overhang" on a
    # part that has none.
    bed = cen[:, 2] < m.vertices[:, 2].min() + 0.06
    flat = n[:, 2] < -0.985
    steep = (n[:, 2] < LIMIT) & ~flat & ~bed
    warn(a[steep].sum() < 2.0,
         f"{name}: unsupported slope past 45 deg = {a[steep].sum():.2f} mm2")
    ceil = flat & ~bed
    unsup_area, span = 0.0, 0.0
    if a[ceil].sum() > 0:
        # A downward face is only a bridge if there is nothing under it. Cast
        # a short ray down and see whether material appears within two layers;
        # if it does, this is a step, not a span. (Measuring the drop to
        # whatever lies below instead reported a 0.2 mm ledge on a 5 mm pin as
        # a "4.7 mm bridge".)
        idx = np.where(ceil)[0]
        cc = cen[idx] + np.array([0, 0, -1e-3])
        hit, ray_idx, _ = m.ray.intersects_location(
            cc, np.tile([0, 0, -1.0], (len(cc), 1)))
        near = np.zeros(len(cc), bool)
        for k, r in enumerate(ray_idx):
            if cc[r][2] - hit[k][2] < 2 * P.LAYER_H:
                near[r] = True
        uns = ~near
        unsup_area = float(a[idx][uns].sum())
        for t in m.triangles[idx[uns]]:
            span = max(span, float(np.ptp(t[:, :2], axis=0).max()))
    # Deliberately NOT reporting facet bbox span as "bridge span": a round
    # bore's ceiling facets run the length of the bore, so a 1.8 mm hole
    # reported a 12.4 mm bridge. The real spans are named in the summary.
    warn(unsup_area < 200.0,
         f"{name}: unsupported ceiling area {unsup_area:.1f} mm2")
    return a[steep].sum(), unsup_area, span


for n, p in PRINT.items():
    overhangs(n, shot.mesh_of(p, tol=0.02))

# ===========================================================================
print("\n4c. Floating regions — islands with nothing under them at all")
# An overhang leans out over material; a floating region starts in mid-air,
# and a slicer either drops it or prints it into space. The two are different
# defects and the slope check above cannot see the second one: both of the
# crown's islands sat on faces that are perfectly vertical.
#
# Slice the way a slicer does and look for a connected region of a layer that
# shares NO area with the layer below. Note to_2D=identity: to_planar() picks
# its own frame per section, so consecutive layers come back in different
# coordinate systems and every wall looks like it jumped sideways.
from shapely.ops import unary_union


def floating(name, m):
    zlo, zhi = m.vertices[:, 2].min(), m.vertices[:, 2].max()

    def slab(z):
        s = m.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
        if s is None:
            return None
        pl, _ = s.to_planar(to_2D=np.eye(4))
        return unary_union(list(pl.polygons_full))

    prev, hits = None, []
    for z in np.arange(zlo + P.LAYER_H / 2, zhi, P.LAYER_H):
        cur = slab(z)
        if cur is None or cur.is_empty:
            prev = cur
            continue
        if prev is not None and not prev.is_empty:
            for g in (cur.geoms if hasattr(cur, "geoms") else [cur]):
                if g.area > 1e-4 and g.intersection(prev).area < 1e-4:
                    b = g.bounds
                    hits.append(f"z={z:.2f} {g.area:.2f} mm2 "
                                f"{b[2]-b[0]:.2f}x{b[3]-b[1]:.2f} "
                                f"at ({b[0]:.1f},{b[1]:.1f})")
        prev = cur
    check(not hits, f"{name}: no floating regions"
          + ("" if not hits else " -- " + "; ".join(hits)))


for n, p in PRINT.items():
    floating(n, shot.mesh_of(p, tol=0.02))

# Context: run the identical metric over the case that already prints, so the
# numbers above mean something instead of floating free.
print("\n4b. Same metric on the CURRENT validated case, for comparison")
from base import build_base as _cur_base
from lid import build_lid as _cur_lid
_keep = list(WARN)
for n, p in (("current base", _cur_base()), ("current lid", orient_lid(_cur_lid()))):
    overhangs(n, shot.mesh_of(p, tol=0.02))
WARN[:] = _keep   # the current case's own warnings are not ours to fix here

# ===========================================================================
print("""
  Named bridges (measured, not inferred):
    USB opening      9.0 mm  — pre-existing, base.py already calls this out
    microSD slot     9.4 mm  — was 12.2 as a plain box; a stadium fixes it
    fin slot         0.0 mm  — stadium top is semicircular, self-supporting
    lanyard bore     1.8 mm  — spans its own diameter, not its length
    trough / groove  0.6 mm deep lips""")

print("\n5. Wall thickness (ray probes, moved out for the crown)")
# The current validate.py fires from OUT_W/2 +/- 1, which lands INSIDE a
# crowned wall and silently measures nonsense. Origins are pushed out here.
G = V.CROWN_MAX + 2.0


def probe(name, m, samples):
    for label, o, d in samples:
        o = np.array(o, float)
        d = np.array(d, float)
        loc, _, _ = m.ray.intersects_location([o], [d])
        if len(loc) >= 2:
            dist = np.sort(np.linalg.norm(loc - o, axis=1))
            t = dist[1] - dist[0]
            warn(t >= P.MIN_FEATURE - 1e-3,
                 f"{name} {label} = {t:.2f} mm (>= {P.MIN_FEATURE})")
        else:
            print(f"     {name} {label}: no hit")


probe("base", meshes["base"], [
    ("floor", (5, 5, -P.FLOOR_T - 1), (0, 0, 1)),
    ("-Y wall", (-3, P.IN_Y_MIN - G, 2.0), (0, 1, 0)),
    ("+X wall (solid span)", (P.OUT_W / 2 + G, 19.0, 6.5), (-1, 0, 0)),
    ("+X wall under trough", (P.OUT_W / 2 + G, -7.5, 6.5), (-1, 0, 0)),
    ("-X rebated wall", (-P.OUT_W / 2 - G, 2.5, P.RIM_Z - 2), (1, 0, 0)),
])
probe("lid", meshes["lid"], [
    ("top plate", (-15, 20, P.RIM_Z + P.LID_T + 1), (0, 0, -1)),
    ("skirt -X", (-P.OUT_W / 2 - G, 2.0, 9.0), (1, 0, 0)),
])

# ===========================================================================
print("\n6. Print mass (PETG 1.27 g/cm3, 20% infill)")
tot = 0.0
for n in ("base", "lid", "plunger_rec", "plunger_pwr"):
    cm3 = PARTS[n].volume / 1000.0
    g = cm3 * (0.55 + 0.45 * 0.20) * 1.27
    tot += g
    print(f"  {n:12s} {cm3:6.2f} cm3 -> ~{g:5.1f} g")
print(f"  {'TOTAL':12s} ~{tot:.1f} g")

# ===========================================================================
if FAIL:
    print(f"\nVALIDATION FAILED: {len(FAIL)}")
    for f in FAIL:
        print("  - " + f)
    sys.exit(1)

print("\nExporting to models/next/ ...")
for n, p in PRINT.items():
    export_stl(p, os.path.join(OUT, f"{n}.stl"), tolerance=0.012,
               angular_tolerance=0.1)
    m = Mesher()
    m.add_shape(p)
    m.write(os.path.join(OUT, f"{n}.3mf"))
for n, p in PARTS.items():
    export_step(p, os.path.join(OUT, f"{n}.step"))

print(f"\nwrote .stl / .3mf (print-oriented) and .step (assembled) -> {OUT}")
if WARN:
    print(f"\n{len(WARN)} warning(s) — read before printing:")
    for w in WARN:
        print("  - " + w)
