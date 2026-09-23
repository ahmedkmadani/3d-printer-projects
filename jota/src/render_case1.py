"""Render case 1. Run: .venv/bin/python jota/src/render_case1.py

Per-pixel depth, not matplotlib's painter. matplotlib sorts whole triangles
by average depth, which on interlocking geometry is simply wrong — it once
painted the base over the lid and made a closed case look like an open tray.
A lap joint is exactly the geometry that breaks it.
"""

import os
import sys

import numpy as np
import trimesh
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import params as P

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "renders", "case1")
W = H = 900
BG = np.array([246, 244, 240], float)


def raster(mesh, colour, elev=28.0, azim=38.0, roll=0.0, pad=1.12):
    e, a = np.radians(elev), np.radians(azim)
    fwd = np.array([np.cos(e) * np.cos(a), np.cos(e) * np.sin(a), np.sin(e)])
    up0 = np.array([0, 0, 1.0])
    right = np.cross(fwd, up0); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    if roll:
        r = np.radians(roll)
        right, up = right * np.cos(r) + up * np.sin(r), up * np.cos(r) - right * np.sin(r)
    v = mesh.vertices - mesh.bounds.mean(axis=0)
    # the camera sits at +fwd looking back down -fwd, so depth grows away
    # from it. Getting this backwards renders the part from underneath.
    x, y, d = v @ right, v @ up, -(v @ fwd)
    s = max(x.max() - x.min(), y.max() - y.min()) * pad
    px = (x / s + 0.5) * W
    py = (0.5 - y / s) * H
    tri = mesh.faces
    zbuf = np.full((H, W), np.inf)
    img = np.tile(BG, (H, W, 1))
    # light over the viewer's shoulder, so what faces the camera is what is
    # lit. A world-fixed light leaves every visible face in shadow.
    light = fwd + 0.45 * up - 0.30 * right
    light /= np.linalg.norm(light)
    shade = np.clip(mesh.face_normals @ light, 0, 1) * 0.70 + 0.30
    col = np.asarray(colour, float)
    if col.ndim == 1:
        col = np.tile(col, (len(tri), 1))
    order = np.argsort(-d[tri].mean(axis=1))
    for f in order:
        i, j, k = tri[f]
        ax_, ay_, bx, by, cx, cy = px[i], py[i], px[j], py[j], px[k], py[k]
        x0, x1 = int(max(min(ax_, bx, cx), 0)), int(min(max(ax_, bx, cx) + 1, W))
        y0, y1 = int(max(min(ay_, by, cy), 0)), int(min(max(ay_, by, cy) + 1, H))
        if x1 <= x0 or y1 <= y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + .5, np.arange(y0, y1) + .5)
        den = (by - cy) * (ax_ - cx) + (cx - bx) * (ay_ - cy)
        if abs(den) < 1e-9:
            continue
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w1 = ((cy - ay_) * (gx - cx) + (ax_ - cx) * (gy - cy)) / den
        w2 = 1 - w0 - w1
        m = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not m.any():
            continue
        z = w0 * d[i] + w1 * d[j] + w2 * d[k]
        sub = zbuf[y0:y1, x0:x1]
        hit = m & (z < sub)
        sub[hit] = z[hit]
        img[y0:y1, x0:x1][hit] = col[f] * shade[f]
    return img, zbuf


def compose(meshes, colours, name, **kw):
    """One rasterisation pass over both halves, with a colour per face.

    Compositing two separately-rendered depth buffers speckles wherever the
    silhouettes coincide — and here they always do, because both halves share
    the same pebble. One pass, one z-buffer, no ties to break.
    """
    merged = trimesh.util.concatenate(meshes)
    per_face = np.vstack([np.tile(np.asarray(c, float), (len(m.faces), 1))
                          for m, c in zip(meshes, colours)])
    img, _ = raster(merged, per_face, **kw)
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, name)
    Image.fromarray(img.clip(0, 255).astype(np.uint8)).save(p)
    print(f"  {p}")


if __name__ == "__main__":
    d = os.path.join(ROOT, "models", "next")
    front = trimesh.load(os.path.join(d, "case1_front.stl"))
    back = trimesh.load(os.path.join(d, "case1_back.stl"))
    # assemble: front is authored face-down, so 180 about Y onto the back
    fa = front.copy()
    T = np.eye(4); T[:3, :3] = np.diag([-1., 1., -1.]); T[2, 3] = P.C1_H
    fa.apply_transform(T)
    BONE = np.array([228, 222, 210], float)
    CLAY = np.array([198, 158, 132], float)
    compose([back, fa], [BONE, CLAY], "assembled.png")
    compose([back, fa], [BONE, CLAY], "assembled_end.png", elev=8, azim=-88)
    compose([back], [BONE], "back.png", elev=42, azim=52)
    compose([front], [CLAY], "front.png", elev=42, azim=-128)
