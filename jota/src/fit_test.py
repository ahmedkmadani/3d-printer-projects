"""Fit-test tray — the cheapest possible answer to "does the board drop in?"

The full case is the wrong thing to print to answer that. Everything above the
seat plane (snaps, skirt, crown, window, bezel) is irrelevant to whether the
PCB fits between the end stops, and it is most of the print time.

So this takes the real base and slices off everything above the locating
rails. What survives is exactly the geometry that decides the fit: the floor,
the four seat ledges, both end stops, the side locating rails, the battery
corral, and the lower part of every wall opening.

It exists because PCB_L was wrong by 8 mm and nobody found out until a whole
case had been printed and assembled.

Run:  .venv/bin/python jota/src/fit_test.py
"""

import os
import sys

from build123d import Box, Pos, export_stl, Mesher

import params as P
from base import build_base

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "models", "next")
os.makedirs(OUT, exist_ok=True)

# Keep up to just above the locating rails: high enough that the rails can
# actually locate the board, low enough to stay a quick print.
CUT_Z = P.POST_SEAT_Z + 3.0

tray = build_base() & (
    Pos(0, P.IN_CTR_Y, (CUT_Z - P.FLOOR_T) / 2)
    * Box(P.OUT_W + 10, P.OUT_L + 10, CUT_Z + P.FLOOR_T)
)

cm3 = tray.volume / 1000.0
print(f"fit-test tray: {cm3:.2f} cm3 -> ~{cm3 * (0.55 + 0.45*0.20) * 1.27:.1f} g PETG")
print(f"  sliced at Z = {CUT_Z:.2f} (seat {P.POST_SEAT_Z:.2f} + 3.0)")
print()
print("  what this proves, and nothing more:")
print(f"    PCB {P.PCB_W} x {P.PCB_L} drops between the end stops and rails")
print(f"    seat ledges are coplanar at Z = {P.POST_SEAT_Z:.2f}")
print(f"    battery {P.BATT_W} x {P.BATT_L} sits in its corral")
print("    USB / SD openings line up in X and Y (their lower halves)")
print()
print("    button travel — the cut at POST_SEAT_Z + 3.0 keeps the whole boss")
print("      (Z 0..10.5) and the bore (Z 4.3..8.7), so fit a plunger and press")
print("      it. This was blocked on M27; SWITCH_TIP_X is now measured at")
print(f"      {P.SWITCH_TIP_X:.2f}, and testing it is the point of this print.")
print()
print("  what it CANNOT prove:")
print("    lid closure or overall height  -> needs M17, still blank")
print("    snap retention — every cantilever is above the cut, by design.")
print("      That is why this tray prints honestly in PLA and the case does not.")

export_stl(tray, os.path.join(OUT, "fit_test.stl"),
           tolerance=0.012, angular_tolerance=0.1)
m = Mesher(); m.add_shape(tray); m.write(os.path.join(OUT, "fit_test.3mf"))
print(f"\nwrote fit_test.stl / .3mf -> {OUT}")
