"""Three closure concepts, from scratch. SHAPE STUDIES — none has been through
a checker. They exist to be looked at and to pick one from.

What every earlier case taught, and what all three obey:
  * nothing bends on purpose — no cantilever, no living hinge, no snap
  * every wall and the front face are >= 2.0 mm
  * the PCB's own mounting holes (28.00 x 43.20, two sources agree) are the
    datum; nothing bears on the e-paper glass, so DISPLAY_RAISE (1.5 or 4.2,
    still unresolved) only sets a pocket depth, never a fit
  * the battery comes out with a screwdriver, never by prying
  * prints on the A1 mini without support

  A  SANDWICH  — four M2 screws from the back, through the PCB holes, into
                 blind pilots in the front. The board is the structure.
  B  HOOK+ONE  — two rigid hooks on the button wall, one hidden screw on the
                 far wall. Tilt in, close, one screw.
  C  SLEEVE    — a one-piece tube (closed top end), the board and cell on a
                 carrier that slides in from the USB end, an end cap with one
                 screw beside the USB. No perimeter seam at all.

Frame: X width (+X = button/SD wall), Y length (+Y = top, -Y = USB end),
Z from the OUTER BACK FACE (z=0) up to the front face (z=T).
Run: .venv/bin/python jota/src/concepts.py   -> renders/concepts/*.png
"""

import os
import sys

import numpy as np

from build123d import (
    Axis, Box, Cylinder, Part, Plane, Pos, Rot, RectangleRounded,
    chamfer, extrude, fillet,
)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import params as P
import shot

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders", "concepts")

# ---- shared envelope --------------------------------------------------------
OUT_W, OUT_L, R = 42.0, 57.0, P.EDGE_FILLET_R
WALL = FLOOR = FACE = 2.0
UNDER = 6.3                                   # cell 5.3 + 1.0 for the SD holder
PCB_BACK = FLOOR + UNDER                      # 8.3
PCB_FRONT = PCB_BACK + P.PCB_T                # 9.9
GLASS = PCB_FRONT + P.DISPLAY_RAISE           # 14.1  (touch stack, worst case)
T = GLASS + 0.3 + FACE                        # 16.4
IN_W, IN_L = OUT_W - 2 * WALL, OUT_L - 2 * WALL
HOLES = [(sx * P.HOLE_PITCH_X / 2, sy * P.HOLE_PITCH_Y / 2)
         for sx in (-1, 1) for sy in (-1, 1)]
DISP_W, DISP_L = P.PANEL_W + 1.2, P.PANEL_L + 1.2
DISP_CY = P.ACTIVE_CTR_Y
WIN = P.ACTIVE + 0.8
BTN_Z = PCB_BACK - 1.0
CELL_Z = FLOOR + P.BATT_T / 2


def rrect(w, l, r):
    return RectangleRounded(w, l, r)


def prism(w, l, r, z0, z1):
    return extrude(Plane.XY.offset(z0) * rrect(w, l, r), z1 - z0)


def box(x0, x1, y0, y1, z0, z1):
    return Pos((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) * Box(x1 - x0, y1 - y0, z1 - z0)


def cyl_z(x, y, d, z0, z1):
    return Pos(x, y, (z0 + z1) / 2) * Cylinder(d / 2, z1 - z0)


def cyl_y(x, z, d, y0, y1):
    return Pos(x, (y0 + y1) / 2, z) * Rot(90, 0, 0) * Cylinder(d / 2, y1 - y0)


def pebble(p, bottom=True, top=True):
    """1.5 mm 45 deg facet on the two outer faces — the printable pebble edge."""
    fs = p.faces().sort_by(Axis.Z)
    if bottom:
        p = chamfer(fs.first.outer_wire().edges(), 1.5)
    if top:
        p = chamfer(p.faces().sort_by(Axis.Z).last.outer_wire().edges(), 1.5)
    return p


_OUTER = None


def outer():
    """The whole pebble, chamfered once; every part is a slice of it."""
    global _OUTER
    if _OUTER is None:
        _OUTER = pebble(prism(OUT_W, OUT_L, R, 0, T))
    return _OUTER


def slab(z0, z1):
    return outer() & box(-OUT_W, OUT_W, -OUT_L, OUT_L, z0, z1)


def wall_openings(p, seam_lo, seam_hi, usb=True):
    """Button bores, SD slot and USB opening, wherever they fall in this part."""
    for y in (P.BTN1_CTR_Y, P.BTN2_CTR_Y):
        p -= Pos(OUT_W / 2 - 1, y, BTN_Z) * Rot(0, 90, 0) * Cylinder(P.BTN_BORE_D / 2, 4)
    sd_z = PCB_BACK - 0.8
    p -= box(IN_W / 2 - 1, OUT_W / 2 + 1, P.SD_CTR_Y - 7, P.SD_CTR_Y + 7,
             sd_z - 1.4, sd_z + 1.4)
    if usb:
        uz = PCB_BACK - 1.65
        p -= box(-P.USB_CTR_X - 4.5, -P.USB_CTR_X + 4.5, -OUT_L / 2 - 1, -IN_L / 2 + 1,
                 uz - 1.9, uz + 1.9)
    return p


def contents(cell_x=0.0):
    pcb = box(-P.PCB_W / 2, P.PCB_W / 2, -P.PCB_L / 2, P.PCB_L / 2, PCB_BACK, PCB_FRONT)
    for x, y in HOLES:
        pcb -= cyl_z(x, y, 2.2, PCB_BACK - 1, PCB_FRONT + 1)
    disp = box(-P.PANEL_W / 2, P.PANEL_W / 2, DISP_CY - P.PANEL_L / 2,
               DISP_CY + P.PANEL_L / 2, PCB_FRONT, GLASS)
    cell = box(cell_x - P.BATT_W / 2, cell_x + P.BATT_W / 2, -P.BATT_L / 2, P.BATT_L / 2,
               FLOOR, FLOOR + P.BATT_T)
    return pcb, disp, cell


# ---- A: sandwich -------------------------------------------------------------
def concept_a():
    SEAM = PCB_BACK                          # the back's rim is the PCB's seat
    # front: face + display pocket + board band; the y-end ledges are the seat
    f = slab(SEAM, T)
    f -= prism(IN_W, IN_L, R - WALL, SEAM, PCB_FRONT)                  # board band
    f -= Pos(0, DISP_CY, (PCB_FRONT + GLASS + 0.3) / 2) * Box(DISP_W, DISP_L, GLASS + 0.3 - PCB_FRONT)
    f -= box(-IN_W / 2, IN_W / 2, DISP_CY - DISP_L / 2 - 4, DISP_CY - DISP_L / 2,
             PCB_FRONT, PCB_FRONT + 2.5)                               # FPC relief
    f -= Pos(P.ACTIVE_CTR_X, DISP_CY, T) * Box(WIN, WIN, 2 * FACE + 1)
    f -= prism(IN_W - 2 * 1.0 + 0.8, IN_L - 2 * 1.0 + 0.8, R - WALL - 1.0 + 0.4,
               SEAM - 1, SEAM + 3.0)                                   # tongue rebate
    for x, y in HOLES:
        f -= cyl_z(x, y, 1.6, PCB_FRONT - 0.1, PCB_FRONT + 3.5)        # blind pilot
    f = wall_openings(f, SEAM, T, usb=False)

    b = slab(0, SEAM)
    b -= prism(IN_W, IN_L, R - WALL, FLOOR, SEAM + 1)
    b += prism(IN_W - 2 * 1.0, IN_L - 2 * 1.0, R - WALL - 1.0, SEAM, SEAM + 3.0) \
        - prism(IN_W - 2 * 2.0, IN_L - 2 * 2.0, R - WALL - 2.0, SEAM - 1, SEAM + 4)
    for x, y in HOLES:
        b += cyl_z(x, y, 6.4, FLOOR - 0.1, SEAM)                       # standoff
        b -= cyl_z(x, y, 2.4, -1, SEAM + 1)                            # screw through
        b -= cyl_z(x, y, 4.6, -1, 3.0)                                 # head counterbore
    b = wall_openings(b, 0, SEAM)
    screws = Part() + [cyl_z(x, y, 2.0, 3.0, PCB_FRONT + 3.0) + cyl_z(x, y, 3.8, 3.0, 4.6)
                       for x, y in HOLES]
    return dict(front=f, back=b, screws=screws), contents()


# ---- B: two hooks, one screw ------------------------------------------------
def concept_b():
    SEAM = 10.5
    HOOK_Y, HOOK_W, NOSE = 19.5, 4.0, 1.2
    xi = IN_W / 2                                                        # 19.0
    # back tray: floor, walls, tongue, pegged standoffs, hooks, screw boss
    b = slab(0, SEAM)
    b -= prism(IN_W, IN_L, R - WALL, FLOOR, SEAM + 1)
    b += prism(IN_W - 2 * 1.0, IN_L - 2 * 1.0, R - WALL - 1.0, SEAM, SEAM + 2.5) \
        - prism(IN_W - 2 * 2.0, IN_L - 2 * 2.0, R - WALL - 2.0, SEAM - 1, SEAM + 4)
    for x, y in HOLES:
        b += cyl_z(x, y, 5.0, FLOOR - 0.1, PCB_BACK)                    # standoff
        b += cyl_z(x, y, 1.9, PCB_BACK, PCB_BACK + 2.0)                 # peg in the hole
    for sy in (-1, 1):                                                   # two rigid hooks
        y = sy * HOOK_Y
        b += box(xi - 1.0, xi, y - HOOK_W / 2, y + HOOK_W / 2, SEAM - 0.1, SEAM + 3.2)
        nose = box(xi - 1.0, xi + NOSE, y - HOOK_W / 2, y + HOOK_W / 2, SEAM + 1.7, SEAM + 3.2)
        nose = chamfer(nose.faces().sort_by(Axis.Z).first.edges().filter_by(Axis.Y).sort_by(Axis.X).last, NOSE - 0.05)
        b += nose
    b += cyl_z(-17.5, 0, 5.6, FLOOR - 0.1, SEAM)                         # screw boss
    b -= cyl_z(-17.5, 0, 2.4, -1, SEAM + 1)
    b -= cyl_z(-17.5, 0, 4.6, -1, 3.0)
    b = wall_openings(b, 0, SEAM)

    f = slab(SEAM, T)
    f -= prism(IN_W, IN_L, R - WALL, SEAM - 1, GLASS + 0.3)
    f -= prism(IN_W - 2 * 1.0 + 0.8, IN_L - 2 * 1.0 + 0.8, R - WALL - 1.0 + 0.4,
               SEAM - 1, SEAM + 2.5)
    for sy in (-1, 1):                                                   # end ledges reach the PCB
        y0, y1 = (DISP_CY + DISP_L / 2 + 0.6, IN_L / 2 - 2.0) if sy > 0 \
            else (-IN_L / 2 + 2.0, DISP_CY - DISP_L / 2 - 3.5)
        f += box(-IN_W / 2 + 2.4, IN_W / 2 - 2.4, y0, y1, PCB_FRONT, GLASS + 0.4)
    for x, y in HOLES:
        f -= cyl_z(x, y, 2.4, PCB_FRONT - 1, PCB_FRONT + 2.2)           # peg clearance
    for sy in (-1, 1):                                                   # hook pockets
        y = sy * HOOK_Y
        f -= box(xi - 1.4, xi + NOSE + 0.3, y - HOOK_W / 2 - 0.3, y + HOOK_W / 2 + 0.3,
                 SEAM - 1, SEAM + 3.6)
    f += cyl_z(-17.5, 0, 5.6, SEAM, GLASS + 0.4)                          # screw boss
    f -= cyl_z(-17.5, 0, 1.6, SEAM - 0.1, SEAM + 3.2)
    f -= Pos(P.ACTIVE_CTR_X, DISP_CY, T) * Box(WIN, WIN, 2 * FACE + 1)
    f = wall_openings(f, SEAM, T, usb=False)
    screw = cyl_z(-17.5, 0, 2.0, 3.0, SEAM + 3.0) + cyl_z(-17.5, 0, 3.8, 3.0, 4.6)
    return dict(front=f, back=b, screws=screw), contents(cell_x=0.5)


# ---- C: sleeve + carrier + end cap -------------------------------------------
def concept_c():
    L_SLEEVE = OUT_L - 2.0                       # the cap plate makes up the length
    Y_MOUTH = -OUT_L / 2 + 2.0                   # -26.5, open end
    Y_TOP_IN = OUT_L / 2 - WALL                  # 26.5, inside of the closed end
    s = outer() & box(-OUT_W, OUT_W, Y_MOUTH, OUT_L, -1, T + 1)          # trim to the cap line
    tunnel = box(-IN_W / 2, IN_W / 2, Y_MOUTH - 1, Y_TOP_IN, FLOOR, GLASS + 0.3)
    tunnel = fillet(tunnel.edges().filter_by(Axis.Y), 2.0)
    s -= tunnel
    s -= Pos(P.ACTIVE_CTR_X, DISP_CY, T) * Box(WIN, WIN, 2 * FACE + 1)
    s += cyl_y(12.0, 5.2, 5.6, Y_MOUTH - 0.1, Y_MOUTH + 8.0)             # cap screw boss
    s -= cyl_y(12.0, 5.2, 1.6, Y_MOUTH - 1, Y_MOUTH + 6.0)
    s = wall_openings(s, 0, T, usb=False)

    # carrier: two low rails, four pegged blocks at the holes, a -Y crossbar
    c = Part()
    for sx in (-1, 1):
        c += box(min(sx * 16.7, sx * 18.6), max(sx * 16.7, sx * 18.6),
                 Y_MOUTH + 3.5, Y_TOP_IN - 0.4, FLOOR, FLOOR + 3.0)
    for x, y in HOLES:
        c += box(x - 2.6, x + 2.6, y - 2.6, y + 2.6, FLOOR, PCB_BACK)
        c += box(min(x, 16.7 * (1 if x > 0 else -1)), max(x, 16.7 * (1 if x > 0 else -1)),
                 y - 2.6, y + 2.6, FLOOR, FLOOR + 3.0)
        c += cyl_z(x, y, 1.9, PCB_BACK, PCB_BACK + 2.0)
    c += box(-16.7, 8.5, Y_MOUTH + 3.5, Y_MOUTH + 5.5, FLOOR, FLOOR + 3.0)
    c -= box(-P.USB_CTR_X - 5.0, -P.USB_CTR_X + 5.0, Y_MOUTH, Y_MOUTH + 6, FLOOR - 1, PCB_BACK)

    # cap: plate + tongue, USB through it, one countersunk screw beside the port
    k = outer() & box(-OUT_W, OUT_W, -OUT_L, Y_MOUTH, -1, T + 1)
    tongue = box(-IN_W / 2 + 0.3, IN_W / 2 - 0.3, Y_MOUTH - 0.1, Y_MOUTH + 3.0,
                 FLOOR + 0.3, GLASS)
    tongue = fillet(tongue.edges().filter_by(Axis.Y), 1.7)
    tongue -= box(-IN_W / 2 + 1.8, IN_W / 2 - 1.8, Y_MOUTH - 1, Y_MOUTH + 4, FLOOR + 1.8, GLASS - 1.5)
    k += tongue
    uz = PCB_BACK - 1.65
    k -= box(-P.USB_CTR_X - 4.5, -P.USB_CTR_X + 4.5, -OUT_L, Y_MOUTH + 4, uz - 1.9, uz + 1.9)
    k -= cyl_y(12.0, 5.2, 2.4, -OUT_L, Y_MOUTH + 4)
    k -= cyl_y(12.0, 5.2, 4.6, -OUT_L, -OUT_L / 2 + 1.2)
    screw = cyl_y(12.0, 5.2, 2.0, -OUT_L / 2 + 1.2, Y_MOUTH + 5.5) + cyl_y(12.0, 5.2, 3.8, -OUT_L / 2 + 0.2, -OUT_L / 2 + 1.2)
    return dict(sleeve=s, carrier=c, cap=k, screws=screw), contents()



# ---- D: corner press-fit (Pala's principle, our geometry) --------------------
# What Pala's case does, read off its STEP: butt-jointed walls, and all the
# engagement at the four CORNERS - the front's outer skin continues 2.6 mm
# below the seam as a quarter-round leg that presses into a rebate in the
# back's solid corner block. Nominal clearance 0.11, a 0.33 ridge on the block
# and a 0.34 lip on the leg overlapping 0.10 - a detent that the printer's own
# proud surfaces turn into a press fit. Nothing is a cantilever: the corner
# arc is the stiffest wall on the case.
D_WALL = 3.0
D_SKIN = 2.2               # the leg is this much of the outer skin
D_LEG = 2.6                # how far the leg drops below the seam
D_CLR = 0.11               # leg to block, drawn
D_RIDGE, D_LIP = 0.33, 0.34
D_CORNER = 9.8             # corner footprint that carries the leg


def _corner_boxes(z0, z1):
    b = Part()
    for sx in (-1, 1):
        for sy in (-1, 1):
            b += box(min(sx * OUT_W / 2, sx * (OUT_W / 2 - D_CORNER)),
                     max(sx * OUT_W / 2, sx * (OUT_W / 2 - D_CORNER)),
                     min(sy * OUT_L / 2, sy * (OUT_L / 2 - D_CORNER)),
                     max(sy * OUT_L / 2, sy * (OUT_L / 2 - D_CORNER)), z0, z1)
    return b


def _ring(inset_out, inset_in, z0, z1):
    """A band of the pebble outline between two insets from the outer face."""
    return prism(OUT_W - 2 * inset_out, OUT_L - 2 * inset_out, R - inset_out, z0, z1) \
        - prism(OUT_W - 2 * inset_in, OUT_L - 2 * inset_in, R - inset_in, z0 - 1, z1 + 1)


def concept_d(clr=D_CLR):
    D_CLR_ = clr
    SEAM = PCB_BACK
    inw, inl = OUT_W - 2 * D_WALL, OUT_L - 2 * D_WALL
    z_leg0 = SEAM - D_LEG
    corners_leg = _corner_boxes(z_leg0 - 0.01, SEAM + 0.01)

    # back: tray, corner posts to the PCB back, rebated corners, ridge
    b = slab(0, SEAM)
    b -= prism(inw, inl, R - D_WALL, FLOOR, SEAM + 1)
    for x, y in HOLES:
        b += cyl_z(x, y, 5.0, FLOOR - 0.1, SEAM)                          # post = PCB seat
    b -= (_ring(0, D_SKIN + D_CLR_, z_leg0, SEAM + 1) & corners_leg)     # rebate for the leg
    b += (_ring(D_SKIN + D_CLR_ - D_RIDGE, D_SKIN + D_CLR_ + 0.01, z_leg0 + 0.6, z_leg0 + 1.1)
          & corners_leg)                                                   # ridge
    b = wall_openings(b, 0, SEAM)

    # front: face, display pocket, board band, end ledges with pegs, corner legs, lip
    f = slab(SEAM, T)
    f -= prism(inw, inl, R - D_WALL, SEAM - 1, PCB_FRONT)                  # board band
    f -= Pos(0, DISP_CY, (PCB_FRONT + GLASS + 0.3) / 2) * Box(DISP_W, DISP_L, GLASS + 0.3 - PCB_FRONT)
    f -= box(-inw / 2, inw / 2, DISP_CY - DISP_L / 2 - 4, DISP_CY - DISP_L / 2,
             PCB_FRONT, PCB_FRONT + 2.5)                                   # FPC relief
    f -= Pos(P.ACTIVE_CTR_X, DISP_CY, T) * Box(WIN, WIN, 2 * FACE + 1)
    for x, y in HOLES:
        f += cyl_z(x, y, 1.9, PCB_BACK + 0.2, PCB_FRONT + 0.1)             # peg into the PCB hole
    f += (_ring(0, D_SKIN, z_leg0, SEAM + 0.01) & corners_leg)             # the legs
    f += (_ring(D_SKIN - 0.01, D_SKIN + D_LIP, z_leg0, z_leg0 + 0.5) & corners_leg)   # lip
    f = wall_openings(f, SEAM, T, usb=False)
    return dict(front=f, back=b), contents()



def export_d_coupons(clrs=(0.05, 0.10, 0.15), size=14.0):
    """One +X/+Y corner of each half of D at several drawn clearances. Notches
    on the outer edge count the variant: 1 = tightest. Front pieces are
    exported face-down, back pieces floor-down - the print orientations."""
    from build123d import Axis, Mesher, export_stl
    out = os.path.join(ROOT, "models", "next", "coupons")
    os.makedirs(out, exist_ok=True)
    corner = box(OUT_W / 2 - size, OUT_W + 1, OUT_L / 2 - size, OUT_L + 1, -1, T + 1)
    for i, clr in enumerate(clrs, 1):
        parts, _ = concept_d(clr)
        for k, part in parts.items():
            piece = part & corner
            for n in range(i):                                   # notches, count = variant
                piece -= box(OUT_W / 2 - size + 2 + 2.5 * n, OUT_W / 2 - size + 3 + 2.5 * n,
                             OUT_L / 2 - 1.2, OUT_L + 1, -1, T + 1)
            if k == "front":
                piece = piece.rotate(Axis.X, 180)
            bb = piece.bounding_box()
            piece = piece.moved(Pos(-bb.min.X, -bb.min.Y, -bb.min.Z))
            name = f"D_corner_{k}_clr{int(round(clr * 100)):03d}"
            export_stl(piece, os.path.join(out, name + ".stl"), tolerance=0.02)
            m = Mesher(); m.add_shape(piece); m.write(os.path.join(out, name + ".3mf"))
            print("wrote", name, "clr", clr)

# ---- rendering ---------------------------------------------------------------
BONE = (0.90, 0.87, 0.80)
SAGE = (0.62, 0.68, 0.58)
CLAY = (0.76, 0.55, 0.43)
PCBC = (0.16, 0.30, 0.22)
INK = (0.22, 0.20, 0.19)
STEEL = (0.55, 0.56, 0.58)
GLASSC = (0.96, 0.96, 0.94)

COLOURS = dict(front=BONE, back=SAGE, sleeve=BONE, carrier=CLAY, cap=SAGE, screws=STEEL)


def mesh(p):
    return shot.mesh_of(p)


def shift(m, dx=0, dy=0, dz=0):
    m = m.copy()
    m.apply_translation([dx, dy, dz])
    return m


def section(p, keep):
    return p & keep


def render_concept(name, parts, cont, explode, cut, sec_azim=-62, detail=None):
    os.makedirs(OUT, exist_ok=True)
    pcb, disp, cell = cont
    cm = [(mesh(pcb), PCBC), (mesh(disp), GLASSC), (mesh(cell), INK)]
    pm = {k: mesh(v) for k, v in parts.items() if len(v.solids()) > 0}

    closed = [(pm[k], COLOURS[k]) for k in pm if k != "screws"]
    shot.render(closed, os.path.join(OUT, f"{name}_closed.png"), elev=30, azim=-50)
    shot.render(closed, os.path.join(OUT, f"{name}_back.png"), elev=-32, azim=130)

    ex = []
    for k, m in pm.items():
        dx, dy, dz = explode.get(k, (0, 0, 0))
        ex.append((shift(m, dx, dy, dz), COLOURS[k]))
    dx, dy, dz = explode.get("contents", (0, 0, 0))
    ex += [(shift(m, dx, dy, dz), c) for m, c in cm]
    shot.render(ex, os.path.join(OUT, f"{name}_exploded.png"), elev=30, azim=-50, margin=1.18)

    sec = [(mesh(section(v, cut)), COLOURS[k]) for k, v in parts.items()
           if len((v & cut).solids()) > 0]
    sec += [(mesh(section(v, cut)), c) for v, c in ((pcb, PCBC), (disp, GLASSC), (cell, INK))
            if len((v & cut).solids()) > 0]
    shot.render(sec, os.path.join(OUT, f"{name}_section.png"), elev=18, azim=sec_azim)
    if detail is not None:
        shot.render(sec, os.path.join(OUT, f"{name}_detail.png"), elev=14, azim=sec_azim,
                    bounds=detail)


if __name__ == "__main__":
    which = sys.argv[1:] or ["a", "b", "c", "d"]
    if "a" in which:
        parts, cont = concept_a()
        render_concept("A_sandwich", parts, cont,
                       explode=dict(front=(0, 0, 22), screws=(0, 0, -14), contents=(0, 0, 9)),
                       cut=box(-OUT_W, OUT_W, P.HOLE_PITCH_Y / 2, OUT_L, -1, T + 1))
    if "b" in which:
        parts, cont = concept_b()
        render_concept("B_hook_one_screw", parts, cont,
                       explode=dict(front=(0, 0, 22), screws=(0, 0, -12), contents=(0, 0, 8)),
                       cut=box(-OUT_W, OUT_W, 0, OUT_L, -1, T + 1))
    if "c" in which:
        parts, cont = concept_c()
        render_concept("C_sleeve", parts, cont,
                       explode=dict(carrier=(0, -34, 0), contents=(0, -34, 0),
                                    cap=(0, -52, 0), screws=(0, -62, 0)),
                       cut=box(12.0, OUT_W, -OUT_L, OUT_L, -1, T + 1), sec_azim=-152)
    if "coupons" in which:
        export_d_coupons()
        sys.exit(0)
    if "d" in which:
        parts, cont = concept_d()
        render_concept("D_corner_pressfit", parts, cont,
                       explode=dict(front=(0, 0, 22), contents=(0, 0, 9)),
                       cut=box(-OUT_W, OUT_W, P.HOLE_PITCH_Y / 2 - 0.5, OUT_L, -1, T + 1),
                       detail=(np.array([OUT_W / 2 - 5.0, OUT_L / 2 - 3.0, PCB_BACK - 1.0]), 7.0))
    print("wrote", OUT)
