"""Export the v2 parts, each already sitting in its own print orientation.

Nothing here should need rotating in the slicer. Orientation is a design
decision — it decides which faces overhang — so it belongs in the model, not
in a note somebody has to remember.
"""

import os

from build123d import Box, Mesher, Pos, Rot, export_stl

import params as P
from cover import build_cover
from frame import build_frame

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
    print(f"  {name:20s} {cm3:5.2f} cm3  ~{cm3*(0.55+0.45*0.20)*1.24:4.1f} g  "
          f"{b.size.X:5.1f} x {b.size.Y:5.1f} x {b.size.Z:4.1f}  {note}")


frame = build_frame()
cover = build_cover()

# The frame is authored front-face-down already: Z = 0 IS the bed.
write(frame, "frame_v2", "as authored, window face on the bed")

# The cover has to be turned over. Rotate about X rather than mirror —
# mirroring would hand the part and put the tabs on the wrong walls.
cover_p = (Rot(180, 0, 0) * cover).moved(Pos(0, 0, P.F_H))
write(cover_p, "cover_v2", "turned over, outer face on the bed")

# --- tab test -------------------------------------------------------------
# Two fragments that snap to each other, cut around the +X tab whose barb
# runs 0.00..6.00. Worth a few grams to learn whether the snap is a push or
# a fight before committing to a whole frame.
win_f = Pos(17.5, 2.0, 13.8) * Box(9.0, 22.0, 7.6)
win_c = Pos(13.5, 2.0, 16.6) * Box(13.0, 22.0, 2.0)
# The wall on its own is a 2.4 mm sliver 7.6 tall and would topple off the
# bed, so it gets a foot. The foot is below the pocket and touches nothing
# the test is about.
foot = Pos(16.5, 2.0, 9.0) * Box(9.0, 22.0, 2.0)
write((frame & win_f) + foot, "tabtest_wall_v2", "wall, pocket, lead-in, notch")
write((Rot(180, 0, 0) * (cover & win_c)).moved(Pos(0, 0, P.F_H)),
      "tabtest_tab_v2", "one finger, turned over like the cover")
