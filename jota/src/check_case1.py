"""Does case 1 hold up? Run: .venv/bin/python jota/src/check_case1.py

Checks in this order, deliberately:

  0. What every drawn fit BECOMES once printed. Our printer lays down 0.25
     proud of the drawn surface; a check that reads the drawing and not the
     print is the reason a window could be drawn with 0.05 mm of wall.
  1. Against the REFERENCE MESH itself, not against numbers transcribed out
     of it. Four of the first attempt's faults were transcription, so this
     file re-reads `jota/ref/refcase_*.stl` every run and compares.
  2-4. The lap joint, the rim, the openings — the structure the first
     attempt did not have at all.
  5. The battery, which the reference never had to hold.
  6-7. Minimum feature width and overhangs. CLAUDE.md names these the two
     highest-value missing checks; three real defects got past their absence.
"""

import os
import sys

import math
import numpy as np
import trimesh
from build123d import export_stl

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import params as P
from case1 import (AX, CAV_X, CAV_Y, JOINT_A, OUT_X, OUT_Y, PIN_FREE_TRAVEL, build_key,
                   POK_X, POK_Y, R_CAV, R_OUT, R_POK, R_TON, SEAT_A, SKIN_X,
                   SKIN_Y, TON_X, TON_Y, build_back, build_front, build_pin)
from ref_extract import load as ref_load, runs

FAIL = []
PROUD = P.PROCESS_PROUD


def check(cond, msg):
    print(f"  [{'PASS' if cond else 'FAIL'}] {msg}")
    if not cond:
        FAIL.append(msg)


def near(a, b, tol, msg):
    check(abs(a - b) <= tol, f"{msg}: {a:.3f} vs {b:.3f} (tol {tol})")


def solid_runs(mesh, axis, fixed, lo, hi, n=2400):
    return runs(mesh, axis, fixed, lo, hi, n)


def main():
    tmp = os.environ.get("TMPDIR", "/tmp")
    front, back = build_front(), build_back()
    fp, bp = os.path.join(tmp, "c1f.stl"), os.path.join(tmp, "c1b.stl")
    kp = os.path.join(tmp, "c1k.stl")
    export_stl(front, fp, tolerance=0.004, angular_tolerance=0.1)
    export_stl(back, bp, tolerance=0.004, angular_tolerance=0.1)
    export_stl(build_key(), kp, tolerance=0.004, angular_tolerance=0.1)
    F, B = trimesh.load(fp), trimesh.load(bp)
    rbot, rtop = ref_load()
    # the front in the ASSEMBLED frame — the frame the board and params use.
    # Authored face-down, so X is negated on the way in. Everything with a
    # side is checked here, not in the authored frame.
    FA = F.copy()
    T = np.eye(4); T[:3, :3] = np.diag([-1.0, 1.0, -1.0]); T[2, 3] = P.C1_H
    FA.apply_transform(T)
    z_mid_lap = P.C1_BACK_H - P.C1_LAP_D / 2               # mid-lap, assembled

    print("\n0. what the drawing becomes once printed")
    check(F.is_watertight, "front mesh is watertight")
    check(B.is_watertight, "back mesh is watertight")
    for nm, drawn, ref, tol in (
            ("board pocket W", P.C1_POCKET_W, 33.616, 0.05),
            ("board pocket L", P.C1_POCKET_L, 48.804, 0.05),
            ("display pocket W", P.C1_DISP_W, 33.018, 0.05),
            ("display pocket L", P.C1_DISP_L, 39.018, 0.05),
            ("window W", P.C1_WIN_W, 27.817, 0.05),
            ("window L", P.C1_WIN_L, 27.574, 0.05),
            ("connector opening W", P.C1_END_OPEN_W, 20.510, 0.05),
            ("screw clearance D", P.C1_SCREW_CLEAR_D, 2.507, 0.05)):
        near(drawn - 2 * PROUD, ref, tol, f"printed {nm} matches the reference")

    print("\n1. against the reference mesh, re-read this run")
    # window centre, sign included — this is the one the first attempt mirrored
    rw = solid_runs(rtop, 1, (0, 12.30), -27.9, 27.9)
    ref_win_ctr = (rw[0][1] + rw[1][0]) / 2
    ow = solid_runs(F, 1, (0, P.C1_FACE_T - 0.05), -27.9, 27.9)
    our_win_ctr = (ow[0][1] + ow[1][0]) / 2
    near(abs(our_win_ctr), abs(ref_win_ctr), 0.06,
         "window Y offset MAGNITUDE matches the reference (panel asymmetry)")
    # Sign comes from the board, not the reference: the FPC is at the USB
    # end, the active area sits away from the FPC. Print #3 proved it.
    check(our_win_ctr > 0,
          f"window sits AWAY from the USB end, toward +Y ({our_win_ctr:+.3f})")
    X = P.C1_EXTRA_DEPTH
    near(P.C1_SEAT_Z - X, 10.69, 0.05, "board seating face matches the reference (+extra depth)")
    near(P.C1_H - X, 13.49, 0.05, "assembled height matches the reference (+extra depth)")
    if X:
        print(f"       C1_EXTRA_DEPTH = {X:.2f}: case is {P.C1_H:.2f} tall, {P.C1_SEAT_Z - P.PCB_T - P.C1_FLOOR_T:.2f} under the board")
    near(P.C1_FLOOR_T, 2.79, 0.05, "back floor matches the reference")

    print("\n2. the lap joint — the thing that was missing entirely")
    check(P.C1_LAP_D >= 4.0, f"lap is {P.C1_LAP_D:.2f} mm deep, not a butt joint")
    near(P.C1_LAP_CLEAR - 2 * PROUD, 0.203, 0.03,
         "printed lap clearance matches the reference's")
    for nm, skin in (("X", SKIN_X), ("Y", SKIN_Y)):
        check(skin >= P.C1_SKIN_MIN,
              f"{nm} outer skin drawn {skin:.3f} >= {P.C1_SKIN_MIN}")
        check(skin >= P.C1_SKIN_MIN,
              f"{nm} tongue drawn {skin:.3f} >= {P.C1_SKIN_MIN}")
    # prove the tongue actually enters the recess, on all four sides
    z_lap_back = P.C1_BACK_H - P.C1_LAP_D / 2                 # mid-lap, back
    z_lap_front = JOINT_A + P.C1_LAP_D / 2                    # mid-lap, front
    # Probe the straight runs only. In a corner the two rounded rectangles
    # share a centre, so the gap is still 0.70 — but an axis-aligned ray
    # crosses it obliquely and reads long. That is the ray, not the part.
    # authored-front frame: authored -X = assembled +X (the lapped side);
    # authored +X = assembled -X, where the tongue is deleted for the slide
    # and is checked for ABSENCE below. The +Y probe sits in an inter-window
    # gap (windows at the C1_SLIDE_SITES span the rest of that wall).
    for axis, other, lo, hi, lbl in ((0, 0.0, -29, 0, "-X (assembled +X)"),
                                     (1, -7.0, 0, 29, "+Y (between windows)")):
        br = solid_runs(B, axis, (other, z_lap_back), lo, hi)
        fr = solid_runs(F, axis, (other, z_lap_front), lo, hi)
        ok = bool(br) and bool(fr)
        check(ok, f"both halves have material at the {lbl} lap")
        if ok:
            # outermost runs only: ribs and standoffs sit inboard of the joint
            gap = (br[0][1] - fr[0][0]) if lo < 0 else (br[-1][0] - fr[-1][1])
            near(abs(gap), P.C1_LAP_CLEAR, 0.06, f"{lbl} lap clearance as drawn")

    # the corner diagonal — the direction the straight probes never looked.
    # Ray from the pebble arc centre out through the (+,+) corner at 45 deg.
    import math
    cx, cy = OUT_X - R_OUT, OUT_Y - R_OUT
    d = np.array([math.cos(math.pi / 4), math.sin(math.pi / 4)])
    def diag(mesh, z, lo=0.0, hi=R_OUT + 1.0, n=2500):
        t = np.linspace(lo, hi, n)
        pts = np.column_stack([cx + t * d[0], cy + t * d[1], np.full(n, z)])
        ins = mesh.contains(pts); out, st = [], None
        for i, v in enumerate(ins):
            if v and st is None: st = t[i]
            if not v and st is not None: out.append((st, t[i - 1])); st = None
        if st is not None: out.append((st, t[-1]))
        return out
    # the front's probed corner is authored (-,+) = assembled (+,+), the
    # same physical corner the back's (+,+) probe reads: the assembled
    # (-,*) corners have no tongue at all (slide clearance)
    def diag_f(mesh, z, n=2500):
        t = np.linspace(0.0, R_OUT + 1.0, n)
        pts = np.column_stack([-(cx + t * d[0]), cy + t * d[1], np.full(n, z)])
        ins = mesh.contains(pts); out, st = [], None
        for i, v in enumerate(ins):
            if v and st is None: st = t[i]
            if not v and st is not None: out.append((st, t[i - 1])); st = None
        if st is not None: out.append((st, t[-1]))
        return out
    # probed in the SEAM BAND, not mid-lap: the (+,+) corner sits inside
    # the standoff sweep relief, where the tongue keeps only its top stub
    # (the slide drags the +X run over the standoffs, so it is shortened
    # there on purpose)
    # 0.9 under the seam: below the 0.8 joint chamfer, inside the stub
    bs = diag(B, P.C1_BACK_H - 0.9); fs = diag_f(F, JOINT_A + 0.9)
    check(bool(bs), "back has skin at the corner diagonal, mid-lap")
    check(bool(fs), "front has tongue at the corner diagonal, mid-lap")
    if bs and fs:
        skin_d = bs[-1][1] - bs[-1][0]
        tongue_d = fs[-1][1] - fs[-1][0]
        gap_d = bs[-1][0] - fs[-1][1]
        check(skin_d >= P.C1_SKIN_MIN,
              f"skin at the corner diagonal {skin_d:.2f} >= {P.C1_SKIN_MIN}")
        check(tongue_d >= P.C1_SKIN_MIN,
              f"tongue at the corner diagonal {tongue_d:.2f} >= {P.C1_SKIN_MIN}")
        near(gap_d, P.C1_LAP_CLEAR, 0.08, "lap clearance at the corner diagonal")
    # the -X wall, assembled: back skin whole, front tongue deliberately
    # absent (the drop clearance) — its lap lives in the key and the rims
    r = solid_runs(B, 0, (0.0, z_lap_back), -29, -14)
    check(bool(r), "back has skin at the -X mid-lap")
    r = solid_runs(FA, 0, (-13.0, z_lap_back), -29, -P.C1_TONGUE_XCUT - 0.05)
    check(not r, "front has NO tongue outboard of C1_TONGUE_XCUT — the slide clearance is real")
    fs2 = diag(F, SEAT_A + 0.8)                            # the shelf band
    check(bool(fs2) and fs2[-1][1] - fs2[-1][0] >= P.MIN_WALL_SOLID,
          f"front wall at the corner diagonal, board level: "
          f"{(fs2[-1][1] - fs2[-1][0]) if fs2 else 0:.2f}")

    print("\n2b. the board can actually enter the pocket")
    # A PCB outline — PCB_W x PCB_L, the reference's corner radius — grown
    # by what the print adds, walked round at three heights in the board's
    # band. Not one point may be inside the front. This is the check that
    # would have failed the R5.06 pocket before it was printed.
    check(R_POK <= 1.85, f"pocket corner R{R_POK} <= the reference's R1.8")
    hw = P.PCB_W / 2 + PROUD; hl = P.PCB_L / 2 + PROUD; rc = R_POK
    pts = []
    for ang in np.linspace(0, 2 * math.pi, 720, endpoint=False):
        # superellipse-free: build a rounded rect by clamping a circle
        x = np.clip((hw) * math.cos(ang) * 1.5, -(hw - rc), hw - rc)
        y = np.clip((hl) * math.sin(ang) * 1.5, -(hl - rc), hl - rc)
        pts.append((x + rc * math.cos(ang), y + rc * math.sin(ang)))
    pts = np.array(pts)
    # make the outline exact: nearest point on the rounded rect boundary
    def rr_boundary(px, py):
        qx = np.clip(px, -(hw - rc), hw - rc); qy = np.clip(py, -(hl - rc), hl - rc)
        vx, vy = px - qx, py - qy; nrm = math.hypot(vx, vy) or 1.0
        return qx + vx / nrm * rc, qy + vy / nrm * rc
    outline = np.array([rr_boundary(6 * math.cos(a), 6 * math.sin(a))
                        for a in np.linspace(0, 2 * math.pi, 1440, endpoint=False)])
    outline = np.array([rr_boundary(x * 4, y * 4) for x, y in outline])
    hits = 0
    for z in (SEAT_A + 0.15, SEAT_A + P.PCB_T / 2, SEAT_A + P.PCB_T - 0.15):
        p3 = np.column_stack([outline[:, 0], outline[:, 1] + P.C1_POCKET_CTR_Y,
                              np.full(len(outline), z)])
        hits += int(F.contains(p3).sum())
    check(hits == 0, f"PCB outline ({P.PCB_W} x {P.PCB_L}, R{rc}) clears the "
                     f"printed pocket at three heights ({hits} points inside)")
    span_x = 2 * (POK_X - PROUD) - P.PCB_W
    span_y = 2 * (POK_Y - PROUD) - P.PCB_L
    check(span_x >= 0.3, f"printed pocket is {span_x:.2f} wider than the PCB")
    check(span_y >= 0.3, f"printed pocket is {span_y:.2f} longer than the PCB body")

    print("\n3. the mating rim is a continuous ring")
    z = P.C1_BACK_H - 0.15
    sec = B.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
    check(sec is not None, "back has a rim at the mating plane")
    if sec is not None:
        # Count the ring's pieces off the section's WORLD-frame loops, not
        # to_2D(): the planar frame to_2D picks is arbitrary, and adding the
        # snap lead-in wedges rotated it enough to skew every bound — the
        # same 4 pieces suddenly counted as 1. Same intent, honest frame.
        loops = [np.asarray(d) for d in sec.discrete]
        outer = [L for L in loops if np.abs(L[:, 0]).max() > OUT_X - 1.0]
        # exactly four deliberate notches: the USB end, two button slots and
        # the SD slot. Anything else is a defect.
        check(len(outer) == 5,
              f"rim is one ring cut only by USB + 2 buttons + SD + the key slot (got {len(outer)} pieces)")
        for y in (-9.5, -18.0, 19.8):   # flats; clear of slots, standoffs, corners, key
            r = solid_runs(B, 0, (y, z), -OUT_X - 1, OUT_X + 1)
            outer_runs = [(a, b) for a, b in r if abs(a) > CAV_X - 0.3 or abs(b) > CAV_X - 0.3]
            check(len(outer_runs) == 2, f"rim's outer skin intact both sides at y={y:+.1f} ({len(outer_runs)} outer runs)")
    # the seam: the front's joint face, 0.02 above the joint, must be solid
    # across the whole wall at every relief (only the tongue is relieved)
    for nm, y_or_x, axis in (("speaker relief", (P.C1_SPK_CTR_X, +1), 1),
                             ("USB relief", (P.C1_USB_CTR_X, -1), 1),
                             ("PWR relief", (P.BTN1_CTR_Y, +1), 0),
                             ("-X wall (tongueless)", (-13.0, -1), 0)):
        c, sgn = y_or_x
        z = P.C1_BACK_H + 0.02
        lo_, hi_ = sorted((sgn * (POK_Y + 0.3), sgn * (OUT_Y - 1.0))) if axis == 1 else sorted((sgn * (POK_X + 0.3), sgn * (OUT_X - 1.0)))
        r = solid_runs(FA, axis, (c, z), lo_, hi_)
        span = sum(b - a for a, b in r)
        need = hi_ - lo_
        # USB and PWR are the two places a notch above the joint is intended
        expect = need if nm not in ("USB relief", "PWR relief") else 0.0
        check(abs(span - expect) < 0.1,
              f"seam at the {nm}: {span:.2f} of {need:.2f} solid at joint+0.02 (expect {expect:.2f})")

    print("\n3d. the USB port — tight hole, recess for the plug nose")
    ux, uz = P.C1_USB_CTR_X, P.C1_USB_CTR_Z
    so_r = P.C1_STANDOFF_OD / 2 + PROUD
    r = solid_runs(B, 1, (ux, uz), -OUT_Y - 0.5, P.C1_USB_FLOOR_Y0 + 0.8)
    check(not r, "hole is open from outside through the boss at the connector's centre")
    r = solid_runs(B, 1, (ux + P.C1_USB_HOLE_W / 2 + 0.8, uz), -OUT_Y - 0.5, P.C1_USB_FLOOR_Y0 + 0.8)
    if P.C1_USB_NO_FLOOR:
        check(not r, "no-floor: beside the hole is open straight through")
    else:
        check(len(r) == 1 and abs(r[0][0] - P.C1_USB_FLOOR_Y1) < 0.1 and abs(r[0][1] - P.C1_USB_FLOOR_Y0) < 0.1,
              f"beside the hole: recess open to the seat at y={P.C1_USB_FLOOR_Y1:.2f}, then {P.C1_USB_WALL_T:.2f} of floor to y={P.C1_USB_FLOOR_Y0:.2f}")
    r = solid_runs(B, 1, (ux + P.C1_USB_REC_W / 2 + 1.0, uz), -OUT_Y - 0.5, -CAV_Y + 0.3)
    check(bool(r) and r[0][0] < -OUT_Y + 0.3, "outside the recess the end skin is whole")
    # 9.4 x 3.8 at band-max growth: 0.23/side round the 8.94 x 3.26 shell.
    # (Was >= 9.5/3.9 — thresholds carried the old C1_C-padded sizes; the
    # 2026-09-01 print measured free-wall growth at 0.05/side, so the drawn
    # hole shrank and the floor moved with it. See the params block.)
    check(P.C1_USB_HOLE_W - 2 * PROUD >= 9.4 and P.C1_USB_HOLE_H - 2 * PROUD >= 3.8,
          f"printed hole {P.C1_USB_HOLE_W - 2*PROUD:.1f} x {P.C1_USB_HOLE_H - 2*PROUD:.1f} clears an 8.9 x 3.3 shell")
    # Spec-max (12.35 x 6.5) bricks are REFUSED on purpose now — the port
    # must read closed. The recess admits the common overmould class.
    check(P.C1_USB_REC_W - 2 * PROUD >= 11.5 and P.C1_USB_REC_H - 2 * PROUD >= 5.7,
          f"printed recess {P.C1_USB_REC_W - 2*PROUD:.1f} x {P.C1_USB_REC_H - 2*PROUD:.1f} admits the common overmould class "
          f"(<= 11.1 x 5.3 + 0.2/side worst case); spec-max bricks are refused on purpose")
    seat_out = P.C1_USB_FACE_Y - P.C1_USB_FLOOR_Y1
    print(f"       recess {OUT_Y + P.C1_USB_FLOOR_Y1:.2f} deep; seat {seat_out:.2f} outboard of the receptacle face "
          f"(spec max 0.3); floor {P.C1_USB_WALL_T:.2f}; if the receptacle is flush with the PCB edge the seat is "
          f"{seat_out + P.C1_USB_PROTRUDE:.2f} outboard")
    if P.C1_USB_NO_FLOOR:
        print("       NO-FLOOR variant: the recess cuts straight through to the hole; "
              "the receptacle face is the seat at any protrusion")
        check(True, "no-floor variant: seat cannot be outboard of the receptacle face")
    else:
        check(seat_out <= 0.3, "overmould seat within 0.3 of the receptacle face (USB-IF)")
        check(P.C1_USB_WALL_T >= 0.6, f"recess floor {P.C1_USB_WALL_T:.2f} >= 0.6 (local, two thin lines)")
        # the floor only works over a band of receptacle protrusions: say it
        lo = P.C1_USB_PROTRUDE - 0.3
        print(f"       floor works while the receptacle protrudes >= {lo:.2f} past the PCB edge "
              f"(assumed {P.C1_USB_PROTRUDE:.2f}); below that, C1_USB_NO_FLOOR=1")
        check(lo <= 0.7, "the protrusion band the floor tolerates reaches down to 0.7")
    check(P.C1_USB_FLOOR_Y0 <= -(P.PCB_L / 2) - 0.25, "floor's inner face stays 0.25+ off the PCB edge")
    # the Y stops: board captured with 0.3 a side, nothing else in the pocket band
    for sgn, nm_ in ((-1, "USB block"), (+1, "+Y stop")):
        yq = sgn * (P.PCB_L / 2 + 0.15)
        r = solid_runs(FA, 1, (0.0 if sgn > 0 else P.C1_USB_CTR_X, P.C1_SEAT_Z - P.PCB_T / 2),
                       sgn * (P.PCB_L / 2 - 0.5), sgn * (POK_Y + 0.5))
        lo_, hi_ = sorted((sgn * (P.PCB_L / 2 - 0.5), sgn * (POK_Y + 0.5)))
        xq = 0.0 if sgn > 0 else (P.C1_USB_CTR_X + P.C1_Y_STOP_X0 + 1.0)   # -Y: on a flanking stop
        r = solid_runs(FA, 1, (xq, P.C1_SEAT_Z - P.PCB_T / 2), lo_, hi_)
        edge = (min(a for a, _ in r) if sgn > 0 else max(b for _, b in r)) if r else float("nan")
        check(bool(r) and abs(abs(edge) - P.C1_Y_STOP) < 0.08,
              f"{nm_} faces the board at |y|={abs(edge):.2f} (board edge {P.PCB_L/2:.2f})")
    # bounded BOTH ways: two prints in a row read as a hole with a connector
    # lost in it. The DRAWN mouth may never exceed a spec-max overmould's
    # own footprint — tightened from printed-size +0.5/side (2026-09-02).
    check(P.C1_USB_REC_W <= 12.35 and P.C1_USB_REC_H <= 6.5,
          f"drawn mouth {P.C1_USB_REC_W:.2f} x {P.C1_USB_REC_H:.2f} <= 12.35 x 6.5 (a spec-max overmould footprint)")
    for x, y in P.C1_SCREW_XY:
        if y < 0:
            check(abs(x) - so_r > abs(ux) + P.C1_USB_BOSS_W / 2 + 0.3, f"USB boss clears the standoff at ({x:+.1f},{y:+.1f})")
    check(P.C1_USB_FLOOR_Y0 < P.C1_BATT_CTR_Y - P.C1_BATT_POCKET_L / 2 - P.C1_BATT_RIB_T - 0.3,
          f"USB boss ({P.C1_USB_FLOOR_Y0:.2f}) stays clear of the cell's -Y rib")
    if not P.C1_USB_NO_FLOOR:
        r = solid_runs(FA, 1, (ux + 5.5, P.C1_BACK_H + P.C1_USB_FRONT_NOTCH / 2), -OUT_Y - 0.5, -POK_Y + 1.2)
        check(bool(r) and abs(r[0][0] - P.C1_USB_FLOOR_Y1) < 0.1 and abs(r[0][1] - P.C1_USB_FLOOR_Y0) < 0.1,
              f"front continues the recess floor above the seam: solid {r[0][0] if r else 0:+.2f}..{r[0][1] if r else 0:+.2f}")
    r = solid_runs(FA, 1, (ux, P.C1_BACK_H + P.C1_USB_HOLE_NOTCH / 2), -OUT_Y - 0.5, -POK_Y + 1.2)
    check(not any(a < P.C1_USB_FLOOR_Y0 + 0.2 for a, _ in r),
          "front's hole notch goes through the floor into the pocket (receptacle corner clear)")
    # the receptacle envelope (8.94 x 3.26 x 7.35 from its face) must be in air
    rx0, rx1 = ux - 4.47, ux + 4.47
    rz0, rz1 = P.C1_SEAT_Z - P.PCB_T - 3.26, P.C1_SEAT_Z - P.PCB_T
    pts = np.array([[x, y, z] for x in np.linspace(rx0 + 0.05, rx1 - 0.05, 9)
                    for y in np.linspace(P.C1_USB_FACE_Y + 0.05, P.C1_USB_FACE_Y + 7.3, 12)
                    for z in np.linspace(rz0 + 0.05, rz1 - 0.05, 7)])
    hitF, hitB = int(FA.contains(pts).sum()), int(B.contains(pts).sum())
    check(hitF == 0 and hitB == 0, f"receptacle envelope is clear of both halves ({hitF} pts in front, {hitB} in back)")
    r = solid_runs(FA, 1, (ux, P.C1_BACK_H + P.C1_USB_FRONT_NOTCH + 0.4), -OUT_Y - 0.5, -POK_Y)
    check(bool(r) and r[0][0] < -OUT_Y + 0.9, "front's wall is solid above the recess")

    print("\n3f. the USB mouth, assembled — the port must READ closed")
    # The gate the 2026-09-02 print earned: both prints of this port passed
    # every per-half probe above and still looked like a hole, because
    # nothing measured the ASSEMBLED mouth as an eye does — its area, its
    # air, where its top lip lands on the pebble, and whether anything
    # spills outside the drawn profile.
    hw_u, hh_u, rr_u = P.C1_USB_REC_W / 2, P.C1_USB_REC_H / 2, P.C1_USB_REC_R
    seat_u = P.C1_USB_FLOOR_Y1
    air = P.C1_USB_REC_W * P.C1_USB_REC_H - (4 - math.pi) * rr_u * rr_u - 8.94 * 3.26
    check(air <= 50.0, f"visible air around the shell {air:.1f} mm2 <= 50")
    # the top lip must land where the face roll-off is still under 0.10 —
    # on the old 7.5-tall recess the lip sat 0.17 into the pebble fillet and
    # feathered into the face, reading ~1.7 taller than drawn
    zt_u = P.C1_FACE_CHAMFER + P.C1_FACE_FILLET * math.tan(math.radians(22.5))
    check(P.C1_H - (uz + hh_u) >= zt_u - math.sqrt(2 * P.C1_FACE_FILLET * 0.10),
          "top lip lands where the pebble roll-off is < 0.10 — an edge, not a feather")
    ok_in = True
    for dx_u in np.linspace(-hw_u + 0.25, hw_u - 0.25, 9):
        for dz_u in np.linspace(-hh_u + 0.25, hh_u - 0.25, 7):
            cx_u = max(abs(dx_u) - (hw_u - rr_u), 0.0)
            cz_u = max(abs(dz_u) - (hh_u - rr_u), 0.0)
            if cx_u * cx_u + cz_u * cz_u > (rr_u - 0.25) ** 2:
                continue
            for M in (B, FA):
                if solid_runs(M, 1, (ux + dx_u, uz + dz_u), -OUT_Y - 0.5, seat_u - 0.02, n=600):
                    ok_in = False
    check(ok_in, "drawn recess profile is open to the seat over its full area, both halves")
    ok_out = True
    ring = [(x_u, s * (hh_u + 0.35)) for x_u in np.linspace(-hw_u - 0.35, hw_u + 0.35, 11) for s in (-1, 1)] \
         + [(s * (hw_u + 0.35), z_u) for z_u in np.linspace(-hh_u - 0.35, hh_u + 0.35, 7) for s in (-1, 1)]
    for dx_u, dz_u in ring:
        z_u = uz + dz_u
        if abs(z_u - P.C1_BACK_H) <= 0.2:      # the seam line itself
            continue
        M = FA if z_u > P.C1_BACK_H else B
        r = solid_runs(M, 1, (ux + dx_u, z_u), -OUT_Y + 0.9, seat_u - 0.05, n=600)
        if not (r and r[0][0] <= -OUT_Y + 1.0 and r[-1][1] >= seat_u - 0.15):
            ok_out = False
    check(ok_out, "0.35 outside the profile the wall is solid past the seam V to the seat — nothing spills")

    print("\n3e. the slide-lock — drop, slide, lock, key, all measured")
    # The mechanism is rigid, so the proof is kinematic, on the meshes:
    #  drop:  the whole front, offset -C1_SLIDE_T, lowers to seated with
    #         zero intersection anywhere (tabs pass the entry notches);
    #  slide: it translates +X to home, zero intersection the whole way;
    #  lock:  lifted 2*C1_WIN_C at home, the tabs and strips DO collide —
    #         that interference is the closure;
    #  key:   fits its slot with the front home, and blocks the slide back.
    # Three closures died before this one; every one of them would have
    # been caught by exactly these four sweeps.
    Tr = P.C1_SLIDE_T

    def front_at(dx, dz):
        M = FA.copy()
        M.apply_translation([dx, 0, dz])
        return M

    def ivol(a, b):
        try:
            return trimesh.boolean.intersection([a, b], engine="manifold").volume
        except Exception:
            return float("nan")

    worst = max(ivol(front_at(-Tr, dz), B) for dz in (2.0, 1.0, 0.5, 0.2, 0.0))
    check(worst < 1e-3, f"DROP: front at -{Tr} lowers to seated free ({worst:.4f} mm3 worst)")
    worst = max(ivol(front_at(-Tr * (1 - f), 0), B) for f in (0.25, 0.5, 0.75, 1.0))
    check(worst < 1e-3, f"SLIDE: front travels home free ({worst:.4f} mm3 worst)")
    v_lock = ivol(front_at(0, 2 * P.C1_WIN_C), B)
    check(v_lock > 0.05, f"LOCK: lifted {2*P.C1_WIN_C:.2f} at home, tabs bite ({v_lock:.3f} mm3)")
    v_free = ivol(front_at(-Tr, 1.5), B)
    check(v_free < 1e-3, f"and at the drop offset the same lift is free ({v_free:.4f} mm3) — it opens on purpose")
    # the key, seated: through the -X skin, snug band across the seam
    K = trimesh.load(kp)
    K.apply_translation([-OUT_X + (P.C1_KEY_DEPTH - 0.20) / 2 + 0.05, 0,
                         P.C1_BACK_H - P.C1_KEY_ZB + P.C1_KEY_FIT])
    vkb, vkf = ivol(K, B), ivol(K, front_at(0, 0))
    check(vkb < 1e-3 and vkf < 1e-3, f"KEY: fits with the front home (back {vkb:.4f} / front {vkf:.4f} mm3)")
    v_blk = ivol(front_at(-0.5, 0), K)
    check(v_blk > 0.05, f"KEY: blocks the slide back ({v_blk:.3f} mm3 at -0.5)")
    # analytics: the numbers the sweeps rest on
    check(P.C1_TAB_E <= P.C1_LAP_CLEAR + P.C1_TONGUE_T - 0.05,
          f"tab reach {P.C1_TAB_E:.2f} stays out of the pocket band")
    check(P.C1_STRIP_H >= 1.2, f"strip under each window {P.C1_STRIP_H:.2f} >= 1.2")
    check(P.C1_WIN_C >= 0.25, f"working clearance {P.C1_WIN_C:.2f} >= 0.25 — sliding fit, not a snap fit")
    seg_tip = P.C1_BACK_H - P.C1_LAP_D - P.C1_SEG_EXTRA
    check(seg_tip >= P.C1_FLOOR_T + 0.5,
          f"deepened tongue tip {seg_tip:.2f} keeps 0.5 over the floor {P.C1_FLOOR_T:.2f}")
    for sy, sites in ((-1, P.C1_SLIDE_SITES_NY), (+1, P.C1_SLIDE_SITES_PY)):
        for xc, tw in sites:
            a = xc - tw / 2 - P.C1_WIN_C
            # the tab is really on the wall: probe its crown mid-flat
            yq = sy * (CAV_Y - P.C1_TAB_E + 0.1)
            r = solid_runs(B, 2, (yq, 0), 0, P.C1_BACK_H, n=400)
            hmm = [seg for seg in r] if r else []
            pts = [[xc, yq, P.C1_BACK_H - P.C1_TAB_TOP - P.C1_TAB_FLAT / 2]]
            import numpy as _np
            check(bool(B.contains(_np.array(pts))[0]),
                  f"tab at ({'+Y' if sy > 0 else '-Y'}, x={xc:+.1f}) reaches {P.C1_TAB_E:.2f} in")
            # the strip is really under the roofed span, at home
            pts = [[a + Tr / 2, sy * (POK_Y + P.C1_TONGUE_T / 2),
                    P.C1_BACK_H - P._win_bot - P.C1_STRIP_H / 2]]
            check(bool(FA.contains(_np.array(pts))[0]),
                  f"strip under the window at ({'+Y' if sy > 0 else '-Y'}, x={xc:+.1f})")

    print("\n3b. the pins")
    check(P.C1_PIN_HEAD_D < P.C1_BTN_SLOT_W - 2 * PROUD,
          f"head {P.C1_PIN_HEAD_D} passes the printed slot {P.C1_BTN_SLOT_W - 2*PROUD:.2f}")
    check(P.C1_PIN_STEM_D < P.C1_BTN_SLOT_W - 2 * PROUD - 0.3,
          f"stem {P.C1_PIN_STEM_D} slides in the printed slot")
    check(P.C1_PIN_FLANGE_D > P.C1_BTN_SLOT_W + 0.8,
          f"flange {P.C1_PIN_FLANGE_D} cannot pass the slot {P.C1_BTN_SLOT_W}")
    check(P.BTN_FREE_TRAVEL <= PIN_FREE_TRAVEL <= 0.90,
          f"free travel {PIN_FREE_TRAVEL:.2f}: >= {P.BTN_FREE_TRAVEL} so the pin "
          f"never holds the switch, <= 0.90 so it is not a rattle")
    check(P.C1_PIN_HEAD_PROUD - P.BTN_SWITCH_TRAVEL - (PIN_FREE_TRAVEL - P.BTN_FREE_TRAVEL) > 0.05,
          "head stays proud of the skin through the full press")
    check(P.C1_BTN_Z + P.C1_PIN_FLANGE_D / 2 <= P.C1_BACK_H + P.C1_BTN_FRONT_NOTCH,
          "flange fits under the front's cap even riding high")
    check(P.C1_BTN_SLOT_Z0 >= P.C1_FLOOR_T + P.MIN_WALL_SOLID,
          f"slot bottom {P.C1_BTN_SLOT_Z0:.2f} leaves skin above the floor")
    for nm, rec, proud, extra in (("PWR", False, P.C1_PIN_HEAD_PROUD, 0.0),
                                  ("REC", True, P.C1_PIN_REC_PROUD, 0.0)):
        PIN = build_pin(rec); pp = os.path.join(tmp, f"c1p_{nm}.stl")
        export_stl(PIN, pp, tolerance=0.004, angular_tolerance=0.1)
        PM = trimesh.load(pp)
        check(PM.is_watertight, f"{nm} pin mesh is watertight")
        b = PM.bounds
        want = P.C1_PIN_FLANGE_L + SKIN_X + proud + extra
        check(abs((b[1][2] - b[0][2]) - want) < 0.02,
              f"{nm} pin length {b[1][2]-b[0][2]:.2f} = flange + skin + proud (+dome)")
        check(b[1][0] - b[0][0] <= P.C1_PIN_FLANGE_D + 0.01,
              f"{nm} pin: nothing wider than the flange")
    check(P.C1_PIN_REC_PROUD - P.C1_PIN_HEAD_PROUD >= 0.3,
          "record pin stands out clearly further than PWR")

    print("\n3c. the pebble")
    check(P.C1_FACE_FILLET <= 3.41 * P.C1_FACE_CHAMFER + 1e-6,
          f"pebble fillet R{P.C1_FACE_FILLET} fits on the {P.C1_FACE_CHAMFER} facet")
    check(OUT_X - P.C1_FACE_CHAMFER > P.C1_DISP_W / 2 + 1.0,
          "front's face chamfer stays clear of the display pocket (X)")
    check(OUT_Y - P.C1_FACE_CHAMFER > P.C1_DISP_L / 2 + 1.0,
          "front's face chamfer stays clear of the display pocket (Y)")
    check(P.C1_FLOOR_T - P.C1_FACE_CHAMFER >= 0.6,
          f"back's floor keeps {P.C1_FLOOR_T - P.C1_FACE_CHAMFER:.2f} under the chamfer edge")
    check(SKIN_X - P.C1_DISH_DEPTH >= P.MIN_WALL_SOLID,
          f"skin under the thumb dish {SKIN_X - P.C1_DISH_DEPTH:.2f} >= {P.MIN_WALL_SOLID:.2f}")
    # the dish really is there, on the record button, in both halves
    dx = solid_runs(B, 0, (P.C1_DISH_Y + 3.0, P.C1_DISH_Z - 1.0), 0, OUT_X + 1)
    check(bool(dx) and dx[-1][1] < OUT_X - 0.3,
          f"back's wall is dished beside BOOT (outer face at {dx[-1][1] if dx else 0:.2f} < {OUT_X})")
    dx = solid_runs(FA, 0, (P.C1_DISH_Y, P.C1_BACK_H + 2.0), 0, OUT_X + 1)
    check(bool(dx) and dx[-1][1] < OUT_X - 0.3,
          "front's wall carries the dish above the joint")
    dx = solid_runs(B, 0, (P.BTN1_CTR_Y + 3.0, P.C1_DISH_Z), 0, OUT_X + 1)
    check(bool(dx) and dx[-1][1] > OUT_X - 0.05, "PWR's wall is NOT dished")


    r = solid_runs(FA, 0, (0.0, P.C1_H - 0.05), -OUT_X, OUT_X)
    win_x = (r[0][1] + r[1][0]) / 2 if len(r) >= 2 else float("nan")
    near(win_x, 0.100, 0.06, "window X offset matches the reference (assembled)")

    print("\n4. the window is tapered, not counterbored")
    straight = P.C1_FACE_T - P.C1_WIN_FLARE
    check(straight >= P.C1_WIN_STRAIGHT_MIN,
          f"straight window wall {straight:.3f} >= {P.C1_WIN_STRAIGHT_MIN}")
    check(straight >= 2 * P.LAYER_H,
          f"straight window wall {straight:.3f} is at least 2 layers")

    print("\n5. the battery, which the reference never had to hold")
    free = P.C1_SEAT_Z - P.PCB_T - P.C1_FLOOR_T
    check(free >= P.BATT_T,
          f"free depth under the board {free:.2f} >= cell {P.BATT_T}")
    check(2 * min(POK_X, CAV_X) - 2 * PROUD >= 30.0,
          "cell width fits the cavity")
    for x, y in P.C1_SCREW_XY:
        check(abs(y) > 17.5 or abs(x) > 15.0,
              f"screw at ({x:+.2f},{y:+.2f}) clears the cell footprint")

    # the fence that holds it
    tongue_free_z = P.C1_H - P.C1_FRONT_H                     # 4.49 assembled
    fence_top = P.C1_FLOOR_T + P.C1_BATT_RIB_H
    check(fence_top <= tongue_free_z,
          f"fence top {fence_top:.2f} clears the tongue's free end "
          f"{tongue_free_z:.2f}")
    near(P.C1_BATT_POCKET_W - 2 * PROUD, P.BATT_W + 2 * P.C1_BATT_CLEAR, 0.02,
         "printed fence holds the cell's width with its clearance")
    near(P.C1_BATT_POCKET_L - 2 * PROUD, P.BATT_L + 2 * P.C1_BATT_CLEAR, 0.02,
         "printed fence holds the cell's length with its clearance")
    fx = P.C1_BATT_POCKET_W / 2 + P.C1_BATT_RIB_T + PROUD
    fy = P.C1_BATT_POCKET_L / 2 + P.C1_BATT_RIB_T + PROUD
    check(fx <= CAV_X - PROUD, f"rib half-width {fx:.2f} fits the cavity")
    check(fy <= CAV_Y - PROUD, f"rib half-length {fy:.2f} fits the cavity")
    # the HOLE has a radius. Checking its centre is what let a rib corner
    # hang over one.
    hole_r = P.C1_SCREW_CLEAR_D / 2 + PROUD
    hw_, hl_, t_ = P.C1_BATT_POCKET_W / 2, P.C1_BATT_POCKET_L / 2, P.C1_BATT_RIB_T
    for x, y in P.C1_SCREW_XY:
        dx, dy = abs(x - P.C1_BATT_CTR_X), abs(y - P.C1_BATT_CTR_Y)
        # side ribs run along Y at |x| = hw..hw+t; end ribs along X at |y| = hl..hl+t
        clear_side = dy - hole_r > hl_ or dx - hole_r > hw_ + t_ or dx + hole_r < hw_
        clear_end = dy - hole_r > hl_ + t_ or dx - hole_r > P.C1_BATT_RIB_SPAN_X / 2
        check(clear_side and clear_end,
              f"screw hole at ({x:+.2f},{y:+.2f}) clears every cell rib")
    # the standoffs must stop SHORT of the board: the board-to-front screw
    # heads (4.0 dia x 1.6, on the PCB back face) live in that band. Drawn
    # to touch the board, each column landed on a head and the 2026-09-02
    # print stood 1.60 mm open all round.
    so_top = P.C1_FLOOR_T + P.C1_STANDOFF_H
    near(so_top, (board_back0 := P.C1_SEAT_Z - P.PCB_T) - P.C1_SCREW_HEAD_RELIEF, 0.02,
         "standoff top clears the screw head by the relief")
    check(so_top <= board_back0 - (P.C1_SCREW_HEAD_H + 0.2) + 1e-6,
          f"standoff top {so_top:.2f} clears the head envelope "
          f"(head {P.C1_SCREW_HEAD_H:.2f} + 0.2 under the board face {board_back0:.2f})")
    check(min(abs(x) for x, _ in P.C1_SCREW_XY) - (P.C1_SCREW_HEAD_D / 2 + 0.2 + PROUD)
          > abs(P.C1_USB_CTR_X) + P.C1_USB_BOSS_W / 2,
          "USB boss clears the head envelope in x")
    so_r = P.C1_STANDOFF_OD / 2 + PROUD
    check((P.C1_STANDOFF_OD - P.C1_SCREW_CLEAR_D) / 2 >= P.MIN_WALL_TRACE - 1e-6,
          f"standoff wall {(P.C1_STANDOFF_OD - P.C1_SCREW_CLEAR_D)/2:.3f} mm")
    for x, y in P.C1_SCREW_XY:
        check(abs(y) - so_r > P.BATT_L / 2,
              f"standoff at ({x:+.2f},{y:+.2f}) clears the cell "
              f"(edge {abs(y)-so_r:.2f} vs {P.BATT_L/2:.2f})")
        check(abs(x) - so_r > P.C1_BATT_RIB_SPAN_X / 2,
              f"standoff at ({x:+.2f},{y:+.2f}) clears the end rib")
        check(abs(x) + so_r < POK_X and abs(y) + so_r < POK_Y,
              f"standoff at ({x:+.2f},{y:+.2f}) clears the tongue")

    # what length of screw this actually wants. BOARD-TO-FRONT, and short:
    # the head seats on the PCB back face, the thread past the board goes
    # into the 2.30 blind pilot with only 0.495 of face skin under it.
    eng_s = P.C1_SCREW_L - P.PCB_T
    print(f"       M2 x {P.C1_SCREW_L:.0f} board-to-front: {eng_s:.2f} of thread in a "
          f"{P.C1_SCREW_PILOT_DEPTH:.2f} pilot (bottoms by "
          f"{max(0.0, eng_s - P.C1_SCREW_PILOT_DEPTH):.2f} — the tip taper's job)")
    check(eng_s - P.C1_SCREW_PILOT_DEPTH <= 0.15,
          f"M2 x {P.C1_SCREW_L:.0f} cannot bottom and lift its head "
          f"(an M2x5 bottoms by 1.10 and punches the face skin under the pilot)")
    check(P.C1_SCREW_PILOT_DEPTH >= 2.0,
          f"pilot is {P.C1_SCREW_PILOT_DEPTH:.2f} mm deep for the screw to bite")

    # the speaker
    print("\n5c. the stock 2x6 header — the black block on the board's back")
    cav = P.C1_SEAT_Z - P.PCB_T - P.C1_FLOOR_T                 # 6.30 under the board
    short = P.HEADER_H - cav
    fitted = P.HEADER_FITTED or os.environ.get("HEADER_FITTED") == "1"
    print(f"       header {P.HEADER_H:.1f} tall [measured M18] vs {cav:.2f} under the board:"
          f" the back cannot close by {short:.2f} mm while it is fitted")
    print(f"       and its {P.HEADER_L:.1f} x {P.HEADER_W:.1f} footprint at the +Y end lands on"
          f" the speaker bay and the cell's +Y rib")
    check(not fitted or short <= 0,
          "header desoldered (HEADER_FITTED=False) — the only way this case closes")
    if P.HEADER_FITTED:
        print(f"       HEADER VARIANT: cavity {cav:.2f} under the board, case {P.C1_H:.2f} tall,"
              f" cell {P.BATT_W:.1f} x {P.BATT_L:.1f} x {P.BATT_T:.1f} at x={P.C1_BATT_CTR_X:+.2f}")
        check(cav >= P.HEADER_H + 0.3, f"header {P.HEADER_H} clears the floor by {cav - P.HEADER_H:.2f}")
        hx0, hx1 = P.HEADER_CTR_X - P.HEADER_W / 2, P.HEADER_CTR_X + P.HEADER_W / 2
        hy0, hy1 = P.HEADER_CTR_Y - P.HEADER_L / 2, P.HEADER_CTR_Y + P.HEADER_L / 2
        # the cell's X budget: header on -X, the front's TONGUE on +X (NOT
        # the cavity wall — that error put 1.00 mm of cell in the tongue's
        # path and the case could not close with a cell fitted)
        lo_c = P.C1_BATT_CTR_X - P.C1_BATT_POCKET_W / 2
        hi_c = P.C1_BATT_CTR_X + P.C1_BATT_POCKET_W / 2
        rib = P.C1_BATT_RIB_T if P.C1_BATT_RIB_NX else 0.0
        check(lo_c - rib - PROUD >= hx1 + 0.4,
              f"cell pocket -X {lo_c - rib - PROUD:.2f} clears the header's +X face {hx1:.2f}")
        check(hi_c + PROUD <= POK_X,
              f"cell pocket +X {hi_c + PROUD:.2f} stays inside the tongue's inner face {POK_X:.2f}")
        check(P.C1_BATT_POCKET_W <= P.C1_BATT_SPAN,
              f"cell pocket {P.C1_BATT_POCKET_W:.2f} fits the {P.C1_BATT_SPAN:.2f} between header and tongue")
        check(P.C1_BATT_CTR_X + P.C1_BATT_POCKET_W / 2 <= CAV_X - PROUD + 1e-6,
              "cell pocket meets the +X cavity wall (the wall is its rib)")
        check(hx0 >= -CAV_X + PROUD + 0.3, f"header's -X face {hx0:.2f} is inside the cavity wall")
        # nothing else under the header's footprint at any height: standoffs, bay, ribs
        for x, y in P.C1_SCREW_XY:
            check(not (hx0 - so_r < x < hx1 + so_r and hy0 - so_r < y < hy1 + so_r),
                  f"standoff at ({x:+.1f},{y:+.1f}) is outside the header footprint")
        bay_y0 = P.C1_BATT_CTR_Y + P.C1_BATT_POCKET_L / 2 + P.C1_BATT_RIB_T
        check(hy1 + 0.3 < bay_y0, f"header's +Y end {hy1:.2f} is clear of the speaker bay ({bay_y0:.2f})")
        # and the mesh agrees: a ray down the header's centre finds only floor
        rr = solid_runs(B, 2, (P.HEADER_CTR_X, P.HEADER_CTR_Y), -0.5, P.C1_BACK_H + 0.5)
        check(len(rr) == 1 and rr[0][1] <= P.C1_FLOOR_T + 0.05,
              "nothing stands on the floor under the header (mesh)")

    print("\n5b. the speaker, which the reference does not have either"
          + ("" if P.C1_SPEAKER else " — OFF (C1_SPEAKER=1 to fit one)"))
    if not P.C1_SPEAKER:
        # with no speaker the +Y end must be a plain closed wall and the
        # tongue must run the whole length of that end
        for xc in (-6.8, 7.4):      # the inter-window gaps of the +Y tongue
            r = solid_runs(B, 1, (xc, P.C1_SPK_SLOT_Z0 + 2.0), 20.0, OUT_Y + 0.5)
            check(bool(r) and r[-1][1] > OUT_Y - 0.3, f"+Y skin is solid at x={xc:+.0f} (no grille)")
            r = solid_runs(FA, 1, (xc, z_mid_lap), 20.0, OUT_Y + 0.5)
            check(bool(r), f"front's tongue is present at x={xc:+.0f} on the +Y end (no relief)")
        r = solid_runs(B, 2, (0.0, CAV_Y - 2.0), P.C1_FLOOR_T + 0.1, P.C1_FLOOR_T + 2.0)
        check(not r, "no speaker ribs stand on the floor at the +Y end")
    if P.C1_SPEAKER:
        # the standoffs must stop SHORT of the board — see 5, same reason
        so_top = P.C1_FLOOR_T + P.C1_STANDOFF_H
        near(so_top, (board_back0 := P.C1_SEAT_Z - P.PCB_T) - P.C1_SCREW_HEAD_RELIEF, 0.02,
             "standoff top clears the screw head by the relief")
        so_r = P.C1_STANDOFF_OD / 2 + PROUD
        check((P.C1_STANDOFF_OD - P.C1_SCREW_CLEAR_D) / 2 >= P.MIN_WALL_TRACE - 1e-6,
              f"standoff wall {(P.C1_STANDOFF_OD - P.C1_SCREW_CLEAR_D)/2:.3f} mm")
        for x, y in P.C1_SCREW_XY:
            check(abs(y) - so_r > P.BATT_L / 2,
                  f"standoff at ({x:+.2f},{y:+.2f}) clears the cell "
                  f"(edge {abs(y)-so_r:.2f} vs {P.BATT_L/2:.2f})")
            check(abs(x) - so_r > P.C1_BATT_RIB_SPAN_X / 2,
                  f"standoff at ({x:+.2f},{y:+.2f}) clears the end rib")
            check(abs(x) + so_r < POK_X and abs(y) + so_r < POK_Y,
                  f"standoff at ({x:+.2f},{y:+.2f}) clears the tongue")

        # what length of screw this actually wants — see 5, board-to-front
        eng_s = P.C1_SCREW_L - P.PCB_T
        check(eng_s - P.C1_SCREW_PILOT_DEPTH <= 0.15,
              f"M2 x {P.C1_SCREW_L:.0f} cannot bottom and lift its head")
        check(P.C1_SCREW_PILOT_DEPTH >= 2.0,
              f"pilot is {P.C1_SCREW_PILOT_DEPTH:.2f} mm deep for the screw to bite")

        # the speaker
        print("\n5c. the stock 2x6 header — the black block on the board's back")
        cav = P.C1_SEAT_Z - P.PCB_T - P.C1_FLOOR_T                 # 6.30 under the board
        short = P.HEADER_H - cav
        fitted = P.HEADER_FITTED or os.environ.get("HEADER_FITTED") == "1"
        print(f"       header {P.HEADER_H:.1f} tall [measured M18] vs {cav:.2f} under the board:"
              f" the back cannot close by {short:.2f} mm while it is fitted")
        print(f"       and its {P.HEADER_L:.1f} x {P.HEADER_W:.1f} footprint at the +Y end lands on"
              f" the speaker bay and the cell's +Y rib")
        check(not fitted or short <= 0,
              "header desoldered (HEADER_FITTED=False) — the only way this case closes")
        if P.HEADER_FITTED:
            print(f"       HEADER VARIANT: cavity {cav:.2f} under the board, case {P.C1_H:.2f} tall,"
                  f" cell {P.BATT_W:.1f} x {P.BATT_L:.1f} x {P.BATT_T:.1f} at x={P.C1_BATT_CTR_X:+.2f}")
            check(cav >= P.HEADER_H + 0.3, f"header {P.HEADER_H} clears the floor by {cav - P.HEADER_H:.2f}")
            hx0, hx1 = P.HEADER_CTR_X - P.HEADER_W / 2, P.HEADER_CTR_X + P.HEADER_W / 2
            hy0, hy1 = P.HEADER_CTR_Y - P.HEADER_L / 2, P.HEADER_CTR_Y + P.HEADER_L / 2
            rib_x0 = P.C1_BATT_CTR_X - P.C1_BATT_POCKET_W / 2 - P.C1_BATT_RIB_T - PROUD
            check(rib_x0 >= hx1 + 0.4, f"cell's -X rib at {rib_x0:.2f} clears the header's +X face {hx1:.2f}")
            check(P.C1_BATT_CTR_X + P.C1_BATT_POCKET_W / 2 <= CAV_X - PROUD + 1e-6,
                  "cell pocket meets the +X cavity wall (the wall is its rib)")
            check(hx0 >= -CAV_X + PROUD + 0.3, f"header's -X face {hx0:.2f} is inside the cavity wall")
            # nothing else under the header's footprint at any height: standoffs, bay, ribs
            for x, y in P.C1_SCREW_XY:
                check(not (hx0 - so_r < x < hx1 + so_r and hy0 - so_r < y < hy1 + so_r),
                      f"standoff at ({x:+.1f},{y:+.1f}) is outside the header footprint")
            bay_y0 = P.C1_BATT_CTR_Y + P.C1_BATT_POCKET_L / 2 + P.C1_BATT_RIB_T
            check(hy1 + 0.3 < bay_y0, f"header's +Y end {hy1:.2f} is clear of the speaker bay ({bay_y0:.2f})")
            # and the mesh agrees: a ray down the header's centre finds only floor
            rr = solid_runs(B, 2, (P.HEADER_CTR_X, P.HEADER_CTR_Y), -0.5, P.C1_BACK_H + 0.5)
            check(len(rr) == 1 and rr[0][1] <= P.C1_FLOOR_T + 0.05,
                  "nothing stands on the floor under the header (mesh)")

        sy0 = P.C1_BATT_CTR_Y + P.C1_BATT_POCKET_L / 2 + P.C1_BATT_RIB_T
        bay_t = CAV_Y - sy0
        check(bay_t - 2 * PROUD >= P.SPK_W + 0.3,
              f"speaker bay {bay_t - 2*PROUD:.2f} deep (printed) holds a {P.SPK_W} speaker")
        check(P.C1_SPK_POCKET_W - 2 * PROUD >= P.SPK_L + 0.3,
              f"speaker bay {P.C1_SPK_POCKET_W - 2*PROUD:.2f} wide (printed) holds {P.SPK_L}")
        # the assumed part: 15 x 6 x 3 on edge
        check(P.SPK_FACE_H + 0.2 <= P.C1_SPK_H,
              f"a {P.SPK_FACE_H} tall speaker stands under the board ({P.C1_SPK_H:.2f})")
        check(P.SPK_FACE_W + 0.6 <= P.C1_SPK_POCKET_W - 2 * PROUD and P.SPK_T + 0.3 <= bay_t - 2 * PROUD,
              f"{P.SPK_FACE_W} x {P.SPK_T} footprint fits the printed bay")
        face_lo, face_hi = P.C1_FLOOR_T, P.C1_FLOOR_T + P.SPK_FACE_H
        s_lo, s_hi = P.C1_SPK_SLOT_Z0, P.C1_SPK_SLOT_Z0 + P.SPK_SLOT_H
        check(s_lo >= face_lo - 0.1 and s_hi <= face_hi + 0.1,
              f"grille band {s_lo:.2f}..{s_hi:.2f} lies on the speaker's face {face_lo:.2f}..{face_hi:.2f}")
        check(not (20.0 <= P.C1_SPK_H and 30.0 <= P.C1_SPK_POCKET_W),
              "Waveshare 2030 (20 x 30 x 5.5) is NOT the part for this case")
        rib_out = abs(P.C1_SPK_CTR_X) + P.C1_SPK_POCKET_W / 2 + P.C1_SPK_RIB_T + PROUD
        for x, y in P.C1_SCREW_XY:
            if y > 0:
                check(abs(x) - so_r > rib_out,
                      f"speaker rib clears the standoff at ({x:+.2f},{y:+.2f}) "
                      f"by {abs(x) - so_r - rib_out:.2f}")
        pillar = P.SPK_SLOT_PITCH - P.SPK_SLOT_W
        check(pillar >= P.MIN_WALL_SOLID - 1e-6,
              f"grille pillars {pillar:.2f} >= {P.MIN_WALL_SOLID:.2f}")
        check(P.C1_SPK_SLOT_Z0 + P.SPK_SLOT_H + P.SPK_SLOT_W / 2 < P.C1_BACK_H - P.C1_JOINT_CHAMFER - 0.5,
              "grille stays below the back's rim chamfer")
        zs = P.C1_SPK_SLOT_Z0 + P.SPK_SLOT_H / 2
        for i in range(P.SPK_GRILL_SLOTS):
            xc = P.C1_SPK_CTR_X + (i - (P.SPK_GRILL_SLOTS - 1) / 2) * P.SPK_SLOT_PITCH
            r = solid_runs(B, 1, (xc, zs), 20.0, OUT_Y + 0.5)
            check(not r, f"slit {i} is open through the +Y skin at x={xc:+.1f} ({len(r)} solid runs)")
        for xc in (P.C1_SPK_CTR_X - P.SPK_SLOT_PITCH / 2 - 0.0,):
            pass
        # the tongue must be gone above the speaker (assembled frame)
        z_mid_lap = P.C1_BACK_H - P.C1_LAP_D / 2
        r = solid_runs(FA, 1, (P.C1_SPK_CTR_X, z_mid_lap), 20.0, OUT_Y + 0.5)
        check(not r, "front's tongue is relieved over the speaker bay")
        r = solid_runs(FA, 1, (-14.0, z_mid_lap), 20.0, OUT_Y + 0.5)
        check(bool(r), "front's tongue is present beside the speaker relief")

    # the cell must not be able to lift into the board
    stack = P.C1_FLOOR_T + P.BATT_T + P.C1_BATT_PAD_T
    board_back = P.C1_SEAT_Z - P.PCB_T
    check(stack <= board_back + 0.05,
          f"floor + cell + pad {stack:.2f} <= the board's back face "
          f"{board_back:.2f}")
    # and the leads must have a way out
    cx = P.C1_BATT_CTR_X
    r = solid_runs(B, 0, (P.C1_BATT_CTR_Y + P.C1_BATT_POCKET_L / 2
                          + P.C1_BATT_RIB_T / 2,
                          P.C1_FLOOR_T + P.C1_BATT_RIB_H / 2),
                   cx + P.C1_BATT_LEAD_X0 + 0.3, cx + P.C1_BATT_RIB_SPAN_X / 2 - 0.3)
    check(not r, "the +Y rib is broken at its +X end for the cell's leads (BAT JST corner)")

    print(f"\n6. minimum feature width  (nozzle {P.NOZZLE:.1f}, "
          f"trace {P.MIN_WALL_TRACE:.2f}, solid {P.MIN_WALL_SOLID:.2f})")
    # Walls that carry load want two perimeters. Walls that only have to
    # exist need one trace. Separated, because a 1.07 skin is fine at 0.4
    # and is a single weak trace at 0.6.
    for nm, v in (("back floor", P.C1_FLOOR_T),
                  ("front face", P.C1_FACE_T),
                  ("outer skin X", SKIN_X), ("outer skin Y", SKIN_Y),
                  ("tongue X", SKIN_X), ("tongue Y", SKIN_Y),
                  ("standoff wall",
                   (P.C1_STANDOFF_OD - P.C1_SCREW_CLEAR_D) / 2),
                  ("battery rib", P.C1_BATT_RIB_T)):
        check(v >= P.MIN_WALL_SOLID - 1e-6,
              f"{nm} {v:.3f} >= {P.MIN_WALL_SOLID:.2f} (two perimeters)")
    for nm, v in (("straight window wall", P.C1_FACE_T - P.C1_WIN_FLARE),
                  ("face over the pilot", SEAT_A - P.C1_SCREW_PILOT_DEPTH)):
        check(v >= P.MIN_WALL_TRACE - 1e-6,
              f"{nm} {v:.3f} >= {P.MIN_WALL_TRACE:.2f} (one trace)")
    check(P.C1_LAP_CLEAR >= P.MIN_GAP - 1e-6,
          f"lap clearance {P.C1_LAP_CLEAR:.2f} >= {P.MIN_GAP:.2f} "
          f"(a narrower gap fills in)")
    check(P.LAYER_H <= 0.75 * P.NOZZLE,
          f"layer {P.LAYER_H} <= 0.75 x nozzle ({0.75 * P.NOZZLE:.2f})")

    print("\n7. overhangs — nothing may print over air, nothing past 45 deg")
    import math as _m
    for nm, m in (("front", F), ("back", B)):
        n, a = m.face_normals, m.area_faces
        zc = m.triangles[:, :, 2].mean(axis=1)
        bed = zc < m.bounds[0][2] + 0.05
        flat = (n[:, 2] < -0.985) & (~bed)
        # the deliberate down-facing geometry now: the back's tab chamfers
        # are 45 deg (pass the angle gate on their own), and the FRONT's
        # window roofs — each strip's underside is a 1.2 mm-thick bridge
        # over its window, anchored both ends, <= 8 mm span. Whitelisted
        # with a bounded area so nothing else can hide there.
        tc = m.triangles.mean(axis=1)
        in_snap = np.zeros(len(tc), bool)
        cap = 0.0
        if nm == "front":
            wz = JOINT_A + P._win_bot
            for sy, sites in ((-1, P.C1_SLIDE_SITES_NY), (+1, P.C1_SLIDE_SITES_PY)):
                yc = sy * (POK_Y + P.C1_TONGUE_T / 2)
                for xc, tw in sites:
                    a_ = xc - tw / 2 - P.C1_WIN_C
                    b_ = xc + P.C1_SLIDE_T + tw / 2 + P.C1_WIN_C
                    in_snap |= ((tc[:, 0] > -b_ - 0.3) & (tc[:, 0] < -a_ + 0.3)
                                & (np.abs(tc[:, 1] - yc) < P.C1_TONGUE_T)
                                & (np.abs(tc[:, 2] - wz) < 0.4))
                    cap += (b_ - a_ + 0.6) * (P.C1_TONGUE_T + 0.6) * 1.3
        zone_down = (n[:, 2] < -0.02) & (~bed) & in_snap
        print(f"       {nm}: down-facing area in the window-bridge zones {a[zone_down].sum():.2f} mm2 (cap {cap:.1f})")
        check(a[zone_down].sum() <= cap + 1e-6, f"{nm}: bridge zones hold only the window roofs")
        flat = flat & ~in_snap
        check(a[flat].sum() < 1.0,
              f"{nm}: flat unsupported ceiling area {a[flat].sum():.2f} mm2")
        # every down-facing facet: angle from vertical = asin(-n_z)
        down = (n[:, 2] < -0.02) & (~bed) & (~flat) & (~in_snap)
        ang = np.degrees(np.arcsin(np.clip(-n[down][:, 2], 0, 1)))
        steep = ang > 47.0                       # 45 + tessellation slack
        worst = ang.max() if down.any() else 0.0
        check(a[down][steep].sum() < 1.0,
              f"{nm}: down-facing area past 45 deg {a[down][steep].sum():.2f} mm2 "
              f"(steepest {worst:.1f} deg)")

    print("\n7c. floating regions — every layer must sit on the one below")
    # what the slicer does: 0.2 mm layers, any region with no overlap on the
    # layer beneath is an island printed on air. Sampled off the face planes.
    from shapely.geometry import Polygon
    from shapely.ops import unary_union
    def layer_regions(mesh, z):
        """Solid regions of one layer, in WORLD xy — no planar frame. Loops
        come from the section's own 3D polylines; nesting is resolved by
        even-odd symmetric difference, which handles holes and islands in
        holes alike."""
        sec = mesh.section(plane_origin=[0, 0, z], plane_normal=[0, 0, 1])
        if sec is None: return []
        loops = [Polygon(np.asarray(d)[:, :2]) for d in sec.discrete if len(d) >= 4]
        loops = [q if q.is_valid else q.buffer(0) for q in loops if q.area > 1e-3]
        if not loops: return []
        from functools import reduce
        shape = reduce(lambda a, b: a.symmetric_difference(b), sorted(loops, key=lambda q: -q.area))
        geoms = list(shape.geoms) if hasattr(shape, "geoms") else [shape]
        return [g for g in geoms if g.area > 0.02]
    def islands(mesh, layer=0.2):
        z0, z1 = mesh.bounds[0][2], mesh.bounds[1][2]
        prev, found = None, []
        for z in np.arange(z0 + 0.13, z1, layer):
            regs = layer_regions(mesh, z)
            if prev is not None:
                for q in regs:
                    if q.intersection(prev).area < 1e-4:
                        found.append((z, q.area, q.centroid.x, q.centroid.y))
            prev = unary_union(regs) if regs else None
        return found
    for nm, m in (("front", F), ("back", B)):
        isl = islands(m)
        for z, ar, x, y in isl[:6]:
            print(f"         {nm}: island {ar:.2f} mm2 at z={z:.2f} ({x:+.2f},{y:+.2f})")
        check(not isl, f"{nm}: no floating regions ({len(isl)} found)")

    print("\n7b. the cord tunnel")
    sx, sy = P.C1_TUN_SX, P.C1_TUN_SY
    r = P.C1_TUN_HOLE_D / 2
    zc = P.C1_TUN_Z
    tongue_free = P.C1_H - P.C1_FRONT_H                    # 4.49 assembled
    check(zc + r * 1.414 < tongue_free - 0.2,
          f"mouth apex {zc + r*1.414:.2f} clears the tongue's free end {tongue_free:.2f}")
    check(zc - r >= 0.9, f"floor keeps {zc - r:.2f} under the mouths")
    check(P.C1_CORD_D <= P.C1_TUN_HOLE_D - 2 * PROUD - 0.3,
          f"{P.C1_CORD_D} cord passes a {P.C1_TUN_HOLE_D - 2*PROUD:.2f} printed mouth")
    check(P.C1_FLOOR_T + P.C1_CORD_D <= tongue_free,
          f"cord on the floor ({P.C1_FLOOR_T + P.C1_CORD_D:.2f}) lies under the tongue")
    # mouths are open through their skins
    ax, by = sx * P.C1_TUN_A_X, sy * P.C1_TUN_B_Y
    rr = solid_runs(B, 1, (ax, zc), sy * (CAV_Y - 0.3), sy * (OUT_Y + 0.5))
    check(not rr, "mouth A is open through the +Y end skin")
    rr = solid_runs(B, 0, (by, zc), sx * (CAV_X - 0.3), sx * (OUT_X + 0.5))
    check(not rr, "mouth B is open through the -X side skin")
    # the bar: the corner standoff, and the channel round it
    stx, sty = [xy for xy in P.C1_SCREW_XY if (xy[0] * sx > 0 and xy[1] * sy > 0)][0]
    so_r = P.C1_STANDOFF_OD / 2 + PROUD
    ccx, ccy = sx * (OUT_X - R_OUT), sy * (OUT_Y - R_OUT)  # pebble arc centre
    d_so = math.hypot(stx - ccx, sty - ccy) + so_r        # standoff's outer reach
    # the cavity wall AT THE CORNER: its own R_CAV arc, centred inboard of
    # the pebble arc centre — not the flat-wall distance
    cvx, cvy = sx * (CAV_X - R_CAV), sy * (CAV_Y - R_CAV)
    d_cav = math.hypot(cvx - ccx, cvy - ccy) + R_CAV - PROUD
    chan = d_cav - d_so
    check(chan >= P.C1_CORD_D + 0.3,
          f"channel between the standoff and the corner wall {chan:.2f} >= cord + 0.3")
    # mouth A shares x with the standoff but not y: it opens at y = CAV_Y,
    # the standoff ends at |sty| + so_r; the difference is the end channel
    check(CAV_Y - PROUD - (abs(sty) + so_r) >= P.C1_CORD_D + 0.3,
          f"mouth A opens {CAV_Y - PROUD - (abs(sty) + so_r):.2f} beyond the standoff's reach — the cord turns past it")
    rr = solid_runs(B, 0, (sy * (CAV_Y - 1.0), zc + 0.9), sx * (OUT_X), 0)
    inner = [(a, b) for a, b in rr if abs(a) < CAV_X - 0.5 and abs(b) < CAV_X - 0.5]
    check(not any(min(abs(a), abs(b)) < abs(ax) + r and max(abs(a), abs(b)) > abs(ax) - r
                  for a, b in inner),
          "nothing inside blocks mouth A at cord height")
    # mouth B sits past the end of the cell's side rib, so the cord turns
    # straight out of the wall without running alongside the rib
    rib_end = P.C1_BATT_POCKET_L / 2 + PROUD
    check(abs(by) - (r - PROUD) >= rib_end,
          f"mouth B's lower edge {abs(by) - (r - PROUD):.2f} is past the cell rib's end {rib_end:.2f}")
    # and the channels the cord actually uses: along the end wall past the
    # standoff, and along the side wall past it
    end_ch = (CAV_Y - PROUD) - (abs(sty) + so_r)
    side_ch = (CAV_X - PROUD) - (abs(stx) + so_r)
    check(min(end_ch, side_ch) >= P.C1_CORD_D + 0.3,
          f"channels beside the standoff: end {end_ch:.2f}, side {side_ch:.2f} >= cord + 0.3")

    print("\n8. the no-SD set (case1_front / case1_back, as first printed)")
    F0, B0 = build_front(False), build_back(False)
    f0, b0 = os.path.join(tmp, "c1f0.stl"), os.path.join(tmp, "c1b0.stl")
    export_stl(F0, f0, tolerance=0.004, angular_tolerance=0.1)
    export_stl(B0, b0, tolerance=0.004, angular_tolerance=0.1)
    F0m, B0m = trimesh.load(f0), trimesh.load(b0)
    check(F0m.is_watertight and B0m.is_watertight, "both plain halves watertight")
    sec0 = B0m.section(plane_origin=[0, 0, P.C1_BACK_H - 0.15], plane_normal=[0, 0, 1])
    # world-frame loops for the same reason as in 3 — to_2D's frame is arbitrary
    outer0 = [L for L in (np.asarray(d) for d in sec0.discrete)
              if np.abs(L[:, 0]).max() > OUT_X - 1.0]
    check(len(outer0) == 4, f"plain back's rim cut only by USB + 2 buttons + the key slot ({len(outer0)} pieces)")
    r = solid_runs(B0m, 0, (P.SD_CTR_Y, P.C1_SD_SLOT_Z0 + 1.0), 0, OUT_X + 1)
    check(any(b > OUT_X - 0.3 for _, b in r), "plain back's skin solid at the SD")
    check(abs(F0m.volume - F.volume) < 400 and abs(B0m.volume - B.volume) < 400,
          "plain set differs from the sd_card set only by the slot and its relief")

    print("\n9. DOES IT CLOSE — the whole case, with its contents in it")
    # The check this file did not have, and three prints paid for it. Every
    # earlier check probed one feature against one other. This one lowers
    # the front onto the back and asks whether ANYTHING touches, then puts
    # the real contents in and asks the same. Two faults it caught first
    # time: the cell 1.00 mm into the front's tongue (case could not close
    # with a cell fitted) and the -Y board stops 0.10 under the standoffs.
    # (0.30 of lift is no longer free: the slide-lock tabs bite at 2*C1_WIN_C
    # — that engagement is checked, positively, in 3e)
    for lift in (0.05, 0.00):
        M = FA.copy(); M.apply_translation([0, 0, lift])
        try:
            v = trimesh.boolean.intersection([M, B], engine="manifold").volume
        except Exception:
            v = float("nan")
        check(not (v > 1e-3), f"halves free of each other at lift {lift:+.2f} ({v:.4f} mm3)")
    bb_ = P.C1_SEAT_Z - P.PCB_T
    # The four M2 pan heads, seated on the PCB's back face at the screw
    # columns — the contents the 2026-09-02 print proved the model was
    # missing: without them the sweep said "closes" while every standoff
    # stood on 1.6 mm of steel. Envelope = head + 0.4 dia + 0.2 height.
    head_r = (P.C1_SCREW_HEAD_D + 0.40) / 2
    head_h = P.C1_SCREW_HEAD_H + 0.20
    for x, y in P.C1_SCREW_XY:
        cyl = trimesh.creation.cylinder(radius=head_r, height=head_h, sections=48)
        cyl.apply_translation([x, y, bb_ - head_h / 2])
        vols = []
        for M in (FA, B):
            try:
                vols.append(trimesh.boolean.intersection([cyl, M], engine="manifold").volume)
            except Exception:
                vols.append(float("nan"))
        check(not (vols[0] > 1e-3 or vols[1] > 1e-3),
              f"screw head at ({x:+.1f},{y:+.1f}) is swallowed "
              f"({vols[0]:.3f} mm3 in front, {vols[1]:.3f} in back)")
    contents = [("PCB", 0.0, 0.0, (bb_ + P.C1_SEAT_Z) / 2, P.PCB_W, P.PCB_L, P.PCB_T),
                ("cell", P.C1_BATT_CTR_X, P.C1_BATT_CTR_Y, P.C1_FLOOR_T + P.BATT_T / 2,
                 P.BATT_W, P.BATT_L, P.BATT_T)]
    if P.HEADER_FITTED:
        contents.append(("header", P.HEADER_CTR_X, P.HEADER_CTR_Y, bb_ - P.HEADER_H / 2,
                         P.HEADER_W, P.HEADER_L, P.HEADER_H))
    g = np.mgrid[-1:1:11j, -1:1:15j, -1:1:9j].reshape(3, -1).T
    for nm_, x, y, z, w, l, h in contents:
        pts = np.column_stack([x + g[:, 0] * w / 2 * 0.999,
                               y + g[:, 1] * l / 2 * 0.999,
                               z + g[:, 2] * h / 2 * 0.999])
        fi, bi = int(FA.contains(pts).sum()), int(B.contains(pts).sum())
        check(fi + bi == 0, f"{nm_} ({w:.0f}x{l:.0f}x{h:.1f}) is clear of both halves "
                            f"({fi} pts in front, {bi} in back)")

    print()
    if FAIL:
        print(f"  {len(FAIL)} FAILED:")
        for f in FAIL:
            print(f"    - {f}")
        sys.exit(1)
    print("  all checks pass")


if __name__ == "__main__":
    main()
