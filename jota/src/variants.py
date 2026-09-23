"""The three case directions, as real geometry.

These are SHAPE STUDIES. They build on base.py / lid.py and are here to be
looked at, not printed: none of them has been through validate.py, and each
carries the open risks noted in its docstring. The current design is still
what export.py writes.

  A  pebble  — the side wall becomes a crowned barrel, widest at the button
               axis; both rims become a 45-degree land with an arc above it.
  B  reveal  — the lid's skirt is inverted into an internal spigot, so the
               exterior loses its step, its snap windows and its slots.
  C  thumb   — record becomes a stadium fin standing in a shallow trough;
               power is demoted into a recessed groove.
"""

import math

from build123d import (
    Align, Axis, Box, Cylinder, Part, Plane, Polyline, Pos, Rot,
    RectangleRounded, chamfer, extrude, loft, make_face,
)

import params as P
from base import build_base, EXT_CTR_Y, SKIRT_X_LIMIT, _ledge
from lid import build_lid, build_plunger, WINDOW_CTR_Z


# ===========================================================================
# A — PEBBLE
# ===========================================================================
CROWN_MAX = 1.90       # GUESS: peak outward bulge per side, chosen for feel
CROWN_Z = P.BTN_CTR_Z  # 6.50 — the equator is the button line, deliberately
CROWN_R_LO = 26.0      # GUESS: elevation radius below the equator
CROWN_R_HI = 20.0      # GUESS: above it, so the back is fuller than the front
RIM_LAND = 0.6         # 45-degree rise off the bed face, both parts
BOT_EASE_R = 2.0
TOP_EASE_R = 1.8


def crown(z):
    """Outward offset of the exterior skin at height z."""
    R = CROWN_R_LO if z < CROWN_Z else CROWN_R_HI
    d = min(abs(z - CROWN_Z), R)
    return CROWN_MAX - (R - math.sqrt(R * R - d * d))


def _smin(a, b, k):
    """Smooth minimum. The blend's slope always lies between its two inputs',
    so if neither input exceeds 45 degrees, the blend cannot either."""
    h = max(0.0, min(1.0, 0.5 + 0.5 * (b - a) / k))
    return (b * (1 - h) + a * h) - k * h * (1 - h)


# The rim eases are built as a 45-degree cone rising off the bed face, blended
# into the crown — NOT as an inset subtracted from the crown.
#
# That was the bug: the ease and the crown both grow with height, so an inset
# falling at 45 degrees rides on top of a crown already opening at 19 degrees
# and the real surface came out at 53 degrees off vertical — an overhang, all
# the way round both parts. Constrain the PROFILE and the arithmetic cannot
# drift again: the cone is exactly 45, the crown is shallower, and a smooth
# min of the two is bounded by the steeper of them.
EASE_DROP = 1.19       # how far the skin is pulled in at the bed face
EASE_BLEND = 0.85      # blend radius; bigger = softer, still <= 45 degrees
# The lid gets a tighter blend so its plate still meets the base's rim exactly.
# At 0.85 the blend bled all the way down to the parting line and left the lid
# 0.089 mm narrower than the base it sits on — a step right on the show seam.
EASE_BLEND_LID = 0.28


def _profile_base(z):
    """Half-offset added to OUT/2 for the base shell at height z."""
    cone = crown(-P.FLOOR_T) - EASE_DROP + (z - (-P.FLOOR_T))
    return _smin(crown(z), cone, EASE_BLEND)


def _profile_lid(z):
    """Half-offset for the lid plate at height z (top face on the bed)."""
    top = P.RIM_Z + P.LID_T
    cone = crown(top) - EASE_DROP + (top - z)
    return _smin(crown(z), cone, EASE_BLEND_LID)


def _steps(z0, z1, coarse=0.9, fine=0.22, ease=2.4):
    """Section heights: fine through the eases at either end, coarse between."""
    out, z = [], z0
    while z < z1:
        near = min(z - z0, z1 - z) < ease
        out.append(z)
        z += fine if near else coarse
    out.append(z1)
    return sorted(set(round(v, 4) for v in out))


def _lofted(z0, z1, prof, inset=0.0, r=None):
    secs = []
    for z in _steps(z0, z1):
        o = prof(z) - inset
        rad = (P.EDGE_FILLET_R + o) if r is None else r
        secs.append(Plane.XY.offset(z) * Pos(0, EXT_CTR_Y)
                    * RectangleRounded(P.OUT_W + 2 * o, P.OUT_L + 2 * o,
                                       max(rad, 0.4)))
    return loft(secs, ruled=True)


def build_base_A():
    """Crowned base. Cavity and every support rib are untouched — all of the
    crown material is added outboard, so no interior volume is lost."""
    shell = _lofted(-P.FLOOR_T, P.RIM_Z, _profile_base)

    # Rebate band. Built as "everything outboard of the skin pulled in by
    # REBATE", clipped to the band — NOT as one loft minus another. Two
    # independent lofts share an outer face, and their tessellations do not
    # agree, so that subtraction left slivers and a leaky solid.
    z0 = P.RIM_Z - P.SKIRT_DEPTH
    ring = _outboard_of(P.REBATE)
    ring &= Pos(0, EXT_CTR_Y, z0 + P.SKIRT_DEPTH / 2) * Box(
        300, 300, P.SKIRT_DEPTH)
    ring &= Pos(-150 + SKIRT_X_LIMIT, EXT_CTR_Y, z0 + P.SKIRT_DEPTH / 2) * Box(
        300, 300, P.SKIRT_DEPTH + 2)
    shell -= ring

    cavity = extrude(
        Plane.XY * Pos(0, EXT_CTR_Y) * RectangleRounded(
            P.IN_W, P.IN_L, max(P.EDGE_FILLET_R - P.WALL_T, 0.6)), P.RIM_Z)
    shell -= cavity

    from base import _supports, _openings, _barb
    shell += _supports()

    # Every wall cut has to reach CROWN_MAX further out than it used to. The
    # SD slot is the one that actually breaks: as a 4.0-deep box it stopped
    # 1.08 mm short of the crowned skin and left a blind pocket.
    for cut in _openings():
        bb = cut.bounding_box()
        is_sd = (abs(bb.size.Y - P.SD_SLOT_L) < 0.01
                 and abs((bb.min.Y + bb.max.Y) / 2 - P.SD_CTR_Y) < 0.01)
        if is_sd:
            # The SD slot ships as a plain box, so its ceiling is a 12.2 mm
            # flat bridge — despite base.py's docstring claiming the widest
            # bridge in the part is the 9.0 mm USB opening. A stadium drops
            # the flat span to 9.4 mm at no cost: the card is 11.0 wide and
            # the opening is still 12.02 wide at the card's own height.
            shell -= _stadium_x(P.OUT_W / 2 + CROWN_MAX + 2.0, P.SD_CTR_Y,
                                P.SD_CTR_Z, P.SD_SLOT_L, P.SD_SLOT_H,
                                CROWN_MAX + 6.0)
            continue
        shell -= _grow_xy(cut, CROWN_MAX + 0.6)
    for wall, c in P.SNAPS:
        shell += _rooted_barb(wall, c)
    return shell


# How far the barb's root is driven back into the wall. Only the root moves;
# the tip, the catch height and the release angle are all untouched, so the
# snap mechanics are exactly what section 3 measures.
BARB_ROOT = 0.6


def _rooted_barb(wall, c):
    """A snap barb welded to the crowned wall it grows out of.

    The barb is a prism translated outward by the crown at ONE height, but
    the wall it lands on curves with z. At the barb's own root the skin is
    ~0.05 mm less proud than at the height the translation was taken from, so
    the barb cleared the wall instead of touching it: a 0.26 x 8.0 mm island
    hanging in free air, which is exactly what a slicer calls a floating
    region. The prismatic case never showed this because a flat wall is the
    same distance out at every height.

    Smearing a copy inboard closes the gap. The added material lands inside a
    2.77 mm solid wall, so it costs nothing.
    """
    from base import _barb
    place = Pos(-crown(P.BARB_CATCH_Z + 0.75), 0, 0)
    inboard = Pos(0.2, 0, 0) if wall == "-X" else Pos(0, -0.2, 0)
    b = _barb(wall, c).moved(place)
    root = b
    for i in range(1, round(BARB_ROOT / 0.2) + 1):   # int() floors 2.999 -> 2
        root = root + Pos(*(v * i for v in inboard.position)) * b
    return root


def _smear(out, cut, dist, extent, axis):
    """Union copies of `cut` along `axis` out to `dist`, stepping by at most
    half the cut's own extent so consecutive copies always overlap.

    One copy at the full distance is NOT enough, and that was a real defect:
    a cut shorter than `dist` and its displaced twin never touch, so the wall
    between them survives as a rib stranded in mid-opening. The button flange
    pockets are BTN_POCKET_L = 1.3 mm long against a 2.5 mm grow, and each
    left a 1.2 x 0.67 mm island the slicer reported as a floating region.
    """
    n = max(1, int(math.ceil(abs(dist) / max(extent * 0.5, 1e-6))))
    for i in range(1, n + 1):
        d = dist * i / n
        step = Pos(d, 0, 0) if axis == "X" else Pos(0, d, 0)
        out = out + step * cut
    return out


def _grow_xy(cut, grow):
    """Lengthen a wall cut outward so it still breaks through a crowned skin.

    This is the fix for a real defect the crown exposes: the SD slot is a
    4.0-deep box, and once the wall bulges by 1.9 it stops 1.08 short of the
    outside and leaves a blind pocket instead of a slot.
    """
    bb = cut.bounding_box()
    cx = (bb.min.X + bb.max.X) / 2
    cy = (bb.min.Y + bb.max.Y) / 2
    out = cut
    if abs(cx) > 8:                                  # +/-X wall cut
        out = _smear(out, cut, (1 if cx > 0 else -1) * grow, bb.size.X, "X")
    if abs(cy - EXT_CTR_Y) > 12:                     # +/-Y wall cut
        out = _smear(out, cut, (1 if cy > EXT_CTR_Y else -1) * grow,
                     bb.size.Y, "Y")
    return out


def build_lid_A():
    plate = _lofted(P.RIM_Z, P.RIM_Z + P.LID_T, _profile_lid)
    win = Pos(P.ACTIVE_CTR_X, P.ACTIVE_CTR_Y, P.RIM_Z + P.LID_T / 2) * Box(
        P.WINDOW, P.WINDOW, P.LID_T + 2)
    plate -= win
    top = plate.faces().sort_by(Axis.Z).last
    if top.inner_wires():
        plate = chamfer(top.inner_wires()[0].edges(), P.WINDOW_CHAMFER)
    ring = Pos(P.ACTIVE_CTR_X, P.ACTIVE_CTR_Y, P.RIM_Z - P.PANEL_LID_GAP / 2) * (
        Box(P.WINDOW + 3.0, P.WINDOW + 3.0, P.PANEL_LID_GAP)
        - Box(P.WINDOW, P.WINDOW, P.PANEL_LID_GAP + 2))
    plate += ring

    # skirt: crowns on BOTH faces at once, so it stays 1.2 mm at every height
    z0 = P.RIM_Z - P.SKIRT_DEPTH
    skirt = _lofted(z0, P.RIM_Z, _profile_base) - _lofted(
        z0, P.RIM_Z, _profile_base, inset=P.SKIRT_T,
        r=P.EDGE_FILLET_R - P.SKIRT_T)
    limit = SKIRT_X_LIMIT - P.CLEARANCE
    skirt &= Pos(limit - 100, EXT_CTR_Y, z0 + P.SKIRT_DEPTH / 2) * Box(
        200, 200, P.SKIRT_DEPTH + 2)

    g = P.SKIRT_T + CROWN_MAX + 2
    for wall, c in P.SNAPS:
        if wall == "-X":
            skirt -= Pos(-P.OUT_W / 2 + P.SKIRT_T / 2 - CROWN_MAX / 2, c,
                         WINDOW_CTR_Z) * Box(g, P.SNAP_WINDOW_L, P.SNAP_WINDOW_H)
            for s in (-1, 1):
                skirt -= Pos(-P.OUT_W / 2 + P.SKIRT_T / 2 - CROWN_MAX / 2,
                             c + s * P.SNAP_PANEL_L / 2, z0 + P.SKIRT_DEPTH / 2
                             ) * Box(g, P.SNAP_SLOT_W, P.SKIRT_DEPTH + 0.2)
    fy = EXT_CTR_Y - P.OUT_L / 2 + P.SKIRT_T / 2 - CROWN_MAX / 2
    usb_top = P.USB_CTR_Z + P.USB_OPEN_H / 2
    skirt -= Pos(P.USB_CTR_X, fy, (z0 + usb_top) / 2) * Box(
        P.USB_OPEN_W, g, usb_top - z0 + 0.01)
    for x in (P.MIC_CTR_X, P.LED_CTR_X):
        skirt -= Pos(x, fy, P.MIC_CTR_Z) * Rot(90, 0, 0) * Cylinder(
            P.PINHOLE / 2, 8.0)
    fyp = EXT_CTR_Y + P.OUT_L / 2 - P.SKIRT_T / 2 + CROWN_MAX / 2
    n = P.SPK_GRILL_SLOTS
    tot = (n - 1) * P.SPK_SLOT_PITCH
    for i in range(n):
        skirt -= Pos(P.SPK_CTR_X - tot / 2 + i * P.SPK_SLOT_PITCH, fyp,
                     P.SPK_SLOT_CTR_Z) * Box(P.SPK_SLOT_W, g, P.SPK_SLOT_H)

    from lid import _align_nubs
    return plate + skirt + _align_nubs()


def build_plunger_A():
    """Longer stem: the head now emerges at the equator, where the surface
    normal is exactly +X, so there is no compound angle where a thumb lands."""
    up = (Align.CENTER, Align.CENTER, Align.MIN)
    shoulder = P.SWITCH_TIP_X + P.BTN_POCKET_L
    stem_l = (P.OUT_W / 2 + crown(P.BTN_CTR_Z) - shoulder) + P.BTN_HEAD_PROUD
    return (Cylinder(P.BTN_FLANGE_D / 2, P.BTN_FLANGE_L, align=up)
            + Pos(0, 0, P.BTN_FLANGE_L) * Cylinder(P.BTN_STEM_D / 2, stem_l,
                                                   align=up)
            + Pos(0, 0, P.BTN_FLANGE_L + stem_l - P.BTN_HEAD_PROUD)
            * Cylinder(P.BTN_HEAD_D / 2, P.BTN_HEAD_PROUD, align=up))


# ===========================================================================
# B — THE REVEAL
# ===========================================================================
RECESS = 0.5           # exterior band: the skin steps IN above the foot
RECESS_Z0 = 1.4        # assembled Z where the band starts
SPIGOT_T = 0.8
SPIGOT_REBATE = SPIGOT_T + P.CLEARANCE
SPIGOT_DEPTH = 9.0
SEAM_CHAMFER = 0.4
SPK_HOLE_D = 1.2
SPK_HOLE_PITCH = 2.2
SPK_COLS, SPK_ROWS = 7, 3
B_ENGAGE = 8.0
B_CATCH_Z = P.RIM_Z - B_ENGAGE


def _band(z0, z1, inset):
    fp_o = Pos(0, EXT_CTR_Y) * RectangleRounded(P.OUT_W, P.OUT_L,
                                                P.EDGE_FILLET_R)
    fp_i = Pos(0, EXT_CTR_Y) * RectangleRounded(
        P.OUT_W - 2 * inset, P.OUT_L - 2 * inset, P.EDGE_FILLET_R - inset)
    return extrude(Plane.XY.offset(z0) * (fp_o - fp_i), z1 - z0)


def build_base_B():
    full = Pos(0, EXT_CTR_Y) * RectangleRounded(P.OUT_W, P.OUT_L,
                                               P.EDGE_FILLET_R)
    shell = extrude(Plane.XY.offset(-P.FLOOR_T) * full, P.FLOOR_T + P.RIM_Z)
    shell -= _band(RECESS_Z0, P.RIM_Z, RECESS)        # the recess band
    shell -= extrude(Plane.XY * Pos(0, EXT_CTR_Y) * RectangleRounded(
        P.IN_W, P.IN_L, max(P.EDGE_FILLET_R - P.WALL_T, 0.6)), P.RIM_Z)
    bottom = shell.faces().sort_by(Axis.Z).first
    shell = chamfer(bottom.edges(), P.RIM_CHAMFER)
    top = shell.faces().sort_by(Axis.Z).last
    try:
        shell = chamfer(top.outer_wire().edges(), SEAM_CHAMFER)
    except Exception:
        pass

    from base import _supports
    shell += _supports()

    # rebate cut INTO the inner face, three panels not a ring
    zr0 = P.RIM_Z - SPIGOT_DEPTH
    xin = -(P.OUT_W / 2 - P.WALL_T + SPIGOT_REBATE)
    shell -= Pos(xin - 0.5, EXT_CTR_Y, (zr0 + P.RIM_Z) / 2) * Box(
        SPIGOT_REBATE + 1.0, P.OUT_L - 2 * P.EDGE_FILLET_R + 6, SPIGOT_DEPTH + 0.02)
    yin = EXT_CTR_Y + P.OUT_L / 2 - P.WALL_T + SPIGOT_REBATE
    for x0, x1 in ((-12.75, -8.0), (9.6, 12.75)):
        shell -= Pos((x0 + x1) / 2, yin + 0.5, (zr0 + P.RIM_Z) / 2) * Box(
            x1 - x0, SPIGOT_REBATE + 1.0, SPIGOT_DEPTH + 0.02)

    # openings: stadiums, and the grille becomes a field of round holes
    shell -= _stadium_x(P.OUT_W / 2 + 1, P.SD_CTR_Y, P.SD_CTR_Z,
                        P.SD_SLOT_L, P.SD_SLOT_H, 6.0)
    for y in (P.BTN1_CTR_Y, P.BTN2_CTR_Y):
        shell -= Pos(P.OUT_W / 2, y, P.BTN_CTR_Z) * Rot(0, 90, 0) * Cylinder(
            P.BTN_BORE_D / 2, 12.0)
        shell -= Pos(P.SWITCH_TIP_X + P.BTN_POCKET_L / 2, y, P.BTN_CTR_Z
                     ) * Rot(0, 90, 0) * Cylinder(P.BTN_POCKET_D / 2,
                                                  P.BTN_POCKET_L)
    shell -= _stadium_y(P.USB_CTR_X, P.IN_Y_MIN - 2.0, P.USB_CTR_Z,
                        P.USB_OPEN_W, P.USB_OPEN_H, 6.0)
    for x in (P.MIC_CTR_X, P.LED_CTR_X):
        shell -= Pos(x, P.IN_Y_MIN - 1.0, P.MIC_CTR_Z) * Rot(90, 0, 0) \
            * Cylinder(P.PINHOLE / 2, 8.0)
    tot_x = (SPK_COLS - 1) * SPK_HOLE_PITCH
    for r in range(SPK_ROWS):
        z = P.SPK_SLOT_CTR_Z + (r - (SPK_ROWS - 1) / 2) * SPK_HOLE_PITCH
        off = (SPK_HOLE_PITCH / 2) if r % 2 else 0.0
        for c in range(SPK_COLS):
            x = P.SPK_CTR_X - tot_x / 2 + c * SPK_HOLE_PITCH + off - SPK_HOLE_PITCH / 4
            shell -= Pos(x, P.IN_Y_MAX + 1.5, z) * Rot(90, 0, 0) * Cylinder(
                SPK_HOLE_D / 2, 8.0)

    # barbs, now growing INWARD off the rebate face
    for wall, c in P.SNAPS:
        if wall != "-X":
            continue
        h = P.SNAP_BARB_H
        back = h * math.tan(math.radians(P.SNAP_RELEASE_ANGLE))
        fx = xin
        pts = [(fx, B_CATCH_Z), (fx + h, B_CATCH_Z + back), (fx, B_CATCH_Z + 1.5)]
        sk = make_face(Plane.XZ * Polyline(*pts, close=True))
        shell += extrude(sk, P.SNAP_BARB_L / 2, both=True).moved(Pos(0, c, 0))
    return shell


def _stadium_x(x, y, z, ly, lz, depth):
    return extrude(Plane.YZ.offset(x - depth) * Pos(y, z)
                   * RectangleRounded(ly, lz, min(ly, lz) / 2 - 0.001), depth * 2)


def _stadium_y(x, y, z, lx, lz, depth):
    return extrude(Plane.XZ.offset(-(y + depth)) * Pos(x, z)
                   * RectangleRounded(lx, lz, min(lx, lz) / 2 - 0.001), depth * 2)


def build_lid_B():
    full = Pos(0, EXT_CTR_Y) * RectangleRounded(P.OUT_W, P.OUT_L,
                                               P.EDGE_FILLET_R)
    plate = extrude(Plane.XY.offset(P.RIM_Z) * full, P.LID_T)
    # Chamfer the top BEFORE cutting the recess band: the band's top edge has
    # to land exactly where the chamfer starts, or the two features overlap
    # and OCCT refuses the chamfer outright.
    top = plate.faces().sort_by(Axis.Z).last
    plate = chamfer(top.edges(), P.RIM_CHAMFER)
    plate -= _band(P.RIM_Z, P.RIM_Z + P.LID_T - P.RIM_CHAMFER, RECESS)
    win = Pos(P.ACTIVE_CTR_X, P.ACTIVE_CTR_Y, P.RIM_Z + P.LID_T / 2) * Box(
        P.WINDOW, P.WINDOW, P.LID_T + 2)
    plate -= win
    t2 = plate.faces().sort_by(Axis.Z).last
    if t2.inner_wires():
        plate = chamfer(t2.inner_wires()[0].edges(), P.WINDOW_CHAMFER)
    plate += Pos(P.ACTIVE_CTR_X, P.ACTIVE_CTR_Y,
                 P.RIM_Z - P.PANEL_LID_GAP / 2) * (
        Box(P.WINDOW + 3.0, P.WINDOW + 3.0, P.PANEL_LID_GAP)
        - Box(P.WINDOW, P.WINDOW, P.PANEL_LID_GAP + 2))

    # spigot: INSIDE the base wall, so nothing of it is ever visible
    zr0 = P.RIM_Z - SPIGOT_DEPTH
    xo = -(P.OUT_W / 2 - P.WALL_T + SPIGOT_REBATE)
    spig = Pos(xo + SPIGOT_T / 2, EXT_CTR_Y, (zr0 + P.RIM_Z) / 2) * Box(
        SPIGOT_T, P.OUT_L - 2 * P.EDGE_FILLET_R + 4, SPIGOT_DEPTH)
    yo = EXT_CTR_Y + P.OUT_L / 2 - P.WALL_T + SPIGOT_REBATE
    for x0, x1 in ((-12.75, -8.0), (9.6, 12.75)):
        spig += Pos((x0 + x1) / 2, yo - SPIGOT_T / 2, (zr0 + P.RIM_Z) / 2) * Box(
            x1 - x0, SPIGOT_T, SPIGOT_DEPTH)
    # snap windows + panel slots, in the hidden spigot
    for wall, c in P.SNAPS:
        if wall != "-X":
            continue
        spig -= Pos(xo + SPIGOT_T / 2, c, B_CATCH_Z - 0.30 + P.SNAP_WINDOW_H / 2
                    ) * Box(SPIGOT_T + 2, P.SNAP_WINDOW_L + 1.5, P.SNAP_WINDOW_H)
        for s in (-1, 1):
            spig -= Pos(xo + SPIGOT_T / 2, c + s * 6.0, (zr0 + P.RIM_Z) / 2
                        ) * Box(SPIGOT_T + 2, P.SNAP_SLOT_W, SPIGOT_DEPTH + 0.2)
    from lid import _align_nubs
    return plate + spig + _align_nubs()


def build_plunger_B():
    up = (Align.CENTER, Align.CENTER, Align.MIN)
    shoulder = P.SWITCH_TIP_X + P.BTN_POCKET_L
    stem_l = (P.OUT_W / 2 - RECESS - shoulder) + P.BTN_HEAD_PROUD
    return (Cylinder(P.BTN_FLANGE_D / 2, P.BTN_FLANGE_L, align=up)
            + Pos(0, 0, P.BTN_FLANGE_L) * Cylinder(P.BTN_STEM_D / 2, stem_l,
                                                   align=up)
            + Pos(0, 0, P.BTN_FLANGE_L + stem_l - P.BTN_HEAD_PROUD)
            * Cylinder(P.BTN_HEAD_D / 2, P.BTN_HEAD_PROUD, align=up))


# ===========================================================================
# C — THUMB FIRST
# ===========================================================================
FIN_W, FIN_H = 5.6, 8.6
FIN_PROUD = 1.2
FIN_SLOT_W, FIN_SLOT_H = FIN_W + 0.8, FIN_H + 0.8
FIN_FLANGE_W, FIN_FLANGE_H = FIN_SLOT_W + 1.6, FIN_SLOT_H + 1.6
FIN_POCKET_W, FIN_POCKET_H = FIN_FLANGE_W + 0.4, FIN_FLANGE_H + 0.4
FIN_POCKET_L = P.BTN_POCKET_L
TROUGH_W, TROUGH_H, TROUGH_D = 12.0, 11.0, 0.6
PWR_GROOVE_W, PWR_GROOVE_H, PWR_GROOVE_D = 6.0, 11.0, 0.6
BTN_HEAD_PROUD_PWR = 0.4
REC_Y, PWR_Y = P.BTN2_CTR_Y, P.BTN1_CTR_Y


def build_base_C():
    """Everything happens on the +X wall, below the parting line. The lid,
    the skirt and both snaps are untouched."""
    base = build_base()

    # widen the record boss so the stadium pocket has material to sit in
    boss_face = P.SWITCH_TIP_X
    boss_t = P.IN_W / 2 - boss_face
    base += Pos(boss_face + boss_t / 2, REC_Y, 13.0 / 2) * Box(boss_t, 11.0, 13.0)
    base += _ledge(16.2, REC_Y, 1.7, 11.0, "X")

    # the two recesses. Stadiums, because they are the only shape the brand
    # permits, and shallow so a flat surface bridges them but a thumb does not.
    base -= _stadium_x(P.OUT_W / 2 + TROUGH_D, REC_Y, P.BTN_CTR_Z,
                       TROUGH_W, TROUGH_H, TROUGH_D)
    base -= _stadium_x(P.OUT_W / 2 + PWR_GROOVE_D, PWR_Y, P.BTN_CTR_Z,
                       PWR_GROOVE_W, PWR_GROOVE_H, PWR_GROOVE_D)
    # the fin's slot and flange pocket subsume the old round bore/pocket
    base -= _stadium_x(P.OUT_W / 2 + 2, REC_Y, P.BTN_CTR_Z,
                       FIN_SLOT_W, FIN_SLOT_H, 8.0)
    base -= extrude(
        Plane.YZ.offset(P.SWITCH_TIP_X) * Pos(REC_Y, P.BTN_CTR_Z)
        * RectangleRounded(FIN_POCKET_W, FIN_POCKET_H, FIN_POCKET_W / 2 - 0.001),
        FIN_POCKET_L)
    return base


def build_lid_C():
    return build_lid()          # untouched, and that is the point


def build_plunger_C_fin():
    """Stadium prism. The flange is oversize in BOTH axes against the slot,
    so the switch spring cannot eject it; the slot keys it so it cannot spin."""
    shoulder = P.SWITCH_TIP_X + FIN_POCKET_L
    wall_face = P.OUT_W / 2 - TROUGH_D
    stem_l = (wall_face - shoulder) + FIN_PROUD
    flange = extrude(Pos(0, 0) * RectangleRounded(
        FIN_FLANGE_W, FIN_FLANGE_H, FIN_FLANGE_W / 2 - 0.001), P.BTN_FLANGE_L)
    stem = Pos(0, 0, P.BTN_FLANGE_L) * extrude(
        RectangleRounded(FIN_W, FIN_H, FIN_W / 2 - 0.001), stem_l)
    return flange + stem


def build_plunger_C_pwr():
    up = (Align.CENTER, Align.CENTER, Align.MIN)
    shoulder = P.SWITCH_TIP_X + P.BTN_POCKET_L
    stem_l = (P.OUT_W / 2 - PWR_GROOVE_D - shoulder) + BTN_HEAD_PROUD_PWR
    return (Cylinder(P.BTN_FLANGE_D / 2, P.BTN_FLANGE_L, align=up)
            + Pos(0, 0, P.BTN_FLANGE_L) * Cylinder(P.BTN_STEM_D / 2, stem_l,
                                                   align=up)
            + Pos(0, 0, P.BTN_FLANGE_L + stem_l - BTN_HEAD_PROUD_PWR)
            * Cylinder(P.BTN_HEAD_D / 2, BTN_HEAD_PROUD_PWR, align=up))


# ===========================================================================
# A+C — PEBBLE, THUMB FIRST
#
# The two directions want the same millimetre: the crown's widest line is
# CROWN_Z = BTN_CTR_Z = 6.50, and that is exactly where the fin sits. The
# crown gives the thumb a gradient to run down; the fin gives it something
# unmistakable when it arrives.
#
# The one thing that does NOT transfer: a flat-bottomed trough. Cut to a
# constant depth from a plane, it is 0.60 deep at the equator and 0.012 deep
# at its lower edge — it disappears exactly where the crown falls away. So
# both recesses are cut as a constant-depth offset OF THE CROWNED SKIN, which
# is what keeps the trough a trough all the way up.
# ===========================================================================

def _outboard_of(depth):
    """Solid filling everything outboard of the crowned skin pulled in by
    `depth` — intersect it with a footprint to get a recess that follows the
    curve instead of cutting through it."""
    inner = _lofted(-P.FLOOR_T, P.RIM_Z,
                    lambda z: _profile_base(z) - depth)
    big = Pos(0, EXT_CTR_Y, (P.RIM_Z - P.FLOOR_T) / 2) * Box(
        260, 260, P.FLOOR_T + P.RIM_Z)
    return big - inner


def build_base_AC():
    base = build_base_A()

    boss_face = P.SWITCH_TIP_X
    boss_t = P.IN_W / 2 - boss_face
    base += Pos(boss_face + boss_t / 2, REC_Y, 13.0 / 2) * Box(boss_t, 11.0, 13.0)
    base += _ledge(16.2, REC_Y, 1.7, 11.0, "X")

    shellband = _outboard_of(TROUGH_D)          # both recesses are 0.6 deep
    base -= shellband & _stadium_x(P.OUT_W / 2 + 12, REC_Y, P.BTN_CTR_Z,
                                   TROUGH_W, TROUGH_H, 22)
    base -= shellband & _stadium_x(P.OUT_W / 2 + 12, PWR_Y, P.BTN_CTR_Z,
                                   PWR_GROOVE_W, PWR_GROOVE_H, 22)

    base -= _stadium_x(P.OUT_W / 2 + 6, REC_Y, P.BTN_CTR_Z,
                       FIN_SLOT_W, FIN_SLOT_H, 12.0)
    base -= extrude(
        Plane.YZ.offset(P.SWITCH_TIP_X) * Pos(REC_Y, P.BTN_CTR_Z)
        * RectangleRounded(FIN_POCKET_W, FIN_POCKET_H, FIN_POCKET_W / 2 - 0.001),
        FIN_POCKET_L)
    return _lanyard(base)


# --- lanyard anchor -------------------------------------------------------
# A cord tunnel across the +X/+Y corner. Every constraint points at this one
# spot:
#   * it must load the BASE. Anchored to the lid, a pull on the cord works
#     directly against the two snaps and pops the case open.
#   * it must sit below z = RIM_Z - SKIRT_DEPTH = 3.55. Above that the lid
#     skirt wraps the outside of the wall everywhere x <= 12.75, so a mouth
#     up there would simply be covered by the lid.
#   * it cannot cross the parting line, or the cord sits in the seam.
#   * a bare corner tunnel breaks into the cavity (corner wall is 2.4 thick
#     against a 5.6 interior radius), so the corner gets a solid gusset —
#     into space that is genuinely empty: the battery and PCB stop at y=19.5,
#     the speaker at x=8.8.
# The crown pays off here: at the tunnel the corner radius is 9.43 instead of
# 8.00, so the bar the cord loops around is 3.5 mm thick rather than 2.1.
LAN_D = 1.8            # GUESS: fits a thin lanyard cord; not measured
LAN_Z = 1.75           # centre height — clear of the skirt line at 3.55
LAN_OFF = 5.0          # tunnel axis, radially out from the corner centre
LAN_CX = P.OUT_W / 2 - P.EDGE_FILLET_R          # 12.75
LAN_CY = EXT_CTR_Y + P.OUT_L / 2 - P.EDGE_FILLET_R   # 21.15


def _lanyard(base):
    k = math.sqrt(0.5)
    gus = Pos(LAN_CX, LAN_CY, 4.5 / 2) * Cylinder(6.0, 4.5)
    gus &= Pos(13.5 + 10, 21.5 + 10, 4.5 / 2) * Box(20, 20, 4.5)
    base += gus
    axis = Pos(LAN_CX + LAN_OFF * k, LAN_CY + LAN_OFF * k, LAN_Z)
    tunnel = axis * Rot(0, 0, 45) * Rot(90, 0, 0) * Cylinder(LAN_D / 2, 40)
    return base - tunnel


AC_WALL_FACE = P.OUT_W / 2 + crown(P.BTN_CTR_Z) - TROUGH_D   # 22.05


def build_plunger_AC_fin():
    shoulder = P.SWITCH_TIP_X + FIN_POCKET_L
    stem_l = (AC_WALL_FACE - shoulder) + FIN_PROUD
    flange = extrude(RectangleRounded(FIN_FLANGE_W, FIN_FLANGE_H,
                                      FIN_FLANGE_W / 2 - 0.001), P.BTN_FLANGE_L)
    stem = Pos(0, 0, P.BTN_FLANGE_L) * extrude(
        RectangleRounded(FIN_W, FIN_H, FIN_W / 2 - 0.001), stem_l)
    return flange + stem


def build_plunger_AC_pwr():
    up = (Align.CENTER, Align.CENTER, Align.MIN)
    shoulder = P.SWITCH_TIP_X + P.BTN_POCKET_L
    stem_l = (AC_WALL_FACE - shoulder) + BTN_HEAD_PROUD_PWR
    return (Cylinder(P.BTN_FLANGE_D / 2, P.BTN_FLANGE_L, align=up)
            + Pos(0, 0, P.BTN_FLANGE_L) * Cylinder(P.BTN_STEM_D / 2, stem_l,
                                                   align=up)
            + Pos(0, 0, P.BTN_FLANGE_L + stem_l - BTN_HEAD_PROUD_PWR)
            * Cylinder(P.BTN_HEAD_D / 2, BTN_HEAD_PROUD_PWR, align=up))


DIRECTIONS = {
    "A": dict(name="Pebble", base=build_base_A, lid=build_lid_A,
              plunger=build_plunger_A),
    "AC": dict(name="Pebble, thumb first", base=build_base_AC,
               lid=build_lid_A, plunger=build_plunger_AC_fin),
    "B": dict(name="The Reveal", base=build_base_B, lid=build_lid_B,
              plunger=build_plunger_B),
    "C": dict(name="Thumb first", base=build_base_C, lid=build_lid_C,
              plunger=build_plunger_C_fin),
}


if __name__ == "__main__":
    for k, d in DIRECTIONS.items():
        for part in ("base", "lid", "plunger"):
            try:
                p = d[part]()
                bb = p.bounding_box()
                print(f"{k} {d['name']:12s} {part:8s} vol {p.volume/1000:6.2f} cm3"
                      f"  bbox {bb.size.X:.2f} x {bb.size.Y:.2f} x {bb.size.Z:.2f}")
            except Exception as e:
                print(f"{k} {part:8s} FAILED: {type(e).__name__}: {e}")
