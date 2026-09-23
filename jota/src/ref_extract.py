"""Harvest every case-1 dimension out of the reference case's own STL.

Run: .venv/bin/python jota/src/ref_extract.py

The reference (`jota/ref/refcase_{top,bottom}.stl`) is a real object that
works. Nothing here is measured by hand and nothing is typed from memory —
each number below is read off the mesh, so it can be re-derived at any time
by re-running this file. That is the whole point: `params.py` carries the
numbers, this file carries their provenance.

Frame. The reference is authored with its long axis on X, its short axis on
Z and its thickness on Y, bottom-half-floor upward. Ours is long-on-Y,
short-on-X, back-floor at z=0. The map is a proper rotation plus a shift:

    our_x = ref_z          our_y = -ref_x          our_z = -ref_y + 10.49

det = +1, so it rotates and does not mirror. It puts the reference's open
(connector) end at our -Y, which is where our USB is, and it is the flip the
CASE 1 block of params.py describes. Applying it to EVERY number — not just
to the end opening — is the correction this file exists to make.
"""

import os
import numpy as np
import trimesh

REF = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ref")
Z_SHIFT = 10.49           # puts the reference bottom half's outer floor at z=0

T = np.eye(4)
T[:3, :3] = np.array([[0, 0, 1], [-1, 0, 0], [0, -1, 0]], float)
T[2, 3] = Z_SHIFT


def load():
    bot = trimesh.load(os.path.join(REF, "refcase_bottom.stl"))
    top = trimesh.load(os.path.join(REF, "refcase_top.stl"))
    for m in (bot, top):
        m.apply_transform(T)
    return bot, top


def runs(mesh, axis, fixed, lo, hi, n=3000):
    """Solid intervals along `axis`, at the two other coords given by `fixed`."""
    t = np.linspace(lo, hi, n)
    pts = np.empty((n, 3))
    k = 0
    for a in range(3):
        if a == axis:
            pts[:, a] = t
        else:
            pts[:, a] = fixed[k]
            k += 1
    inside = mesh.contains(pts)
    out, start = [], None
    for i, v in enumerate(inside):
        if v and start is None:
            start = t[i]
        if not v and start is not None:
            out.append((start, t[i - 1]))
            start = None
    if start is not None:
        out.append((start, t[-1]))
    return out


def show(label, iv):
    print(f"  {label:44s} " + "  ".join(
        f"[{a:+7.3f},{b:+7.3f}] = {b - a:6.3f}" for a, b in iv) or "  (none)")


def main():
    bot, top = load()
    print(__doc__.split("Frame.")[0].strip() + "\n")
    for nm, m in (("bottom (our BACK)", bot), ("top (our FRONT)", top)):
        b = m.bounds
        print(f"  {nm:18s} bbox {b[1][0]-b[0][0]:6.2f} x {b[1][1]-b[0][1]:6.2f}"
              f" x {b[1][2]-b[0][2]:6.2f}   z [{b[0][2]:+6.2f}, {b[1][2]:+6.2f}]"
              f"   {m.volume/1000:5.2f} cm3")

    print("\n--- heights ---")
    show("back: floor+wall, ray up at (0,0)", runs(bot, 2, (0, 0), -1, 14))
    show("front: face beyond display pocket (0,+22)", runs(top, 2, (0, 22), -1, 15))
    show("front: face inside display pocket (0,-15)", runs(top, 2, (0, -15), -1, 15))

    print("\n--- the lap joint (this is what we missed) ---")
    for z in (2.0, 3.5, 5.0, 6.5, 8.0, 9.0):
        show(f"back  wall, ray across X at y=0, z={z:4.1f}", runs(bot, 0, (0, z), -21, 0))
        show(f"front tongue, ray across X at y=0, z={z:4.1f}", runs(top, 0, (0, z), -21, 0))

    print("\n--- board pocket and window, in OUR frame ---")
    for z in (11.9, 12.4, 12.9, 13.4):
        show(f"front, sweep Y at x=0, z={z:5.2f}", runs(top, 1, (0, z), -27.4, 27.4))
    for z in (11.9, 12.4, 12.9, 13.4):
        show(f"front, sweep X at y=-2.88, z={z:5.2f}", runs(top, 0, (-2.88, z), -19.9, 19.9))

    print("\n--- which end is open ---")
    for z in (3.0, 5.0, 7.0):
        show(f"back, sweep Y at x=0, z={z:4.1f}", runs(bot, 1, (0, z), -27.4, 27.4))
        show(f"front, sweep Y at x=0, z={z:4.1f}", runs(top, 1, (0, z), -27.4, 27.4))

    print("\n--- screw holes ---")
    for y in (-21.6, 21.6):
        show(f"back, sweep X at y={y:+6.2f}, z=1.0", runs(bot, 0, (y, 1.0), -21, 21))


if __name__ == "__main__":
    main()
