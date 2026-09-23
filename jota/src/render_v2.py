"""Product shots of the v2 pair. Uses the z-buffer renderer, not render.py:
matplotlib sorts whole triangles by average depth, which paints a closed case
as an open tray the moment two parts interlock — and these two interlock.
"""

import os

from build123d import Box, Pos

import params as P
import shot
from cover import build_cover
from frame import build_frame

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders", "v2")
os.makedirs(OUT, exist_ok=True)

BONE = (0.91, 0.88, 0.82)
CLAY_COVER = (0.78, 0.73, 0.66)
INK = (0.16, 0.14, 0.11)
GLASS = (0.965, 0.95, 0.92)
CELL = (0.86, 0.83, 0.78)
PAPER = (0.965, 0.945, 0.91)

frame = build_frame()
cover = build_cover()
pcb = Pos(0, 0, P.F_PCB_FRONT_Z + P.PCB_T / 2) * Box(P.PCB_W, P.PCB_L, P.PCB_T)
panel = Pos(0, 0, (P.SEAT_Z - P.DISPLAY_RAISE + P.SEAT_Z) / 2) * Box(
    P.PANEL_W, P.PANEL_L, P.DISPLAY_RAISE)
batt = Pos(P.F_BATT_CTR_X, P.F_BATT_CTR_Y,
           (P.F_BATT_FRONT_Z + P.F_BATT_BACK_Z) / 2) * Box(
    P.BATT_W, P.BATT_L, P.BATT_T)

M = shot.mesh_of


def go(name, items, **kw):
    p = shot.render(items, os.path.join(OUT, name), bg=PAPER, **kw)
    print(f"  {name}  {os.path.getsize(p)/1024:.0f} KB")


# +Z is the BACK of the case, so a positive elevation looks at the cover.
go("back_closed.png", [(M(frame), BONE), (M(cover), CLAY_COVER)],
   size=560, elev=30, azim=-54)

# and a negative one at the face
go("front.png", [(M(frame), BONE), (M(panel), GLASS), (M(pcb), INK)],
   size=560, elev=-30, azim=-54)

# the cover from inside: standoffs, tab fingers, relief slots
go("cover_inside.png", [(M(cover), CLAY_COVER)], size=560, elev=-34, azim=-40)

# exploded along the assembly axis, which is the only axis anything moves on
go("exploded.png", [
    (M(frame), BONE),
    (M(Pos(0, 0, 17) * panel), GLASS),
    (M(Pos(0, 0, 17) * pcb), INK),
    (M(Pos(0, 0, 32) * batt), CELL),
    (M(Pos(0, 0, 48) * cover), CLAY_COVER),
], size=560, elev=24, azim=-58, margin=1.02)

# A DETAIL of one engaged tab, clipped tight. The wide section shot was
# useless at this scale: the whole mechanism is 2 mm tall on a 60 mm part.
win = Pos(18.0, 3.0, 15.6) * Box(9.0, 7.0, 7.0)
go("tab_detail.png", [(M(frame & win), BONE), (M(cover & win), CLAY_COVER)],
   size=560, elev=12, azim=64, margin=1.10)
