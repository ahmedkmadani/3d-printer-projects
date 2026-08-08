"""Lid: window with bezel overlap, three-sided snap skirt, and the
separate button plunger part.

Why a separate printed plunger and not a printed-in-place flexure: the
flexure would hinge across layer lines in the vertical wall (weak in every
common filament) and couple button feel to wall thickness. A separate pin
prints flat, is filament-agnostic and replaceable, and is captive in the
base wall bore once the board is installed.

Modeled in assembled coordinates (lid on top of base); print orientation
is applied at export (top face on the bed).
"""

from build123d import (
    Axis, Box, Cylinder, Part, Plane, Pos, RectangleRounded, chamfer, extrude,
)

import params as P
from base import EXT_CTR_Y, SKIRT_X_LIMIT


def _plate() -> Part:
    fp = Pos(0, EXT_CTR_Y) * RectangleRounded(P.OUT_W, P.OUT_L, P.EDGE_FILLET_R)
    plate = extrude(Plane.XY.offset(P.RIM_Z) * fp, P.LID_T)
    top = plate.faces().sort_by(Axis.Z).last
    plate = chamfer(top.edges(), P.RIM_CHAMFER)

    # window: straight cut, then a 1.0 x 45deg bevel on the top edges
    win = Pos(P.ACTIVE_CTR_X, P.ACTIVE_CTR_Y, P.RIM_Z + P.LID_T / 2) * Box(
        P.WINDOW, P.WINDOW, P.LID_T + 2
    )
    plate -= win
    top_win_edges = (
        plate.faces().sort_by(Axis.Z).last.inner_wires()[0].edges()
        if plate.faces().sort_by(Axis.Z).last.inner_wires()
        else None
    )
    if top_win_edges:
        plate = chamfer(top_win_edges, P.WINDOW_CHAMFER)

    # bezel ring pressing the panel border (PANEL_LID_GAP proud)
    ring = Pos(P.ACTIVE_CTR_X, P.ACTIVE_CTR_Y, P.RIM_Z - P.PANEL_LID_GAP / 2) * (
        Box(P.WINDOW + 3.0, P.WINDOW + 3.0, P.PANEL_LID_GAP)
        - Box(P.WINDOW, P.WINDOW, P.PANEL_LID_GAP + 2)
    )
    return plate + ring


# Window Z is DERIVED from the barb, not hardcoded: the old literal 7.4 meant
# changing SNAP_ENGAGE_DEPTH moved the barbs while the windows stayed put.
# The bottom sits SNAP_WINDOW_DROOP below the catch face, because that edge
# prints as a bridge and sags upward in assembled-Z.
WINDOW_BOT_Z = P.BARB_CATCH_Z - P.SNAP_WINDOW_DROOP
WINDOW_CTR_Z = WINDOW_BOT_Z + P.SNAP_WINDOW_H / 2


def _skirt() -> Part:
    fp_out = Pos(0, EXT_CTR_Y) * RectangleRounded(P.OUT_W, P.OUT_L, P.EDGE_FILLET_R)
    fp_in = Pos(0, EXT_CTR_Y) * RectangleRounded(
        P.OUT_W - 2 * P.SKIRT_T, P.OUT_L - 2 * P.SKIRT_T,
        P.EDGE_FILLET_R - P.SKIRT_T,
    )
    ring = extrude(
        Plane.XY.offset(P.RIM_Z - P.SKIRT_DEPTH) * (fp_out - fp_in), P.SKIRT_DEPTH
    )
    # three sides only: stop before the +X wall (leave CLEARANCE to the
    # base's skirt shoulder)
    limit = SKIRT_X_LIMIT - P.CLEARANCE
    ring &= Pos(limit - 100, EXT_CTR_Y, P.RIM_Z - P.SKIRT_DEPTH / 2) * Box(
        200, 200, P.SKIRT_DEPTH + 2
    )

    # snap windows + panel slots
    for wall, c in P.SNAPS:
        if wall == "-X":
            win = Pos(-P.OUT_W / 2 + P.SKIRT_T / 2, c, WINDOW_CTR_Z) * Box(
                P.SKIRT_T + 2, P.SNAP_WINDOW_L, P.SNAP_WINDOW_H
            )
            slots = [
                Pos(-P.OUT_W / 2 + P.SKIRT_T / 2, c + s * P.SNAP_PANEL_L / 2,
                    P.RIM_Z - P.SKIRT_DEPTH / 2)
                * Box(P.SKIRT_T + 2, P.SNAP_SLOT_W, P.SKIRT_DEPTH + 0.2)
                for s in (-1, 1)
            ]
        else:  # +Y
            face_y = EXT_CTR_Y + P.OUT_L / 2 - P.SKIRT_T / 2
            win = Pos(c, face_y, WINDOW_CTR_Z) * Box(
                P.SNAP_WINDOW_L, P.SKIRT_T + 2, P.SNAP_WINDOW_H
            )
            slots = [
                Pos(c + s * P.SNAP_PANEL_L / 2, face_y, P.RIM_Z - P.SKIRT_DEPTH / 2)
                * Box(P.SNAP_SLOT_W, P.SKIRT_T + 2, P.SKIRT_DEPTH + 0.2)
                for s in (-1, 1)
            ]
        ring -= win
        for s in slots:
            ring -= s

    # -Y skirt: USB notch (up to the top of the base wall opening) and
    # mic/LED channels
    face_y = EXT_CTR_Y - P.OUT_L / 2 + P.SKIRT_T / 2
    usb_top = P.USB_CTR_Z + P.USB_OPEN_H / 2
    ring -= Pos(P.USB_CTR_X, face_y,
                (P.RIM_Z - P.SKIRT_DEPTH + usb_top) / 2) * Box(
        P.USB_OPEN_W, P.SKIRT_T + 2,
        usb_top - (P.RIM_Z - P.SKIRT_DEPTH) + 0.01,
    )
    from build123d import Rot
    for x in (P.MIC_CTR_X, P.LED_CTR_X):
        ring -= Pos(x, face_y, P.MIC_CTR_Z) * Rot(90, 0, 0) * Cylinder(
            P.PINHOLE / 2, 6.0
        )

    # +Y skirt: the speaker grille. Without these the skirt covered the slits
    # from z 5.55 up, leaving only ~0.55 mm of the 4.0 mm slit height open —
    # about 86 % occluded, and what did escape whistled through the parting
    # line and the snap-panel slots.
    face_y_p = EXT_CTR_Y + P.OUT_L / 2 - P.SKIRT_T / 2
    n = P.SPK_GRILL_SLOTS
    total = (n - 1) * P.SPK_SLOT_PITCH
    for i in range(n):
        sx = P.SPK_CTR_X - total / 2 + i * P.SPK_SLOT_PITCH
        ring -= Pos(sx, face_y_p, P.SPK_SLOT_CTR_Z) * Box(
            P.SPK_SLOT_W, P.SKIRT_T + 2, P.SPK_SLOT_H
        )
    return ring


def _align_nubs() -> Part:
    """Two ribs on the lid underside hugging the +X wall inner face —
    the side that has no skirt still gets located."""
    nubs = None
    for y in (-16.0, 5.0):
        n = Pos(P.IN_W / 2 - 0.25 - 0.6, y, P.RIM_Z - 0.75) * Box(1.2, 5.0, 1.5)
        nubs = n if nubs is None else nubs + n
    return nubs


def build_lid() -> Part:
    return _plate() + _skirt() + _align_nubs()


def build_plunger() -> Part:
    """Button plunger, own frame: axis Z, FLANGE on the bed (print face).

    Installed from inside, before the board:
      flange  > bore  -> the outward stop, so the switch cannot eject it
      stem/head < bore -> so it can be threaded out through the wall
      head     stands proud and stays proud through the whole stroke

    Printed flange-down: every step is inward or a 0.2 mm ledge, so it is
    self-supporting, and the stem is loaded in compression along the layer
    normal — the strong direction.
    """
    from build123d import Align
    up = (Align.CENTER, Align.CENTER, Align.MIN)

    # Stem spans the flange face to the outer wall face, plus the proud head.
    shoulder_x = P.SWITCH_TIP_X + P.BTN_POCKET_L      # bore/pocket step
    stem_l = (P.OUT_W / 2 - shoulder_x) + P.BTN_HEAD_PROUD

    flange = Cylinder(P.BTN_FLANGE_D / 2, P.BTN_FLANGE_L, align=up)
    stem = Pos(0, 0, P.BTN_FLANGE_L) * Cylinder(P.BTN_STEM_D / 2, stem_l,
                                                align=up)
    head = Pos(0, 0, P.BTN_FLANGE_L + stem_l - P.BTN_HEAD_PROUD) * Cylinder(
        P.BTN_HEAD_D / 2, P.BTN_HEAD_PROUD, align=up)
    return flange + stem + head


if __name__ == "__main__":
    from build123d import export_stl
    lid = build_lid()
    print(f"lid: volume {lid.volume/1000:.2f} cm3, bbox {lid.bounding_box().size}")
    export_stl(lid, "debug_lid.stl", tolerance=0.02)
    pl = build_plunger()
    print(f"plunger: volume {pl.volume:.1f} mm3, bbox {pl.bounding_box().size}")
    export_stl(pl, "debug_plunger.stl", tolerance=0.01)
    print("wrote debug_lid.stl, debug_plunger.stl")
