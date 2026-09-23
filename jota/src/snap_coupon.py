"""Slide-lock coupons — crops of the REAL case1 joint.

SPAN pair (the one to print): a strip across the whole case at x ~ -12,
where a +Y site and a -Y site line up, so BOTH tongues and BOTH walls are
in the piece. That matters because the tab's underside is a 45 deg cam:
lifting pushes the strip INWARD, off the tab, and the only thing that stops
the inward move is the opposite wall (lap clearance away). ~30 minutes.

SITE pair (kept for reference, do not print as a hold test): one tab site
only. Printed 2026-09-19: it dropped and slid, then lifted straight off —
by construction, there is no far wall to back the strip. It still proves
the drop/slide clearances.

The KEY is exported with the case (case1_key) and is the one part whose
fit you may retune — reprint the key at +-0.1, never a case half.
"""
import os
import sys

os.environ.setdefault("C1_VARIANT", "header")     # the board being printed
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from build123d import Box, Mesher, Pos, export_stl

import params as P
from case1 import build_back, build_front

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "models", "next", "coupons")
os.makedirs(OUT, exist_ok=True)

# crop around the +Y mid tab site, wide enough for window + travel
XC, TW = P.C1_SLIDE_SITES_PY[1]
X0 = XC - TW / 2 - P.C1_WIN_C - 3.0
X1 = XC + P.C1_SLIDE_T + TW / 2 + P.C1_WIN_C + 3.0
Y0 = 18.0

def crop(part, x0, x1, y0, y1):
    z0, z1 = part.bounding_box().min.Z - 1, part.bounding_box().max.Z + 1
    return part & Pos((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) * \
        Box(x1 - x0, y1 - y0, z1 - z0)

def write(part, name, note):
    export_stl(part, os.path.join(OUT, f"{name}.stl"), tolerance=0.012,
               angular_tolerance=0.1)
    try:
        m = Mesher(); m.add_shape(part); m.write(os.path.join(OUT, f"{name}.3mf"))
    except Exception:
        pass                       # a coupon needs only its STL
    b = part.bounding_box()
    print(f"  {name:22s} {part.volume/1000:4.2f} cm3  "
          f"{b.size.X:5.1f} x {b.size.Y:5.1f} x {b.size.Z:5.1f}   {note}")

if __name__ == "__main__":
    f, b = build_front(False), build_back(False)
    fb, bb = f.bounding_box(), b.bounding_box()
    # front authored is mirrored in x
    write(crop(f, -X1, -X0, Y0, fb.max.Y + 1), "slide_front",
          f"window + notch of the x={XC:+.1f} site")
    write(crop(b, X0, X1, Y0, bb.max.Y + 1), "slide_back",
          f"tab of the same site; travel {P.C1_SLIDE_T}")
    # the span pair: x-strip through the -12 sites, full Y
    SX0, SX1 = -16.5, -6.5
    sf = crop(f, -SX1, -SX0, fb.min.Y - 1, fb.max.Y + 1)
    # the display window crosses this strip and would leave a 2.3 mm bar of
    # face joining the two ends; fill it (coupon only) so the piece is rigid
    sf += Pos((-SX1 - SX0) / 2, 0, (P.C1_FACE_T + P.C1_DISP_D) / 2) * \
        Box(SX1 - SX0, 2 * P.C1_POCKET_L / 2 - 2.0, P.C1_FACE_T + P.C1_DISP_D)
    write(sf, "span_front", "both tongues, +Y and -Y sites at x~-12 (window filled)")
    write(crop(b, SX0, SX1, bb.min.Y - 1, bb.max.Y + 1), "span_back",
          f"both walls + tabs; travel {P.C1_SLIDE_T}")
    print("\n  SPAN pair: drop the front on shifted one travel toward the")
    print("  notch side, slide home, lift. Free lift ~0.3, then the far wall")
    print("  backs the strip and it stops. SITE pair cannot hold on its own.")
