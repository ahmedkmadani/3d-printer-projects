"""Export print-oriented STL + STEP, and render PNGs.

Print orientation (stated per part):
  base    : exterior floor on the bed (as modeled, open side up). No supports:
            the seat ledges and rib tops are the only overhangs and each has a
            45-degree chamfered underside; widest bridge is the 9 mm USB slot.
  lid     : outer TOP face on the bed (rotated 180 about X). Skirt and bezel
            point up; snap windows are holes in vertical walls (self-supporting).
  plunger : cap face on the bed (as modeled). Pure vertical extrusion.
"""

import os
import numpy as np
from build123d import Axis, export_step, export_stl

import params as P
import components as C
from base import build_base
from lid import build_lid, build_plunger

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STL = os.path.join(ROOT, "models", "stl")
STEP = os.path.join(ROOT, "models", "step")
os.makedirs(STL, exist_ok=True)
os.makedirs(STEP, exist_ok=True)


def orient_lid(lid):
    """Top face down for printing."""
    l = lid.rotate(Axis.X, 180)
    bb = l.bounding_box()
    return l.moved(__import__("build123d").Pos(0, 0, -bb.min.Z))


def main():
    base = build_base()
    lid = build_lid()
    plunger = build_plunger()

    # STEP (assembled coordinates, for FreeCAD)
    export_step(base, os.path.join(STEP, "base.step"))
    export_step(lid, os.path.join(STEP, "lid.step"))
    export_step(plunger, os.path.join(STEP, "plunger.step"))

    # STL (print-oriented)
    export_stl(base, os.path.join(STL, "base.stl"), tolerance=0.02,
               angular_tolerance=0.15)
    export_stl(orient_lid(lid), os.path.join(STL, "lid.stl"), tolerance=0.02,
               angular_tolerance=0.15)
    export_stl(plunger, os.path.join(STL, "plunger.stl"), tolerance=0.01,
               angular_tolerance=0.1)
    print(f"wrote base/lid/plunger .step -> {STEP}")
    print(f"wrote base/lid/plunger .stl  -> {STL}")


if __name__ == "__main__":
    main()
