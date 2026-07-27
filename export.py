"""Export print-oriented STL + STEP, and render PNGs.

Print orientation (stated per part):
  base    : exterior floor on the bed (as modeled, open side up). No supports:
            the seat ledges and rib tops are the only overhangs and each has a
            45-degree chamfered underside; widest bridge is the 9 mm USB slot.
  lid     : outer TOP face on the bed (rotated 180 about X). Skirt and bezel
            point up; snap windows are holes in vertical walls (self-supporting).
  plunger : cap face on the bed (as modeled). Pure vertical extrusion.
"""

import numpy as np
from build123d import Axis, export_step, export_stl

import params as P
import components as C
from base import build_base
from lid import build_lid, build_plunger

OUT = "."


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
    export_step(base, f"{OUT}/base.step")
    export_step(lid, f"{OUT}/lid.step")
    export_step(plunger, f"{OUT}/plunger.step")

    # STL (print-oriented)
    export_stl(base, f"{OUT}/base.stl", tolerance=0.02, angular_tolerance=0.15)
    export_stl(orient_lid(lid), f"{OUT}/lid.stl", tolerance=0.02,
               angular_tolerance=0.15)
    export_stl(plunger, f"{OUT}/plunger.stl", tolerance=0.01,
               angular_tolerance=0.1)
    print("wrote base/lid/plunger .step and .stl")


if __name__ == "__main__":
    main()
