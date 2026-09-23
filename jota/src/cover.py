"""Back cover — the flat half of the v2 case.

Prints BACK-face-down — outer face on the bed, standoffs pointing up. There
is no choice about it: the standoffs project from the front face, so printing
that face down would stand the part on four posts with the plate bridging
6.9 mm of air.

That orientation costs something, and it is worth naming rather than hiding.
Each barb's retention face — the one that bears on the pocket lip — is the
FIRST layer of the barb, so it starts as a 0.85 mm unsupported ledge, 6 mm
long, attached along one edge. It will print with a slightly rough underside.
It cannot be chamfered away: a 45-degree lead there would be a ramp on the
face that does the holding, and the cover would cam itself out. It cannot be
gusseted either — the gusset would land exactly where the lip has to be.
0.85 mm is a short bridge and perimeters span it; this is the normal way a
printed snap cover is made, not a compromise peculiar to this one.

It does three jobs and no others: close the box, hold the battery, and press
the board onto its seat through four standoffs and a strip of foam tape.

The tabs are fingers cut from the plate's own edge, so they flex WITHIN the
layer plane. That is the whole reason there is no PETG requirement any more:
the old skirt snaps bent normal to the layers, which is where PLA splits.
"""

from build123d import Box, Circle, Part, Plane, Pos, RectangleRounded, extrude

import params as P
from frame import tab_geometry

X_EDGE = P.F_IN_W / 2 - P.COVER_FIT          # 18.20
COVER_T = P.F_H - P.F_COVER_Z                # 2.00


def _plate() -> Part:
    return extrude(
        Plane.XY.offset(P.F_COVER_Z)
        * Pos(0, P.F_IN_CTR_Y)
        * RectangleRounded(P.F_IN_W - 2 * P.COVER_FIT,
                           P.F_IN_L - 2 * P.COVER_FIT,
                           P.F_IN_R - P.COVER_FIT),
        COVER_T,
    )


def _tabs(plate: Part) -> Part:
    """Cut each finger free, then put its barb back on."""
    z_mid = P.F_COVER_Z + COVER_T / 2
    for wall, root, sign in P.TAB_SPECS:
        sx = 1.0 if wall == "+X" else -1.0
        xe = sx * X_EDGE
        tip = root + sign * P.TAB_L

        # the long relief slot, inboard of the finger
        y0, y1 = sorted((root, tip + sign * P.TAB_SLOT_W))
        plate -= (
            Pos(xe - sx * (P.TAB_T + P.TAB_SLOT_W / 2), (y0 + y1) / 2, z_mid)
            * Box(P.TAB_SLOT_W, y1 - y0, COVER_T + 1)
        )
        # and the cut across the tip, which is what makes it a cantilever
        # rather than a stiff fixed-fixed beam
        y2, y3 = sorted((tip, tip + sign * P.TAB_SLOT_W))
        plate -= (
            Pos(xe - sx * (P.TAB_T + P.TAB_SLOT_W) / 2 + sx * 1.0,
                (y2 + y3) / 2, z_mid)
            * Box(2 * (P.TAB_T + P.TAB_SLOT_W), y3 - y2, COVER_T + 1)
        )

        b0, b1 = tab_geometry(root, sign)
        plate += (
            Pos(xe + sx * P.TAB_BARB / 2, (b0 + b1) / 2,
                P.F_COVER_Z + P.TAB_Z_INSET + P.TAB_BARB_H / 2)
            * Box(P.TAB_BARB, b1 - b0, P.TAB_BARB_H)
        )
    return plate


def _standoffs() -> Part:
    """Four posts reaching forward to the board. They stop PAD_T short of it:
    the foam takes up whatever the display stack really measures, which is
    what makes the Touch variant's extra thickness a non-event."""
    out = None
    for x, y in P.STANDOFF_CTRS:
        s = extrude(
            Plane.XY.offset(P.F_COVER_Z - P.STANDOFF_H) * Pos(x, y)
            * Circle(P.STANDOFF_D / 2),
            P.STANDOFF_H,
        )
        out = s if out is None else out + s
    return out


def build_cover() -> Part:
    return _tabs(_plate()) + _standoffs()


if __name__ == "__main__":
    c = build_cover()
    b = c.bounding_box()
    print(f"cover: {c.volume/1000:.2f} cm3, bbox {b.size.X:.2f} x {b.size.Y:.2f} "
          f"x {b.size.Z:.2f}")
