"""Case 1 — the reference case's inside, our outside.

Every internal dimension is read off `jota/ref/refcase_{top,bottom}.stl` by
`ref_extract.py` and lives in `params.py`. Only the outer shape is ours: the
8 mm pebble radius and the face chamfer. Where our derived numbers disagreed
with the reference the reference won, because it is a real object and ours
were inferred.

The concept worth taking from the reference is that ONE fastener holds the
board AND closes the case. Every mechanism this project invented — locating
pegs, skirt snaps, in-plane tabs, flange fingers — existed only because we
were solving those as two problems.

What the first attempt got wrong, and this file now gets right:

  * The joint is a LAP, not a butt. The back carries an outer skin, the front
    a tongue that nests inside it, overlapping 4.50 mm. Copied as a single
    solid wall it became two flat rims meeting on a plane with nothing but
    four screws in clearance holes to locate them.
  * The rim stays a continuous ring. Every side opening stops below it and
    every side opening has a 45 deg roof, so nothing prints over air.
  * The window is TAPERED, not counterbored. A 1.20 counterbore in a 1.25
    face left 0.05 mm of window wall standing on a 0.90 mm flat ledge.
  * The screws go BOARD-TO-FRONT: M2x4 pan heads on the PCB's back face,
    into the front's blind pilots — fitted BEFORE the back goes on. The
    back's standoff tubes stop C1_SCREW_HEAD_RELIEF short of the board so
    the heads have somewhere to live; drawn to touch the board (as they
    were), each tube landed on a head and held the case 1.60 mm open —
    the 2026-09-02 print. The front's face still gets no holes; the
    reference's screw-from-the-back path through the tube is dead.

Front prints window-face-down, back prints floor-down. Neither needs support.
"""

from build123d import (
    Axis, Box, Circle, Part, Plane, Polygon, Pos, Rectangle,
    RectangleRounded, Sphere, chamfer, extrude, fillet,
)

import params as P

# THE FRAME FLIP. The front is authored face-down (window on the bed, z=0 is
# the outer face) and is turned 180 deg about Y to assemble. That negates X.
# So anything in the front that has an X sign — the window offset, which
# wall the openings are in — is written in params.py in the ASSEMBLED frame
# (the same frame as the board, buttons on +X) and multiplied by AX here.
# The first two prints had the openings on the wrong wall because this
# line did not exist.
AX = -1

# The joint. Tongue thickness is fixed; the skin takes what is left between
# the outer and the board pocket. On the flats it is ~2.0, at the corner
# diagonal it thins toward the minimum — that corner is what sets C1_GROW.
OUT_X, OUT_Y = P.C1_OUT_W / 2, P.C1_OUT_L / 2
POK_X, POK_Y = P.C1_POCKET_W / 2, P.C1_POCKET_L / 2            # board pocket
TONGUE_X = TONGUE_Y = P.C1_TONGUE_T
SKIN_X = OUT_X - POK_X - P.C1_LAP_CLEAR - TONGUE_X
SKIN_Y = OUT_Y - POK_Y - P.C1_LAP_CLEAR - TONGUE_Y
CAV_X, CAV_Y = OUT_X - SKIN_X, OUT_Y - SKIN_Y                  # back tray
TON_X, TON_Y = CAV_X - P.C1_LAP_CLEAR, CAV_Y - P.C1_LAP_CLEAR  # tongue outside

# Corner radii. The pocket's is the reference's; each ring outside it is a
# true offset (radius grows by the ring's thickness), so tongue and clearance
# stay uniform round the corner. Only the outer keeps the pebble's R8, and
# only the skin therefore thins at the corner.
R_POK = P.C1_POCKET_R
R_TON = R_POK + P.C1_TONGUE_T
R_CAV = R_TON + P.C1_LAP_CLEAR
R_OUT = P.C1_EDGE_R

# assembled-frame levels, and the front's own authored frame (face on the bed)
JOINT_Z = P.C1_BACK_H                                          # 8.99
SEAT_A = P.C1_FACE_T + P.C1_DISP_D                             # 2.795 authored
JOINT_A = P.C1_H - JOINT_Z                                     # 4.50 authored


def _rrect(hx: float, hy: float, r: float):
    return RectangleRounded(2 * hx, 2 * hy, r)


def _pebble_edge(p: Part) -> Part:
    """Round the bed-side edge without ever exceeding a 45 deg overhang.

    Chamfer the bottom outer edge, then fillet the ring where that chamfer
    meets the wall. Done on the clean prism, so the only edges at z = c are
    that ring.
    """
    c, r = P.C1_FACE_CHAMFER, P.C1_FACE_FILLET
    p = chamfer(p.faces().sort_by(Axis.Z).first.outer_wire().edges(), c)
    ring = [e for e in p.edges()
            if abs(e.bounding_box().min.Z - c) < 1e-3
            and abs(e.bounding_box().max.Z - c) < 1e-3]
    return fillet(ring, r)


def build_back(sd_card: bool = True) -> Part:
    """The tray. Outer skin, floor, connector end, our side openings."""
    # Both rim chamfers go on while the prism is still whole. Cut the
    # connector opening first and the top rim is no longer a closed ring, and
    # OCC will not chamfer it.
    p = extrude(Plane.XY * _rrect(OUT_X, OUT_Y, R_OUT), P.C1_BACK_H)
    p = _pebble_edge(p)                                # the floor edge
    p = chamfer(p.faces().sort_by(Axis.Z).last.outer_wire().edges(),
                P.C1_JOINT_CHAMFER)                    # the rim: seam line

    # the cavity: everything above the floor, inset by the outer skin
    p -= extrude(Plane.XY.offset(P.C1_FLOOR_T) * _rrect(CAV_X, CAV_Y, R_CAV),
                 P.C1_BACK_H - P.C1_FLOOR_T)

    # the connector end, in the back only, floor to rim. The front's skirt
    # caps it once closed, which is why it may reach the rim and the button
    # and SD openings may not: this one is bounded on all four sides.
    # the USB port: a boss inside the cavity brings a wall up to 0.4 from
    # the receptacle face; a tight hole through it; a recess outside for the
    # plug's overmould nose. All open to the rim; the front caps them.
    bz0 = P.C1_USB_BOSS_Z0
    def ybox(w, ya, yb, za, zb, x=P.C1_USB_CTR_X):
        ya, yb = sorted((ya, yb)); za, zb = sorted((za, zb))
        return Pos(x, (ya + yb) / 2, (za + zb) / 2) * Box(w, yb - ya, zb - za)
    # boss: from just inside the skin up to the recess floor's inner face
    p += ybox(P.C1_USB_BOSS_W, -CAV_Y - 0.5, P.C1_USB_FLOOR_Y0, bz0, P.C1_BACK_H)
    # recess and hole, rounded, cut along Y from outside: the recess to the
    # seat (flush with the receptacle face), the hole on through the floor
    def ycut(w, h, r, y_to, z_c, x=P.C1_USB_CTR_X):
        depth = y_to - (-OUT_Y - 1.0)
        return extrude(Plane.XZ.offset(OUT_Y + 1.0) * Pos(x, z_c)
                       * RectangleRounded(w, h, r), -depth)
    rec_to = (P.C1_USB_FLOOR_Y0 + 0.5) if P.C1_USB_NO_FLOOR else P.C1_USB_FLOOR_Y1
    p -= ycut(P.C1_USB_REC_W, P.C1_USB_REC_H, P.C1_USB_REC_R, rec_to, P.C1_USB_CTR_Z)
    p -= ycut(P.C1_USB_HOLE_W, P.C1_USB_HOLE_H, P.C1_USB_HOLE_R, P.C1_USB_FLOOR_Y0 + 0.5, P.C1_USB_CTR_Z)
    # both also reach the rim above their own tops (the front caps them)
    p -= ybox(P.C1_USB_REC_W - 2 * P.C1_USB_REC_R, -OUT_Y - 1.0, rec_to,
              P.C1_USB_CTR_Z, P.C1_BACK_H + 1.0)
    p -= ybox(P.C1_USB_REC_W, -OUT_Y - 1.0, rec_to,
              P.C1_USB_CTR_Z + P.C1_USB_REC_H / 2 - P.C1_USB_REC_R, P.C1_BACK_H + 1.0)
    p -= ybox(P.C1_USB_HOLE_W - 2 * P.C1_USB_HOLE_R, -OUT_Y - 1.0, P.C1_USB_FLOOR_Y0 + 0.5,
              P.C1_USB_CTR_Z, P.C1_BACK_H + 1.0)
    p -= ybox(P.C1_USB_HOLE_W, -OUT_Y - 1.0, P.C1_USB_FLOOR_Y0 + 0.5,
              P.C1_USB_CTR_Z + P.C1_USB_HOLE_H / 2 - P.C1_USB_HOLE_R, P.C1_BACK_H + 1.0)

    # the slide-lock tabs: five rigid wedges on the +-Y walls' inner faces.
    # Flat top (the working face, prints clean floor-down), 45 deg underside
    # (self-supporting). The front's tongue windows pass over them on the
    # drop and the slide parks each tab over a strip of tongue. Nothing here
    # bends: engagement is the tongue's thickness, clearance is C1_WIN_C.
    zt = P.C1_BACK_H - P.C1_TAB_TOP                      # tab top, assembled
    e, fl = P.C1_TAB_E, P.C1_TAB_FLAT
    for sy, sites in ((-1, P.C1_SLIDE_SITES_NY), (+1, P.C1_SLIDE_SITES_PY)):
        yw = sy * CAV_Y                                  # wall inner face
        prof = [(yw + sy * 0.3, zt), (yw - sy * e, zt),
                (yw - sy * e, zt - fl), (yw + sy * 0.3, zt - fl - e - 0.3)]
        #      root extension ^0.3 continues the 45 deg plane INTO the wall;
        #      ending it flat made the chamfer 49 deg and failed the scan
        for xс, tw in sites:
            p += extrude(Plane.YZ.offset(xс) * Polygon(*prof), tw / 2, both=True)

    # the backing ribs (see C1_SLIDE_RIB_* in params): one per site, on the
    # floor, C1_SLIDE_RIB_C inside the tongue's inner face, over the tab's
    # locked span. Trimmed to the tongue's inner outline at BOTH the locked
    # and the drop offset, so the corner arcs never touch it on the way down.
    rt = P.C1_FLOOR_T + P.C1_STANDOFF_H                   # rib top = standoff top
    inner = None
    for dx in (0.0, -P.C1_SLIDE_T):
        rr = extrude(Pos(dx, 0, P.C1_FLOOR_T - 0.1)
                     * _rrect(POK_X - P.C1_SLIDE_RIB_C, POK_Y - P.C1_SLIDE_RIB_C,
                              max(R_POK - P.C1_SLIDE_RIB_C, 0.5)), rt - P.C1_FLOOR_T + 0.1)
        inner = rr if inner is None else inner & rr
    for sy, sites in ((-1, P.C1_SLIDE_SITES_NY), (+1, P.C1_SLIDE_SITES_PY)):
        yi = sy * POK_Y                                  # tongue inner face
        for xc, tw in sites:
            m = P.C1_SLIDE_RIB_MARGIN
            rib = (Pos(xc, yi - sy * (P.C1_SLIDE_RIB_C + P.C1_SLIDE_RIB_T / 2),
                       (P.C1_FLOOR_T - 0.1 + rt) / 2)
                   * Box(tw + 2 * m, P.C1_SLIDE_RIB_T, rt - P.C1_FLOOR_T + 0.1))
            p += rib & inner

    # the key slot, back half: through the -X skin, from C1_KEY_ZB under
    # the seam up past the rim. The front's shelf carries the other half;
    # with the key in, the front cannot slide back toward -X.
    p -= (Pos(-OUT_X + P.C1_KEY_DEPTH / 2 - 0.5, 0,
              (P.C1_BACK_H - P.C1_KEY_ZB + P.C1_BACK_H + 1.0) / 2)
          * Box(P.C1_KEY_DEPTH + 1.0, P.C1_KEY_W, P.C1_KEY_ZB + 1.0))

    # The buttons and the SD slot: U-slots open to the rim, capped by the
    # front once closed (the reference's idea for the USB). Each is a notch
    # in the rim, not a break through it.
    slots = [(P.BTN1_CTR_Y, P.C1_BTN_SLOT_W, P.C1_BTN_SLOT_Z0),
             (P.BTN2_CTR_Y, P.C1_BTN_SLOT_W, P.C1_BTN_SLOT_Z0)]
    if sd_card:
        slots.append((P.SD_CTR_Y, P.C1_SD_L, P.C1_SD_SLOT_Z0))
    for y, w, z0 in slots:
        p -= (Pos(OUT_X, y, (z0 + P.C1_BACK_H + 1.0) / 2)
              * Box(2 * SKIN_X + 1.0, w, P.C1_BACK_H + 1.0 - z0))

    # the cell's ribs. Two along its sides, two across its ends, none of
    # them near a screw column: a closed fence's corners overhang the
    # clearance holes.
    hw = P.C1_BATT_POCKET_W / 2
    hl = P.C1_BATT_POCKET_L / 2
    t, h = P.C1_BATT_RIB_T, P.C1_BATT_RIB_H
    zc = P.C1_FLOOR_T + h / 2
    for sx in (-1, 1):
        if (sx > 0 and not P.C1_BATT_RIB_PX) or (sx < 0 and not P.C1_BATT_RIB_NX):
            continue        # header build: the header and the tongue are the stops
        p += (Pos(P.C1_BATT_CTR_X + sx * (hw + t / 2), P.C1_BATT_CTR_Y, zc)
              * Box(t, 2 * hl, h))
    span = P.C1_BATT_RIB_SPAN_X
    # -Y end: one rib. +Y end: a rib with a break at its +X end for the
    # cell's leads, which go to the BAT connector in the board's +X,+Y corner.
    p += (Pos(P.C1_BATT_CTR_X, P.C1_BATT_CTR_Y - hl - t / 2, zc)
          * Box(span, t, h))
    x0, x1 = -span / 2, P.C1_BATT_LEAD_X0
    p += (Pos(P.C1_BATT_CTR_X + (x0 + x1) / 2, P.C1_BATT_CTR_Y + hl + t / 2, zc)
          * Box(x1 - x0, t, h))

    if P.C1_SPEAKER:
        # the speaker bay: two short ribs locate it in X, the cell's +Y rib in
        # -Y, the skin in +Y, the board above. Then the grille through the skin.
        sy0 = P.C1_BATT_CTR_Y + hl + t                      # cell rib outer face
        sw, st = P.C1_SPK_POCKET_W, P.C1_SPK_RIB_T
        for sx in (-1, 1):
            p += (Pos(P.C1_SPK_CTR_X + sx * (sw / 2 + st / 2), (sy0 + CAV_Y) / 2,
                      P.C1_FLOOR_T + P.C1_SPK_RIB_H / 2)
                  * Box(st, CAV_Y - sy0, P.C1_SPK_RIB_H))
        n, w, hh, pitch = (P.SPK_GRILL_SLOTS, P.SPK_SLOT_W, P.SPK_SLOT_H,
                           P.SPK_SLOT_PITCH)
        for i in range(n):
            xc = P.C1_SPK_CTR_X + (i - (n - 1) / 2) * pitch
            z0 = P.C1_SPK_SLOT_Z0
            gable = [(xc - w / 2, z0), (xc + w / 2, z0), (xc + w / 2, z0 + hh),
                     (xc, z0 + hh + w / 2), (xc - w / 2, z0 + hh)]
            p -= extrude(Plane.XZ.offset(-OUT_Y) * Polygon(*gable), 4.0, both=True)

    # the thumb dish, centred on the record button; the front carries the
    # rest of the same sphere
    p -= (Pos(OUT_X + P.C1_DISH_R - P.C1_DISH_DEPTH, P.C1_DISH_Y, P.C1_DISH_Z)
          * Sphere(P.C1_DISH_R))

    # standoffs: a column per screw, stopping C1_SCREW_HEAD_RELIEF short of
    # the board's back face — the board-to-front screw heads live in that
    # band. Drawn to TOUCH the board, each column landed on a head and the
    # 2026-09-02 print could not close by exactly the head height.
    for x, y in P.C1_SCREW_XY:
        p += extrude(Plane.XY.offset(P.C1_FLOOR_T) * Pos(x, y)
                     * Circle(P.C1_STANDOFF_OD / 2), P.C1_STANDOFF_H)

    # clearance straight through the floor and column. The screw-from-the-
    # back option is dead (the column no longer clamps), but the hole stays:
    # it is the reference's, and it drains the tube when the case is washed.
    for x, y in P.C1_SCREW_XY:
        p -= extrude(Plane.XY * Pos(x, y) * Circle(P.C1_SCREW_CLEAR_D / 2),
                     P.C1_FLOOR_T + P.C1_STANDOFF_H)

    # the cord tunnel's two mouths, teardrop section so they print flat.
    # A through the +Y end skin (axis Y), B through the -X side skin (axis X).
    import math
    r, zc = P.C1_TUN_HOLE_D / 2, P.C1_TUN_Z
    def teardrop(uc):
        pts = [(uc, zc + r * math.sqrt(2))]
        for k in range(0, 271, 10):
            a = math.radians(45 - k)
            pts.append((uc + r * math.cos(a), zc + r * math.sin(a)))
        return pts
    sx, sy = P.C1_TUN_SX, P.C1_TUN_SY
    ax = sx * P.C1_TUN_A_X
    p -= extrude(Plane.XZ.offset(-sy * OUT_Y) * Polygon(*teardrop(ax)),
                 SKIN_Y + 1.5, both=True)
    by = sy * P.C1_TUN_B_Y
    p -= extrude(Plane.YZ.offset(sx * OUT_X) * Polygon(*teardrop(by)),
                 SKIN_X + 1.5, both=True)
    return p


def build_front(sd_card: bool = True) -> Part:
    """The half that holds everything: face, window, display, board, tongue."""
    # outer face chamfer first, on the clean prism, for the same reason
    p = extrude(Plane.XY * _rrect(OUT_X, OUT_Y, R_OUT), P.C1_FRONT_H)
    p = _pebble_edge(p)                                # the face edge

    # below the joint the part steps in to the tongue
    p -= (extrude(Plane.XY.offset(JOINT_A) * _rrect(OUT_X, OUT_Y, R_OUT),
                  P.C1_FRONT_H - JOINT_A)
          - extrude(Plane.XY.offset(JOINT_A) * _rrect(TON_X, TON_Y, R_TON),
                    P.C1_FRONT_H - JOINT_A))

    # the seam chamfer on the front's rim — the reference has it on both
    # halves, so the seam reads as one 1.6 mm V-line. Done on the clean
    # step edge, before any relief breaks it.
    # the step face is the one horizontal face at z = JOINT_A; its OUTER
    # wire is the rim. (A filter on edge position also caught the tongue's
    # +-Y root edges — an inconsistent set that OCC chamfered into a hole.)
    step = [f for f in p.faces()
            if abs(f.center().Z - JOINT_A) < 1e-3 and abs(f.normal_at().Z) > 0.99
            and f.area > 100.0][0]
    p = chamfer(step.outer_wire().edges(), P.C1_JOINT_CHAMFER)

    # board pocket, open to the tongue's free end
    p -= extrude(Plane.XY.offset(SEAT_A) * Pos(0, P.C1_POCKET_CTR_Y)
                 * _rrect(POK_X, POK_Y, R_POK),
                 P.C1_FRONT_H - SEAT_A)

    # display pocket, centred on the board
    p -= extrude(Plane.XY.offset(P.C1_FACE_T)
                 * Rectangle(P.C1_DISP_W, P.C1_DISP_L), P.C1_DISP_D)

    # the window, pierced straight — the taper is the chamfer below, and it
    # is a chamfer and not a counterbore on purpose
    p -= extrude(Plane.XY * Pos(AX * P.C1_WIN_CTR_X, P.C1_WIN_CTR_Y)
                 * Rectangle(P.C1_WIN_W, P.C1_WIN_L), P.C1_FACE_T)
    face = p.faces().sort_by(Axis.Z).first
    p = chamfer([e for w in face.inner_wires() for e in w.edges()],
                P.C1_WIN_FLARE)

    # The tongue is relieved behind each button (the pin's flange needs the
    # space) and behind the SD slot (the card does). Every relief starts
    # exactly AT the joint face. All on the board's +X edge: +1 assembled, AX.
    reliefs = [(P.BTN1_CTR_Y, P.C1_BTN_RELIEF_W),
               (P.BTN2_CTR_Y, P.C1_BTN_RELIEF_W)]
    if sd_card:
        reliefs.append((P.SD_CTR_Y, P.C1_SD_L))
    for y, w in reliefs:
        p -= (Pos(AX * OUT_X, y, JOINT_A + (P.C1_FRONT_H - JOINT_A + 0.2) / 2)
              * Box(2 * (OUT_X - POK_X) + 1.0, w, P.C1_FRONT_H - JOINT_A + 0.2))

    # a shallow notch above the joint at each button, so a pin head riding
    # high still has somewhere to go
    for y in (P.BTN1_CTR_Y, P.BTN2_CTR_Y):
        p -= (Pos(AX * OUT_X, y, JOINT_A - P.C1_BTN_FRONT_NOTCH / 2 + 0.05)
              * Box(2 * (OUT_X - POK_X) + 1.0, P.C1_BTN_SLOT_W,
                    P.C1_BTN_FRONT_NOTCH + 0.1))

    # the connector. Above the seam the front continues the recess floor:
    # a block in the shelf band from the pocket wall to 0.3 off the PCB edge,
    # then the recess is cut into it to the seat and the tight hole through.
    # The tongue is relieved over the port below the shelf.
    # relief widened +x by the slide travel: at the DROP position the whole
    # front sits C1_SLIDE_T toward -X, so the tongue's edge beside the boss
    # arrives offset and would land on the boss without the extra span
    p -= (Pos(AX * (P.C1_USB_CTR_X + P.C1_SLIDE_T / 2), -OUT_Y,
              JOINT_A + (P.C1_FRONT_H - JOINT_A + 0.2) / 2)
          * Box(P.C1_USB_BOSS_W + 1.0 + P.C1_SLIDE_T, 2 * (OUT_Y - POK_Y) + 1.0,
                P.C1_FRONT_H - JOINT_A + 0.2))
    blk_y0, blk_y1 = sorted((P.C1_USB_FLOOR_Y0, -POK_Y - 0.01))   # -24.66 .. -23.80
    if not P.C1_USB_NO_FLOOR:
        p += (Pos(AX * P.C1_USB_CTR_X, (blk_y0 + blk_y1) / 2, (SEAT_A + (P.C1_H - P.C1_Y_STOP_Z0)) / 2)
              * Box(P.C1_USB_BOSS_W, blk_y1 - blk_y0, (P.C1_H - P.C1_Y_STOP_Z0) - SEAT_A))
    # the -Y board stop: two blocks flanking the recess, so it survives the
    # no-floor variant (where the floor, which used to be the stop, is gone)
    for sx in (-1, 1):
        x0, x1 = P.C1_Y_STOP_X0, P.C1_Y_STOP_X1
        p += (Pos(AX * (P.C1_USB_CTR_X + sx * (x0 + x1) / 2),
                  (blk_y0 + blk_y1) / 2, (SEAT_A + (P.C1_H - P.C1_Y_STOP_Z0)) / 2)
              * Box(x1 - x0, blk_y1 - blk_y0, (P.C1_H - P.C1_Y_STOP_Z0) - SEAT_A))
    # and the matching Y stop at +Y, so the board cannot drift away from
    # the port when a cable is pushed in
    sy0, sy1 = sorted((P.C1_Y_STOP, POK_Y + 0.01))
    p += (Pos(0, (sy0 + sy1) / 2, (SEAT_A + (P.C1_H - P.C1_Y_STOP_Z0)) / 2)
          * Box(P.C1_Y_STOP_W, sy1 - sy0, (P.C1_H - P.C1_Y_STOP_Z0) - SEAT_A))
    def ycut_f(w, h, r, y_to):
        # authored frame: the SAME rounded profile as the back's ycut,
        # centred on the connector (authored z = C1_H - CTR_Z), cut from
        # outside inward to y_to. Its below-joint part lands in the port
        # relief; its above-joint part IS the notch, so front and back share
        # one profile and the assembled mouth is exactly the drawn rounded
        # rect — the old square-cornered, recess-wide notch put ~1.3 mm2 of
        # corner spill above the seam and read as part of the opening.
        depth = y_to - (-OUT_Y - 1.0)
        return extrude(Plane.XZ.offset(OUT_Y + 1.0)
                       * Pos(AX * P.C1_USB_CTR_X, P.C1_H - P.C1_USB_CTR_Z)
                       * RectangleRounded(w, h, r), -depth)
    p -= ycut_f(P.C1_USB_REC_W, P.C1_USB_REC_H, P.C1_USB_REC_R,
                (P.C1_USB_FLOOR_Y0 + 0.5) if P.C1_USB_NO_FLOOR else P.C1_USB_FLOOR_Y1)
    # the hole goes through the block into the pocket: the receptacle's
    # top-front corner lives there. Above the seam this steps the notch down
    # from recess width to hole width — the tight staircase.
    p -= ycut_f(P.C1_USB_HOLE_W, P.C1_USB_HOLE_H, P.C1_USB_HOLE_R,
                P.C1_USB_FLOOR_Y0 + 0.5)

    # the slide-lock, front side. All rigid; the mesh sweep in the checker
    # is the proof it drops, slides and locks. Order matters here: the
    # deepened segments are pure ADDS, so every relief that must win over
    # them (the USB boss relief, the standoff sweep reliefs) is re-cut
    # AFTER them. That ordering bug put tongue back inside the USB relief
    # on the first attempt and the boss hit it at the drop offset.
    # authored x = -assembled x throughout (AX).
    p -= (Pos(AX * -((P.C1_TONGUE_XCUT + TON_X + 1.0) / 2), 0,
              JOINT_A + (P.C1_FRONT_H - JOINT_A + P.C1_SEG_EXTRA + 1.0) / 2)
          * Box(TON_X + 1.0 - P.C1_TONGUE_XCUT, 2 * OUT_Y + 2.0,
                P.C1_FRONT_H - JOINT_A + P.C1_SEG_EXTRA + 1.0))
    wz_hi = JOINT_A + P.C1_TAB_TOP - P.C1_WIN_C          # authored window band
    wz_lo = JOINT_A + P._win_bot                         # floor hugs the chamfer
    tip = P.C1_FRONT_H + P.C1_SEG_EXTRA                  # deepened tongue tip
    for sy, sites in ((-1, P.C1_SLIDE_SITES_NY), (+1, P.C1_SLIDE_SITES_PY)):
        yc = sy * (POK_Y + TONGUE_Y / 2)                 # tongue band centre
        for xc, tw in sites:
            a = xc - tw / 2 - P.C1_WIN_C                 # window, assembled x
            b = xc + P.C1_SLIDE_T + tw / 2 + P.C1_WIN_C
            na = a + P.C1_SLIDE_T                        # roofed span ends /
            #                                              entry notch starts
            # the deeper segment: same tongue, over the roofed span + margin
            s0, s1 = a - P.C1_SEG_MARGIN, na + 0.3
            p += (Pos(AX * (s0 + s1) / 2, yc,
                      (P.C1_FRONT_H - 0.5 + tip) / 2)
                  * Box(s1 - s0, TONGUE_Y, tip - P.C1_FRONT_H + 0.5))
            # the window (roofed span), then the entry notch on to the tip
            p -= (Pos(AX * (a + b) / 2, yc, (wz_hi + wz_lo) / 2)
                  * Box(b - a, TONGUE_Y + 0.8, wz_lo - wz_hi))
            p -= (Pos(AX * (na + b) / 2, yc, (wz_hi + tip + 1.0) / 2)
                  * Box(b - na, TONGUE_Y + 0.8, tip + 1.0 - wz_hi))
    # standoff sweep reliefs: at the drop offset (and all through the slide)
    # the +X tongue run passes over the +X standoffs, whose tops stand well
    # above the ring's tip. The run keeps its seam band — the lap survives —
    # and loses only the depth below the standoff tops, only there.
    so_top_a = P.C1_H - (P.C1_FLOOR_T + P.C1_STANDOFF_H + 0.30)  # authored
    for sy in (-1, 1):
        yc = sy * abs(P.C1_SCREW_XY[0][1])
        p -= (Pos(AX * (POK_X + TONGUE_Y / 2 + 0.5), yc,
                  (so_top_a + tip + 1.0) / 2)
              * Box(TONGUE_Y + 3.0, P.C1_STANDOFF_OD + P.C1_SLIDE_T + 1.2,
                    tip + 1.0 - so_top_a))
    # re-cut the USB boss relief over the segments (see ordering note above)
    p -= (Pos(AX * (P.C1_USB_CTR_X + P.C1_SLIDE_T / 2), -OUT_Y,
              JOINT_A + (P.C1_FRONT_H - JOINT_A + P.C1_SEG_EXTRA + 1.0) / 2)
          * Box(P.C1_USB_BOSS_W + 1.0 + P.C1_SLIDE_T, 2 * (OUT_Y - POK_Y) + 1.0,
                P.C1_FRONT_H - JOINT_A + P.C1_SEG_EXTRA + 1.0))
    # the key slot, front half: into the shelf above the seam, meeting the
    # back's half at the seam plane. Cut from the outer face inward.
    p -= (Pos(AX * -(OUT_X - P.C1_KEY_DEPTH / 2 + 0.5), 0,   # the -X wall, assembled
              JOINT_A - P.C1_KEY_ZA + (P.C1_KEY_ZA + 0.3) / 2)
          * Box(P.C1_KEY_DEPTH + 1.0, P.C1_KEY_W, P.C1_KEY_ZA + 0.3))

    # the other half of the thumb dish: same sphere, through the frame flip
    p -= (Pos(AX * (OUT_X + P.C1_DISH_R - P.C1_DISH_DEPTH), P.C1_DISH_Y,
              P.C1_H - P.C1_DISH_Z)
          * Sphere(P.C1_DISH_R))

    # blind pilots, drilled from the board seat toward the face and stopping
    # short of it, so no hole reaches the face you read
    for x, y in P.C1_SCREW_XY:
        p -= extrude(Plane.XY.offset(SEAT_A - P.C1_SCREW_PILOT_DEPTH)
                     * Pos(x, y) * Circle(P.C1_SCREW_PILOT_D / 2),
                     P.C1_SCREW_PILOT_DEPTH)
    return p


def build_pin(record: bool = False) -> Part:
    """A button pin. Flange down on the bed; stem and head stand on it.

    Head outboard (proud of the skin), stem through the U-slot, flange
    inboard against the skin's inner face. The switch pushes the pin OUT
    and the flange is what stops it. Fitted from inside, before the board.

    The record pin stands further out and is domed; PWR is flat. Both heads
    are the stem's own diameter, because both must pass the slot from inside.
    """
    proud = P.C1_PIN_REC_PROUD if record else P.C1_PIN_HEAD_PROUD
    stem_l = SKIN_X + proud
    pin = extrude(Plane.XY * Circle(P.C1_PIN_FLANGE_D / 2), P.C1_PIN_FLANGE_L)
    pin += extrude(Plane.XY.offset(P.C1_PIN_FLANGE_L)
                   * Circle(P.C1_PIN_STEM_D / 2), stem_l)
    if record:
        # domed by rounding the head's rim — one fillet, no boolean seam.
        # A sphere-and-cylinder dome would not tessellate closed.
        from build123d import fillet
        top_edge = pin.edges().filter_by(Axis.Z, reverse=True).sort_by(Axis.Z).last
        pin = fillet(top_edge, P.C1_PIN_REC_DOME)
    return pin


def build_key() -> Part:
    """The slide-lock's key: a flat pin across the seam, -X wall.

    Pushed in after the slide, it fills the front's slide-back path —
    the case cannot reopen until it is pried out by the nail groove.
    Drawn C1_KEY_FIT under the slot each way; print growth closes
    that to snug. The ONLY fit-tuned part of the closure — loose or
    tight, reprint THIS at +-0.1, never the case.

    Prints lying on its largest face; the nail groove faces up.
    """
    w = P.C1_KEY_W - 2 * P.C1_KEY_FIT
    h = P.C1_KEY_ZB + P.C1_KEY_ZA - 2 * P.C1_KEY_FIT
    d = P.C1_KEY_DEPTH - 0.20
    k = extrude(Plane.XY * Rectangle(d, w), h)
    k -= (Pos(-d / 2 + 0.4, 0, h / 2)
          * Box(0.8, P.C1_KEY_NAIL, h - 1.6))            # the pry groove
    return k


PIN_FREE_TRAVEL = (CAV_X - P.C1_PIN_FLANGE_L) - P.SWITCH_TIP_X   # 0.46


if __name__ == "__main__":
    print(f"  joint: skin {SKIN_X:.3f}/{SKIN_Y:.3f}  tongue {P.C1_TONGUE_T:.2f}"
          f"  clearance {P.C1_LAP_CLEAR:.2f}  lap {P.C1_LAP_D:.2f} deep"
          f"  corners pocket R{R_POK} tongue R{R_TON} cavity R{R_CAV} outer R{R_OUT}")
    print(f"  pin: free travel {PIN_FREE_TRAVEL:.2f} before the switch, "
          f"then {P.BTN_SWITCH_TRAVEL:.2f} of switch")
    for nm, part in (("front", build_front(False)), ("back", build_back(False)),
                     ("front_sd_card", build_front()), ("back_sd_card", build_back()),
                     ("pin_pwr", build_pin()), ("pin_rec", build_pin(True))):
        b = part.bounding_box()
        print(f"  {nm:6s} {part.volume/1000:5.2f} cm3  "
              f"{b.size.X:.2f} x {b.size.Y:.2f} x {b.size.Z:.2f}")
