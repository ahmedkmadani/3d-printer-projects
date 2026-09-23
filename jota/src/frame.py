"""Front frame — the structural half of the v2 case.

Prints window-face-down. Z = 0 is the outer front face and the part grows
+Z, which is also the print direction, so the face anyone looks at and the
recess that decides where the screen lands are both bed surfaces.

Only material is ever REMOVED as Z rises (face -> panel recess -> interior),
so there is nothing to overhang and no support anywhere in the part.

What is here now is the board seat and nothing else: shell, window, panel
recess, seat ledge, board pocket. The wall openings (USB, SD, button bores,
mic/LED pinholes, speaker grille) and the tab pockets are still to come —
they do not touch whether the board fits, which is what this is for.
"""

from build123d import (
    Align, Axis, Box, Circle, Part, Plane, Polyline, Pos, Rectangle,
    RectangleRounded, chamfer, extrude, make_face,
)

import params as P


def _shell() -> Part:
    """Solid block, hollowed from the back, with the panel recess sunk into
    the floor of that hollow and the window pierced through the face."""
    fp = Pos(0, P.F_IN_CTR_Y) * RectangleRounded(P.F_OUT_W, P.F_OUT_L,
                                                 P.EDGE_FILLET_R)
    solid = extrude(Plane.XY * fp, P.F_H)

    # interior: the board pocket, open to the back. Deliberately loose — it
    # locates nothing, the panel recess does that.
    solid -= extrude(
        Plane.XY.offset(P.SEAT_Z)
        * Pos(0, P.F_IN_CTR_Y)
        * RectangleRounded(P.F_IN_W, P.F_IN_L, P.F_IN_R),
        P.F_H - P.SEAT_Z,
    )

    # corner reliefs, so a sharp board corner is never asked to fit inside
    # the pocket's fillet. Only the -Y pair actually cut anything; the +Y
    # pair sit well inside the pocket because the speaker bay is there.
    for sx in (-1, 1):
        for sy in (-1, 1):
            solid -= extrude(
                Plane.XY.offset(P.SEAT_Z)
                * Pos(sx * P.PCB_W / 2, sy * P.PCB_L / 2)
                * Circle(P.PCB_CORNER_RELIEF_R),
                P.F_H - P.SEAT_Z,
            )

    # panel recess, sunk from the seat plane back up toward the face. The
    # annulus left between it and the pocket IS the seat ledge.
    solid -= extrude(
        Plane.XY.offset(P.FACE_T) * Rectangle(P.PANEL_RECESS_W, P.PANEL_RECESS_L),
        P.PANEL_RECESS_D,
    )
    # corner reliefs, so the pane's sharp corners never have to fit inside
    # the radius a nozzle leaves in a printed internal corner
    for sx in (-1, 1):
        for sy in (-1, 1):
            solid -= extrude(
                Plane.XY.offset(P.FACE_T)
                * Pos(sx * P.PANEL_RECESS_W / 2, sy * P.PANEL_RECESS_L / 2)
                * Circle(P.PANEL_CORNER_RELIEF_R),
                P.PANEL_RECESS_D,
            )
    # lead-in at the mouth: the pane is guided in, not aimed at a hole
    solid -= extrude(
        Plane.XY.offset(P.SEAT_Z - P.PANEL_LEADIN)
        * Rectangle(P.PANEL_RECESS_W + 2 * P.PANEL_LEADIN,
                    P.PANEL_RECESS_L + 2 * P.PANEL_LEADIN),
        P.PANEL_LEADIN,
    )

    # window through the face
    solid -= extrude(
        Plane.XY * Pos(P.ACTIVE_CTR_X, P.ACTIVE_CTR_Y) * Rectangle(P.WINDOW, P.WINDOW),
        P.FACE_T,
    )
    return solid


def tab_geometry(root: float, sign: int) -> tuple[float, float]:
    """Barb span in Y for a finger rooted at `root` running in `sign`.

    The barb sits at the finger's free TIP, because strain goes as the
    SQUARE of the distance from the root — a barb halfway along costs four
    times the strain for the same retention.
    """
    tip = root + sign * P.TAB_L
    return tuple(sorted((tip, tip - sign * P.TAB_BARB_L)))


def _tab_cuts() -> list[Part]:
    """Pocket, lead-in and release notch, for each of the four tabs.

    The LEAD-IN is the part worth reading. The barb stands 0.85 proud and the
    wall face it has to pass sits only TAB_LIP (0.90) behind the pocket, so
    the finger has 0.90 mm of travel in which to be pushed 0.45 aside. Put
    that ramp on the barb and it has to fit inside the barb's own 0.80 of
    height — a 59-degree insertion angle, which is a fight. Put it on the
    frame's back lip, where there is 2.40 of wall to spend, and the same
    deflection happens over the full 0.90: 26.5 degrees, which is a push.
    """
    cuts = []
    z_top = P.TAB_POCKET_Z0 + P.TAB_POCKET_H
    for wall, root, sign in P.TAB_SPECS:
        sx = 1.0 if wall == "+X" else -1.0
        b0, b1 = tab_geometry(root, sign)
        y_c, y_l = (b0 + b1) / 2, (b1 - b0) + 0.6      # 0.3 clearance per end
        xi = sx * P.F_IN_W / 2

        cuts.append(
            Pos(xi + sx * P.TAB_POCKET_D / 2, y_c, P.TAB_POCKET_Z0 + P.TAB_POCKET_H / 2)
            * Box(P.TAB_POCKET_D, y_l, P.TAB_POCKET_H)
        )

        # Overlap the pocket and the back face by a hair. Cutters that share
        # an exact face with what they cut leave coincident geometry that
        # OCCT tolerates and the 3MF writer does not.
        pts = [(xi - sx * 0.05, z_top - 0.05),
               (xi + sx * P.TAB_ENGAGE, P.F_H + 0.05),
               (xi - sx * 0.05, P.F_H + 0.05)]
        cuts.append(
            extrude(make_face(Plane.XZ * Polyline(*pts, close=True)),
                    y_l / 2, both=True).moved(Pos(0, y_c, 0))
        )

        # release notch: through what is left of the wall, so a fingernail
        # reaches the barb from outside without prising the case apart.
        outer = sx * P.F_OUT_W / 2
        d = abs(outer - (xi + sx * P.TAB_POCKET_D))
        cuts.append(
            Pos(xi + sx * (P.TAB_POCKET_D + d / 2 - 0.1), y_c,
                P.TAB_POCKET_Z0 + P.TAB_POCKET_H / 2)
            * Box(d + 0.2, P.TAB_NOTCH_L, P.TAB_POCKET_H)
        )
    return cuts


def build_frame() -> Part:
    frame = _shell()
    for c in _tab_cuts():
        frame -= c
    # front-face outer rim chamfer. This edge prints ON the bed, so it must
    # be a chamfer and not a fillet — same reason as v1's rims.
    face = frame.faces().sort_by(Axis.Z).first
    frame = chamfer(face.outer_wire().edges(), P.RIM_CHAMFER)
    return frame


def seat_coupon() -> Part:
    """The cheapest print that answers 'does the board sit right?'.

    Everything past the first few mm of the board pocket is irrelevant to
    that question and is most of the print time, so it is cut away.
    """
    from build123d import Box
    cut_z = P.SEAT_Z + 4.0
    keep = Pos(0, P.F_IN_CTR_Y, cut_z / 2) * Box(P.F_OUT_W + 10, P.F_OUT_L + 10, cut_z)
    return build_frame() & keep


if __name__ == "__main__":
    f = build_frame()
    b = f.bounding_box()
    print(f"frame: {f.volume/1000:.2f} cm3, bbox {b.size.X:.2f} x {b.size.Y:.2f} "
          f"x {b.size.Z:.2f}")
