"""v3 — the board locates on its own mounting holes.

Two printed pegs through HOLE_PITCH_X / HOLE_PITCH_Y, which were measured
with calipers on the rev-V2 board. Everything else is deliberately loose.
See the v3 block in params.py for why a peg beats a pocket on this printer.

The FRONT SHELL prints window-face-down, Z = 0 on the bed. Material only
recedes as Z rises — face, then panel recess, then board pocket — so nothing
in it overhangs and it needs no support. The pegs are the only thing that
grows upward, and they are cones over cylinders, which are self-supporting.

The BACK TRAY prints outer-face-down. Its rim flange is an inward ledge,
which is an overhang, so it is carried on a 45-degree gusset.
"""

import math

from build123d import (
    Align, Axis, Box, Circle, Cone, Cylinder, Part, Plane, Pos, Rectangle,
    Polyline, RectangleRounded, Rot, chamfer, extrude, make_face,
)

import params as P

JOIN_ANGLE = math.degrees(math.atan2(P.HOLE_PITCH_Y, P.HOLE_PITCH_X))


def tab_span(root: float, sign: int) -> tuple[float, float]:
    """Barb span in Y. The barb sits at the finger's free tip: strain goes as
    the SQUARE of the distance from the root, so a barb halfway along costs
    four times the strain for the same retention."""
    tip = root + sign * P.V3_TAB_L
    return tuple(sorted((tip, tip - sign * P.V3_TAB_BARB_L)))


# ---------------------------------------------------------------------------
# front shell
# ---------------------------------------------------------------------------
def _front_body() -> Part:
    fp = Pos(0, P.V3_IN_CTR_Y) * RectangleRounded(P.V3_OUT_W, P.V3_OUT_L,
                                                 P.EDGE_FILLET_R)
    solid = extrude(Plane.XY * fp, P.V3_PART_Z)

    inner = Pos(0, P.V3_IN_CTR_Y) * RectangleRounded(P.V3_IN_W, P.V3_IN_L,
                                                     P.V3_IN_R)
    # board pocket, open to the back and locating nothing
    solid -= extrude(Plane.XY.offset(P.V3_SEAT_Z) * inner,
                     P.V3_PART_Z - P.V3_SEAT_Z)
    for sx in (-1, 1):
        for sy in (-1, 1):
            solid -= extrude(
                Plane.XY.offset(P.V3_SEAT_Z)
                * Pos(sx * P.PCB_W / 2, sy * P.PCB_L / 2)
                * Circle(P.V3_PCB_RELIEF_R),
                P.V3_PART_Z - P.V3_SEAT_Z)

    # panel recess — three times v2's clearance, because it is a datum for
    # nothing now and its tolerance therefore costs nothing
    solid -= extrude(Plane.XY.offset(P.V3_FACE_T)
                     * Rectangle(P.V3_RECESS_W, P.V3_RECESS_L), P.V3_RECESS_D)
    for sx in (-1, 1):
        for sy in (-1, 1):
            solid -= extrude(
                Plane.XY.offset(P.V3_FACE_T)
                * Pos(sx * P.V3_RECESS_W / 2, sy * P.V3_RECESS_L / 2)
                * Circle(P.V3_RECESS_RELIEF_R), P.V3_RECESS_D)
    solid -= extrude(
        Plane.XY.offset(P.V3_SEAT_Z - P.V3_RECESS_LEADIN)
        * Rectangle(P.V3_RECESS_W + 2 * P.V3_RECESS_LEADIN,
                    P.V3_RECESS_L + 2 * P.V3_RECESS_LEADIN),
        P.V3_RECESS_LEADIN)

    # window
    solid -= extrude(Plane.XY * Pos(P.V3_WIN_CTR_X, P.V3_WIN_CTR_Y)
                     * Rectangle(P.V3_WIN_W, P.V3_WIN_L), P.V3_FACE_T)
    return solid


def _pegs() -> Part:
    out = None
    for i, (x, y) in enumerate(P.V3_HOLE_XY):
        r = P.V3_PEG_D_DRAWN / 2
        peg = extrude(Plane.XY.offset(P.V3_SEAT_Z) * Pos(x, y) * Circle(r),
                      P.V3_PEG_LAND)
        peg += Pos(x, y, P.V3_SEAT_Z + P.V3_PEG_LAND) * Cone(
            r, P.V3_PEG_TIP_D / 2, P.V3_PEG_TIP,
            align=(Align.CENTER, Align.CENTER, Align.MIN))
        if i == 1:
            # diamond: full width ACROSS the line joining the pegs, narrowed
            # ALONG it, so two round pegs on a diagonal cannot over-constrain
            slab = Rot(0, 0, JOIN_ANGLE - 90) * Box(
                40, P.V3_PEG_D_DRAWN - P.V3_PEG_FLAT, 40)
            peg &= Pos(x, y, P.V3_SEAT_Z + P.V3_PEG_H / 2) * slab
        out = peg if out is None else out + peg
    return out


def _grooves() -> list[Part]:
    """Groove in the collar's inner face for the tray's hooks to catch."""
    cuts = []
    for wall, root, sign in P.V3_TAB_SPECS:
        sx = 1.0 if wall == "+X" else -1.0
        b0, b1 = tab_span(root, sign)
        y_c, y_l = (b0 + b1) / 2, (b1 - b0) + 0.6
        cuts.append(
            Pos(sx * (P.V3_IN_W / 2 + P.V3_GROOVE_D / 2), y_c,
                (P.V3_HOOK_Z0 + P.V3_HOOK_Z1) / 2)
            * Box(P.V3_GROOVE_D, y_l, P.V3_HOOK_Z1 - P.V3_HOOK_Z0)
        )
    return cuts


def build_front() -> Part:
    f = _front_body() + _pegs()
    for c in _grooves():
        f -= c
    face = f.faces().sort_by(Axis.Z).first
    return chamfer(face.outer_wire().edges(), P.RIM_CHAMFER)


def peg_coupon() -> Part:
    """The whole strategy, for two grams.

    Everything above the board's seat plane is irrelevant to the one question
    that matters — do the pegs go through the board's holes — and everything
    below it is window and bezel. What is left is the end ledges, both pegs,
    and enough of the outline to hold them in register.
    """
    keep = Pos(0, 0, (P.V3_SEAT_Z - 1.6 + P.V3_SEAT_Z + P.V3_PEG_H) / 2) * Box(
        P.V3_OUT_W + 5, P.V3_OUT_L + 5, P.V3_PEG_H + 1.6)
    c = build_front() & keep
    return c.moved(Pos(0, 0, -(P.V3_SEAT_Z - 1.6)))


if __name__ == "__main__":
    f = build_front()
    b = f.bounding_box()
    print(f"front: {f.volume/1000:.2f} cm3  {b.size.X:.2f} x {b.size.Y:.2f} "
          f"x {b.size.Z:.2f}")
    c = peg_coupon()
    bc = c.bounding_box()
    print(f"coupon: {c.volume/1000:.2f} cm3  {bc.size.X:.2f} x {bc.size.Y:.2f} "
          f"x {bc.size.Z:.2f}  z {bc.min.Z:.2f}..{bc.max.Z:.2f}")


# ---------------------------------------------------------------------------
# back tray
# ---------------------------------------------------------------------------
def build_back() -> Part:
    fp = Pos(0, P.V3_IN_CTR_Y) * RectangleRounded(P.V3_OUT_W, P.V3_OUT_L,
                                                  P.EDGE_FILLET_R)
    body = extrude(Plane.XY.offset(P.V3_PART_Z) * fp, P.V3_BACK_H)
    inner = Pos(0, P.V3_IN_CTR_Y) * RectangleRounded(P.V3_IN_W, P.V3_IN_L,
                                                     P.V3_IN_R)
    body -= extrude(Plane.XY.offset(P.V3_PART_Z) * inner,
                    P.V3_H - P.V3_FLOOR_T - P.V3_PART_Z)

    # Flange: a flat annulus reaching UP past the parting line, which the
    # fingers are cut from. Flush with the tray wall below the joint, stepped
    # in by the fit above it so it can enter the front shell.
    def ring(w_off, z0, z1):
        o = Pos(0, P.V3_IN_CTR_Y) * RectangleRounded(
            P.V3_IN_W - 2 * w_off, P.V3_IN_L - 2 * w_off,
            max(P.V3_IN_R - w_off, 0.6))
        i = Pos(0, P.V3_IN_CTR_Y) * RectangleRounded(
            P.V3_IN_W - 2 * (w_off + P.V3_FLANGE_W),
            P.V3_IN_L - 2 * (w_off + P.V3_FLANGE_W),
            max(P.V3_IN_R - w_off - P.V3_FLANGE_W, 0.6))
        return extrude(Plane.XY.offset(z0) * (o - i), z1 - z0)

    body += ring(0.0, P.V3_PART_Z, P.V3_FLANGE_Z1)
    body += ring(P.V3_TAB_FIT, P.V3_FLANGE_Z0, P.V3_PART_Z)

    # 45-degree gusset under the flange. It is a 4.0 mm inward ledge at the
    # top of a printed wall; without it the flange prints in mid-air.
    #
    # It has to be built as a BLOCK MINUS AN EXPANDING VOID, not as a tapered
    # ring: tapering a ring moves its inner AND outer boundary together, so
    # the ring merely shifts inward and gussets nothing. That bug shipped
    # once here and the thickness probe is what caught it.
    g = P.V3_FLANGE_GUSSET
    block = extrude(
        Plane.XY.offset(P.V3_FLANGE_Z1)
        * Pos(0, P.V3_IN_CTR_Y)
        * RectangleRounded(P.V3_IN_W, P.V3_IN_L, P.V3_IN_R), g)
    void = extrude(
        Plane.XY.offset(P.V3_FLANGE_Z1)
        * Pos(0, P.V3_IN_CTR_Y)
        * RectangleRounded(P.V3_IN_W - 2 * g, P.V3_IN_L - 2 * g,
                           max(P.V3_IN_R - g, 0.6)), g, taper=-45)
    body += block - void

    # fingers, and the hook on each
    xe0 = P.V3_IN_W / 2 - P.V3_TAB_FIT
    for wall, root, sign in P.V3_TAB_SPECS:
        sx = 1.0 if wall == "+X" else -1.0
        xe = sx * xe0
        tip = root + sign * P.V3_TAB_L
        z_mid = (P.V3_FLANGE_Z0 + P.V3_FLANGE_Z1) / 2
        z_h = P.V3_FLANGE_Z1 - P.V3_FLANGE_Z0 + 2

        y0, y1 = sorted((root, tip + sign * P.V3_TAB_SLOT))
        body -= (Pos(xe - sx * (P.V3_TAB_T + P.V3_TAB_SLOT / 2),
                     (y0 + y1) / 2, z_mid)
                 * Box(P.V3_TAB_SLOT, y1 - y0, z_h))
        y2, y3 = sorted((tip, tip + sign * P.V3_TAB_SLOT))
        body -= (Pos(xe - sx * (P.V3_TAB_T + P.V3_TAB_SLOT) / 2 + sx * 1.0,
                     (y2 + y3) / 2, z_mid)
                 * Box(2 * (P.V3_TAB_T + P.V3_TAB_SLOT), y3 - y2, z_h))

        # The hook is a WEDGE, not a block, and the taper does two jobs at
        # once. It is the assembly lead-in — the tray meets the front shell
        # travelling toward lower Z, so the low-Z face is what has to be
        # ramped. And it is the print support: the tray builds from its floor
        # toward this end, so a tapering face is one that recedes.
        # The retention face at V3_HOOK_Z1 stays square. It cannot be ramped:
        # a ramp on the face that does the holding lets the tray cam itself
        # off. So its first layer is a 1.10 mm ledge, attached along one edge
        # and spanned by perimeters. That is the normal way a printed hook is
        # made, and section 8 reports it rather than hiding it.
        b0, b1 = tab_span(root, sign)
        pts = [(xe + sx * P.V3_HOOK_TIP, P.V3_HOOK_Z0),
               (xe + sx * P.V3_TAB_BARB, P.V3_HOOK_Z1),
               (xe, P.V3_HOOK_Z1), (xe, P.V3_HOOK_Z0)]
        body += extrude(make_face(Plane.XZ * Polyline(*pts, close=True)),
                        (b1 - b0) / 2, both=True).moved(Pos(0, (b0 + b1) / 2, 0))

    for x, y in P.V3_STANDOFF_CTRS:
        body += extrude(
            Plane.XY.offset(P.V3_PCB_BACK_Z + P.V3_PAD_T) * Pos(x, y)
            * Circle(P.V3_STANDOFF_D / 2),
            P.V3_H - P.V3_FLOOR_T - P.V3_PCB_BACK_Z - P.V3_PAD_T)
    return body


def build_back_print() -> Part:
    """Turned over: outer face on the bed, flange and standoffs pointing up."""
    return (Rot(180, 0, 0) * build_back()).moved(Pos(0, 0, P.V3_H))
