"""Export v3. Each part already sits in its own print orientation — that is a
design decision, not a slicer convenience, so it lives in the model."""

import os

from build123d import Mesher, Pos, Rot, export_stl

import params as P
from shell3 import build_back, build_front, peg_coupon

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models", "next")
os.makedirs(OUT, exist_ok=True)


def write(part, name, note=""):
    export_stl(part, os.path.join(OUT, f"{name}.stl"),
               tolerance=0.012, angular_tolerance=0.1)
    m = Mesher()
    m.add_shape(part)
    m.write(os.path.join(OUT, f"{name}.3mf"))
    cm3 = part.volume / 1000
    b = part.bounding_box()
    print(f"  {name:18s} {cm3:5.2f} cm3  ~{cm3*(0.55+0.45*0.20)*1.24:4.1f} g  "
          f"{b.size.X:5.1f} x {b.size.Y:5.1f} x {b.size.Z:4.1f}  {note}")


write(peg_coupon(), "pegtest_v3", "PRINT THIS — window-face-down, as exported")
write(build_front(), "front_v3", "as authored, window face on the bed")
write((Rot(180, 0, 0) * build_back()).moved(Pos(0, 0, P.V3_H)),
      "back_v3", "turned over — NOT yet passing its printability checks")
