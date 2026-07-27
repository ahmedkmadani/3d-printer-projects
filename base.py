"""Base tray: battery bay, PCB corner-clamp posts, all wall openings,
snap barbs. Prints floor-down, no supports (every ledge has a 45-degree
underside chamfer; the widest bridge is the 9.0 mm USB opening top).
"""

from build123d import (
    Align, Axis, Box, Cylinder, Part, Plane, Polyline, Pos, Rot,
    RectangleRounded, chamfer, extrude, make_face,
)

import params as P

EXT_CTR_Y = (P.IN_Y_MIN + P.IN_Y_MAX) / 2          # exterior/interior Y center
IN_R = max(P.EDGE_FILLET_R - P.WALL_T, 0.6)        # cavity corner radius


def _shell() -> Part:
    """Two-tier outer shell (lower full, upper rebated) minus cavity."""
    lower = extrude(
        Plane.XY.offset(-P.FLOOR_T)
        * Pos(0, EXT_CTR_Y)
        * RectangleRounded(P.OUT_W, P.OUT_L, P.EDGE_FILLET_R),
        P.FLOOR_T + P.RIM_Z - P.SKIRT_DEPTH,
    )
    upper = extrude(
        Plane.XY.offset(P.RIM_Z - P.SKIRT_DEPTH)
        * Pos(0, EXT_CTR_Y)
        * RectangleRounded(
            P.OUT_W - 2 * P.REBATE, P.OUT_L - 2 * P.REBATE,
            P.EDGE_FILLET_R - P.REBATE,
        ),
        P.SKIRT_DEPTH,
    )
    shell = lower + upper
    cavity = extrude(
        Plane.XY * Pos(0, EXT_CTR_Y) * RectangleRounded(P.IN_W, P.IN_L, IN_R),
        P.RIM_Z,
    )
    shell -= cavity
    # bottom rim chamfer
    bottom = shell.faces().sort_by(Axis.Z).first
    shell = chamfer(bottom.edges(), P.RIM_CHAMFER)
    return shell


def _ledge(x, y, w, l, reach_dir) -> Part:
    """PCB seat ledge: top at POST_SEAT_Z, 45-degree chamfered underside.

    (x, y) is the ledge center, (w, l) its footprint; reach_dir is the axis
    ('X' or 'Y') along which it cantilevers so the chamfer runs across it.
    """
    t = 1.7                                          # ledge thickness at the wall
    body = Pos(x, y, P.POST_SEAT_Z - t / 2) * Box(w, l, t)
    run = w if reach_dir == "X" else l
    # 45-degree wedge removed from the underside tip
    sign = 1 if (reach_dir == "X" and x < 0) or (reach_dir == "Y" and y < 0) else -1
    # build wedge in the reach plane
    if reach_dir == "X":
        pts = [(0, 0), (sign * run, 0), (sign * run, min(run, t)), (0, 0)]
        wedge = extrude(
            make_face(
                Plane.XZ * Polyline(*pts, close=True)
            ).moved(Pos(x + sign * w / 2 * -1 + (w / 2 * sign), 0, 0)),
            l / 2, both=True,
        ).moved(Pos(x - sign * w / 2, y, P.POST_SEAT_Z - t))
    else:
        pts = [(0, 0), (sign * run, 0), (sign * run, min(run, t)), (0, 0)]
        wedge = extrude(
            make_face(Plane.YZ * Polyline(*pts, close=True)),
            w / 2, both=True,
        ).moved(Pos(x, y - sign * l / 2, P.POST_SEAT_Z - t))
    return body - wedge if wedge.volume > 1e-6 else body


def _supports() -> Part:
    """Pilasters + seat ledges + locating rails + button boss columns."""
    parts = []

    # --- -X wall rail: full-length pilaster beside the battery
    rail_face = -(P.BATT_CTR_X - P.BATT_W / 2 - P.CLEARANCE) * -1  # -16.5
    rail_t = P.IN_W / 2 - abs(rail_face)               # 1.85
    for y0, y1 in ((-19.0, -8.0), (2.0, 13.0)):
        parts.append(
            Pos(-(P.IN_W / 2) + rail_t / 2, (y0 + y1) / 2, P.POST_SEAT_Z / 2)
            * Box(rail_t, y1 - y0, P.POST_SEAT_Z)
        )
        parts.append(_ledge(-15.0, (y0 + y1) / 2, 3.0, y1 - y0, "X"))

    # --- bottom (-Y) edge pilasters flanking the USB opening
    pil_t = 1.6
    for x0, x1 in ((-16.0, -10.0), (10.0, 15.0)):
        parts.append(
            Pos((x0 + x1) / 2, P.IN_Y_MIN + pil_t / 2, P.POST_SEAT_Z / 2)
            * Box(x1 - x0, pil_t, P.POST_SEAT_Z)
        )
        parts.append(_ledge((x0 + x1) / 2, -18.4, x1 - x0, 2.7, "Y"))

    # --- top (+Y) edge posts gripping the PCB top corners
    for x0, x1 in ((-16.35, -10.0), (10.0, 16.35)):
        parts.append(
            Pos((x0 + x1) / 2, 20.55, P.POST_SEAT_Z / 2)
            * Box(x1 - x0, 1.6, P.POST_SEAT_Z)
        )
        parts.append(_ledge((x0 + x1) / 2, 18.4, x1 - x0, 2.7, "Y"))

    # --- upper locating rails (above the seat, faces at PCB + clearance)
    loc_t = P.IN_W / 2 - (P.PCB_W / 2 + P.CLEARANCE)   # 1.6
    for y0, y1 in ((-19.0, -8.0), (2.0, 13.0)):        # -X side, above rail
        parts.append(
            Pos(-(P.IN_W / 2) + loc_t / 2, (y0 + y1) / 2,
                (P.POST_SEAT_Z + P.RIM_Z) / 2)
            * Box(loc_t, y1 - y0, P.RIM_Z - P.POST_SEAT_Z)
        )
    for x0, x1 in ((-16.0, -10.0), (10.0, 15.0)):      # -Y side
        parts.append(
            Pos((x0 + x1) / 2, -19.75 + -1.6 / 2, (P.POST_SEAT_Z + P.RIM_Z) / 2)
            * Box(x1 - x0, 1.6, P.RIM_Z - P.POST_SEAT_Z)
        )
    for x0, x1 in ((-16.35, -10.0), (10.0, 16.35)):    # +Y side
        parts.append(
            Pos((x0 + x1) / 2, 19.75 + 1.6 / 2, (P.POST_SEAT_Z + P.RIM_Z) / 2)
            * Box(x1 - x0, 1.6, P.RIM_Z - P.POST_SEAT_Z)
        )

    # --- button boss columns on the +X wall (floor to above the bores)
    boss_face = P.SWITCH_TIP_X                          # 17.05
    boss_t = P.IN_W / 2 - boss_face                     # 1.3
    for y in (P.BTN1_CTR_Y, P.BTN2_CTR_Y):
        parts.append(
            Pos(boss_face + boss_t / 2, y, 10.5 / 2) * Box(boss_t, 8.0, 10.5)
        )
        parts.append(_ledge(16.2, y, 1.7, 8.0, "X"))

    # --- battery corral ribs (floor, h=BATT_RIB_H): +X side and -Y side
    parts.append(Pos(14.5 + 0.6, -6.0, 2.0) * Box(1.2, 14.0, 4.0))
    parts.append(Pos(-4.0, -17.75 - 0.6, 2.0) * Box(12.0, 1.2, 4.0))

    # --- speaker pocket ribs
    parts.append(Pos(-8.05, 23.55, 4.0) * Box(1.2, 6.4, 8.0))   # left rib
    parts.append(Pos(9.65, 23.55, 4.0) * Box(1.2, 6.4, 8.0))    # right rib
    parts.append(Pos(0.8, 20.35, 4.0) * Box(18.9, 1.2, 8.0))    # front rib

    out = parts[0]
    for p_ in parts[1:]:
        out += p_
    return out


def _barb(wall: str, c: float) -> Part:
    """Snap barb on a rebated outer face: flat catch underside at
    BARB_CATCH_Z, 45-degree lead-in ramp on top."""
    h = P.SNAP_BARB_H
    rise = 1.5                                         # ramp height above catch
    # profile in the wall-normal/Z plane: (out, z) with out=0 at wall face
    prof = [(0, P.BARB_CATCH_Z), (h, P.BARB_CATCH_Z), (0, P.BARB_CATCH_Z + rise)]
    if wall == "-X":
        face_x = -(P.OUT_W / 2 - P.REBATE)
        pts = [(face_x, z) for _, z in prof]
        pts = [(face_x - o, z) for o, z in prof]
        sk = make_face(Plane.XZ * Polyline(*pts, close=True))
        solid = extrude(sk, P.SNAP_BARB_L / 2, both=True)
        return solid.moved(Pos(0, c, 0))
    else:                                              # "+Y"
        face_y = EXT_CTR_Y + P.OUT_L / 2 - P.REBATE
        pts = [(face_y + o, z) for o, z in prof]
        sk = make_face(Plane.YZ * Polyline(*pts, close=True))
        solid = extrude(sk, P.SNAP_BARB_L / 2, both=True)
        return solid.moved(Pos(c, 0, 0))


def _openings() -> list[Part]:
    """Subtraction solids for every wall opening."""
    cuts = []
    wall_out = 30.0                                    # long enough to clear walls

    # USB: -Y wall, closed rectangular hole (9.0 bridge < 10 limit)
    cuts.append(
        Pos(P.USB_CTR_X, P.IN_Y_MIN - 2.0, P.USB_CTR_Z)
        * Box(P.USB_OPEN_W, 6.0, P.USB_OPEN_H)
    )
    # mic + LED pinholes: -Y wall, d=2 channels
    for x in (P.MIC_CTR_X, P.LED_CTR_X):
        cuts.append(
            Pos(x, P.IN_Y_MIN - 1.0, P.MIC_CTR_Z)
            * Rot(90, 0, 0) * Cylinder(P.PINHOLE / 2, 8.0)
        )
    # SD slot: +X wall
    cuts.append(
        Pos(P.IN_W / 2 + 1.2, P.SD_CTR_Y, P.SD_CTR_Z)
        * Box(4.0, P.SD_SLOT_L, P.SD_SLOT_H)
    )
    # button bores: +X wall — bore through wall, flange recess into boss
    for y in (P.BTN1_CTR_Y, P.BTN2_CTR_Y):
        cuts.append(
            Pos(P.OUT_W / 2, y, P.BTN_CTR_Z)
            * Rot(0, 90, 0) * Cylinder(P.BTN_BORE_D / 2, 12.0)
        )
        cuts.append(
            Pos(P.SWITCH_TIP_X + P.BTN_FLANGE_RECESS_DEPTH / 2, y, P.BTN_CTR_Z)
            * Rot(0, 90, 0)
            * Cylinder(P.BTN_FLANGE_RECESS_D / 2, P.BTN_FLANGE_RECESS_DEPTH)
        )
    # speaker grille slits: +Y wall
    n = P.SPK_GRILL_SLOTS
    total = (n - 1) * P.SPK_SLOT_PITCH
    for i in range(n):
        x = P.SPK_CTR_X - total / 2 + i * P.SPK_SLOT_PITCH
        cuts.append(
            Pos(x, P.IN_Y_MAX + 1.5, 7.0)
            * Box(P.SPK_SLOT_W, 5.0, P.SPK_SLOT_H)
        )
    return cuts


def build_base() -> Part:
    base = _shell() + _supports()
    for cut in _openings():
        base -= cut
    for wall, c in P.SNAPS:
        base += _barb(wall, c)
    return base


if __name__ == "__main__":
    from build123d import export_stl
    b = build_base()
    print(f"base: volume {b.volume/1000:.1f} cm3, "
          f"bbox {b.bounding_box().size}")
    export_stl(b, "debug_base.stl", tolerance=0.02)
    print("wrote debug_base.stl")
