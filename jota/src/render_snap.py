"""Product shots of the snap-fit tray + lid (base.py / lid.py), the chosen
build, in the same four views as the concept studies so they compare like
for like. Per-pixel depth via shot.py, never matplotlib's painter.

Run: .venv/bin/python jota/src/render_snap.py -> renders/concepts/S_snap_*.png
"""

import os
import sys

from build123d import Axis, Box, Pos

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import params as P
import components as C
import shot
from base import build_base
from lid import build_lid, build_plunger

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders", "concepts")

BONE = (0.90, 0.87, 0.80)
SAGE = (0.62, 0.68, 0.58)
CLAY = (0.76, 0.55, 0.43)
PCBC = (0.16, 0.30, 0.22)
INK = (0.22, 0.20, 0.19)
GLASSC = (0.96, 0.96, 0.94)


def plungers(out=0.0):
    ps = []
    for y in (P.BTN1_CTR_Y, P.BTN2_CTR_Y):
        ps.append(build_plunger().rotate(Axis.Y, 90)
                  .moved(Pos(P.OUT_W / 2 + out, y, P.BTN_CTR_Z)))
    return ps


def main():
    os.makedirs(OUT, exist_ok=True)
    base, lid = build_base(), build_lid()
    pcb, disp, cell = C.pcb(), C.display(), C.battery()
    m = shot.mesh_of

    closed = [(m(base), SAGE), (m(lid), BONE)] + [(m(p), CLAY) for p in plungers()]
    shot.render(closed, os.path.join(OUT, "S_snap_closed.png"), elev=30, azim=-50)
    shot.render(closed, os.path.join(OUT, "S_snap_back.png"), elev=-32, azim=130)

    ex = [(m(base), SAGE),
          (m(cell.moved(Pos(0, 0, 6))), INK),
          (m(pcb.moved(Pos(0, 0, 13))), PCBC),
          (m(disp.moved(Pos(0, 0, 13))), GLASSC),
          (m(lid.moved(Pos(0, 0, 26))), BONE)] + [(m(p), CLAY) for p in plungers(out=10)]
    shot.render(ex, os.path.join(OUT, "S_snap_exploded.png"), elev=30, azim=-50, margin=1.18)

    # section through the +Y snap (SNAPS[1] at y = 12): keep y >= 12
    y_cut = P.SNAPS[1][1]
    keep = Pos(0, y_cut + 60, P.RIM_Z / 2) * Box(2 * P.OUT_W, 120, 4 * P.RIM_Z)
    sec = [(m(base & keep), SAGE), (m(lid & keep), BONE)]
    for part, col in ((pcb, PCBC), (disp, GLASSC), (cell, INK)):
        s = part & keep
        if len(s.solids()):
            sec.append((m(s), col))
    shot.render(sec, os.path.join(OUT, "S_snap_section.png"), elev=18, azim=-62)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
