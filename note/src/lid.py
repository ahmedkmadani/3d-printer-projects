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
            win = Pos(-P.OUT_W / 2 + P.SKIRT_T / 2, c, 7.4) * Box(
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
            win = Pos(c, face_y, 7.4) * Box(
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
    """Button plunger, own frame: axis Z, cap at the bottom (print face).

    A capped pin: cap seats in the outer recess, stem reaches the side switch.
    Installed from OUTSIDE — it cannot fall inward past the cap, and the switch
    holds it out against that seat. See params.py for why there is no inner
    retaining flange (there is no room for one; the switch occupies it).
    """
    from build123d import Align
    up = (Align.CENTER, Align.CENTER, Align.MIN)
    cap = Cylinder(P.BTN_CAP_D / 2, P.BTN_CAP_L, align=up)
    stem = Pos(0, 0, P.BTN_CAP_L) * Cylinder(P.BTN_STEM_D / 2, P.BTN_STEM_L,
                                             align=up)
    return cap + stem


if __name__ == "__main__":
    from build123d import export_stl
    lid = build_lid()
    print(f"lid: volume {lid.volume/1000:.2f} cm3, bbox {lid.bounding_box().size}")
    export_stl(lid, "debug_lid.stl", tolerance=0.02)
    pl = build_plunger()
    print(f"plunger: volume {pl.volume:.1f} mm3, bbox {pl.bounding_box().size}")
    export_stl(pl, "debug_plunger.stl", tolerance=0.01)
    print("wrote debug_lid.stl, debug_plunger.stl")
