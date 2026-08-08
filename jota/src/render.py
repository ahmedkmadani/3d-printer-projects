"""Render isometric PNGs of each part and an exploded assembly.

Uses matplotlib 3D with simple flat shading (no GUI / GPU needed).
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

import trimesh
from build123d import export_stl, Pos

import params as P
import components as C
from base import build_base
from lid import build_lid, build_plunger

import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders")
os.makedirs(OUT, exist_ok=True)


def mesh_of(part, tol=0.03):
    p = f"/tmp/_r_{id(part)}.stl"
    export_stl(part, p, tolerance=tol, angular_tolerance=0.2)
    return trimesh.load(p)


def shade(tris, light=np.array([0.4, 0.5, 0.75]), base=(0.62, 0.70, 0.80)):
    n = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    ln = np.linalg.norm(n, axis=1)
    ln[ln == 0] = 1
    n = n / ln[:, None]
    lam = np.clip(n @ (light / np.linalg.norm(light)), 0, 1)
    shade = 0.35 + 0.65 * lam
    return np.array(base)[None, :] * shade[:, None]


def render(items, fname, title, elev=28, azim=-52, colors=None):
    """items: list of trimesh meshes. colors: optional list of base RGB."""
    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection="3d")
    allpts = np.vstack([m.vertices for m in items])
    for i, m in enumerate(items):
        tris = m.triangles
        base = colors[i] if colors else (0.62, 0.70, 0.80)
        fc = shade(tris, base=base)
        pc = Poly3DCollection(tris, facecolors=fc, edgecolors="none")
        ax.add_collection3d(pc)
    c = allpts.mean(axis=0)
    r = (allpts.max(0) - allpts.min(0)).max() / 2 * 1.05
    ax.set_xlim(c[0] - r, c[0] + r)
    ax.set_ylim(c[1] - r, c[1] + r)
    ax.set_zlim(c[2] - r, c[2] + r)
    ax.set_box_aspect((1, 1, 1))
    ax.view_init(elev=elev, azim=azim)
    ax.set_axis_off()
    ax.set_title(title, fontsize=13, pad=0)
    fig.savefig(f"{OUT}/{fname}", dpi=115, bbox_inches="tight")
    plt.close(fig)
    print(f"  wrote {OUT}/{fname}")


def main():
    base = build_base()
    lid = build_lid()
    plunger = build_plunger()

    render([mesh_of(base)], "base_iso.png",
           "Base tray  (floor on bed)  —  USB/mic/LED front, buttons+SD right")
    render([mesh_of(lid)], "lid_iso.png",
           "Lid  (shown open-side up; prints top-face down)", elev=-24, azim=-52)

    # plunger: two of them side by side
    pl = mesh_of(plunger)
    pl2 = mesh_of(build_plunger().moved(Pos(9, 0, 0)))
    render([pl, pl2], "plunger_iso.png", "Button plungers  (x2, cap on bed)",
           elev=22, azim=-60,
           colors=[(0.80, 0.55, 0.45), (0.80, 0.55, 0.45)])

    # exploded assembly: base at 0, components lifted, lid on top, all along +Z
    comps = C.all_components()
    layers = []
    colors = []
    layers.append(mesh_of(base)); colors.append((0.60, 0.68, 0.78))
    dz = 6
    def lift(part, z):
        return mesh_of(part.moved(Pos(0, 0, z)))
    # battery just above tray floor level shown lifted
    layers.append(lift(C.battery(), dz)); colors.append((0.45, 0.65, 0.50))
    layers.append(lift(C.pcb(), dz * 2.2)); colors.append((0.30, 0.55, 0.35))
    layers.append(lift(C.display(), dz * 2.2)); colors.append((0.85, 0.85, 0.88))
    lidm = build_lid()
    layers.append(mesh_of(lidm.moved(Pos(0, 0, dz * 4))))
    colors.append((0.78, 0.72, 0.62))
    layers.append(mesh_of(build_plunger()
                          .rotate(__import__("build123d").Axis.Y, 90)
                          .moved(Pos(P.OUT_W / 2 + dz * 2, P.BTN1_CTR_Y, P.BTN_CTR_Z))))
    colors.append((0.80, 0.55, 0.45))
    render(layers, "exploded.png",
           "Exploded assembly  (base ▸ battery ▸ board ▸ e-paper ▸ lid ▸ plunger)",
           elev=18, azim=-58, colors=colors)


if __name__ == "__main__":
    main()
