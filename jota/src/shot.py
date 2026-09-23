"""Per-pixel z-buffer renderer for product shots.

Why this exists rather than render.py: matplotlib's Poly3DCollection sorts
whole triangles by their average depth, which is simply wrong on interlocking
geometry. A closed case came out looking like an open tray because the base's
big far-side triangles sorted in front of the lid's small near-side ones.
This rasterises with a real depth buffer, so a pixel shows whatever is
actually nearest the camera.

Orthographic, flat-shaded, transparent background. No GPU, no GUI.
"""

import numpy as np
import trimesh
from build123d import export_stl

SS = 3  # supersample factor, averaged down at the end


def mesh_of(part, tol=0.012):
    """Tessellate a build123d Part. Tolerance is tighter than export.py's
    0.02 because these are looked at, not printed."""
    p = f"/tmp/_shot_{abs(hash(str(id(part)))) % (10**9)}.stl"
    export_stl(part, p, tolerance=tol, angular_tolerance=0.1)
    return trimesh.load(p)


def _basis(elev, azim):
    """Camera basis: right, up, view direction (world -> camera)."""
    e, a = np.radians(elev), np.radians(azim)
    fwd = np.array([np.cos(e) * np.cos(a), np.cos(e) * np.sin(a), np.sin(e)])
    fwd /= np.linalg.norm(fwd)
    world_up = np.array([0.0, 0.0, 1.0])
    right = np.cross(world_up, fwd)
    if np.linalg.norm(right) < 1e-9:          # looking straight down
        right = np.array([1.0, 0.0, 0.0])
    right /= np.linalg.norm(right)
    up = np.cross(fwd, right)
    return right, up, fwd


def render(items, path, size=760, elev=26, azim=-52,
           light=(0.42, 0.5, 0.78), bg=None, margin=1.06, bounds=None):
    """items: list of (trimesh, rgb_tuple). Writes an RGBA PNG.

    bounds: optional (centre, radius) shared across several shots so parts
    render at a consistent scale instead of each filling its own frame.
    """
    W = H = size * SS
    right, up, fwd = _basis(elev, azim)

    tris, cols = [], []
    for m, c in items:
        t = m.triangles
        if len(t) == 0:
            continue
        tris.append(t)
        cols.append(np.tile(np.array(c, float), (len(t), 1)))
    tris = np.concatenate(tris)
    cols = np.concatenate(cols)

    pts = tris.reshape(-1, 3)
    if bounds is None:
        centre = (pts.min(0) + pts.max(0)) / 2
        radius = np.abs(pts - centre).max() * margin
    else:
        centre, radius = bounds
    if radius <= 0:
        radius = 1.0

    # world -> camera (orthographic): x right, y up, z depth (smaller = nearer)
    rel = tris - centre
    cx = rel @ right
    cy = rel @ up
    # fwd points from the origin TOWARDS the camera, so depth grows away from
    # it. Getting this sign wrong renders the object from underneath.
    cz = -(rel @ fwd)

    # camera -> pixels
    px = (cx / radius * 0.5 + 0.5) * (W - 1)
    py = (1.0 - (cy / radius * 0.5 + 0.5)) * (H - 1)

    # flat shading from the geometric normal, two-sided
    n = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    ln = np.linalg.norm(n, axis=1)
    ln[ln == 0] = 1
    n = n / ln[:, None]
    L = np.array(light, float)
    L /= np.linalg.norm(L)
    lam = np.abs(n @ L)
    shade = 0.34 + 0.66 * lam
    face_rgb = np.clip(cols * shade[:, None], 0, 1)

    colour = np.zeros((H, W, 3), np.float32)
    depth = np.full((H, W), np.inf, np.float32)
    alpha = np.zeros((H, W), bool)

    # Painter's-algorithm-free: rasterise each triangle into its own bbox and
    # keep the nearest fragment per pixel.
    x0 = np.clip(np.floor(px.min(1)).astype(int), 0, W - 1)
    x1 = np.clip(np.ceil(px.max(1)).astype(int), 0, W - 1)
    y0 = np.clip(np.floor(py.min(1)).astype(int), 0, H - 1)
    y1 = np.clip(np.ceil(py.max(1)).astype(int), 0, H - 1)

    ax, ay = px[:, 0], py[:, 0]
    bx, by = px[:, 1], py[:, 1]
    ccx, ccy = px[:, 2], py[:, 2]
    area = (bx - ax) * (ccy - ay) - (by - ay) * (ccx - ax)

    for i in range(len(tris)):
        if abs(area[i]) < 1e-12 or x1[i] < x0[i] or y1[i] < y0[i]:
            continue
        xs = np.arange(x0[i], x1[i] + 1)
        ys = np.arange(y0[i], y1[i] + 1)
        gx, gy = np.meshgrid(xs + 0.5, ys + 0.5)
        w0 = ((bx[i] - ax[i]) * (gy - ay[i]) - (by[i] - ay[i]) * (gx - ax[i])) / area[i]
        w1 = ((ccx[i] - bx[i]) * (gy - by[i]) - (ccy[i] - by[i]) * (gx - bx[i])) / area[i]
        w2 = 1.0 - w0 - w1
        inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        if not inside.any():
            continue
        # barycentric order: w1->A, w2->B, w0->C
        z = w1 * cz[i, 0] + w2 * cz[i, 1] + w0 * cz[i, 2]
        sub_d = depth[y0[i]:y1[i] + 1, x0[i]:x1[i] + 1]
        win = inside & (z < sub_d)
        if not win.any():
            continue
        sub_d[win] = z[win]
        colour[y0[i]:y1[i] + 1, x0[i]:x1[i] + 1][win] = face_rgb[i]
        alpha[y0[i]:y1[i] + 1, x0[i]:x1[i] + 1][win] = True

    rgba = np.zeros((H, W, 4), np.float32)
    rgba[..., :3] = colour
    rgba[..., 3] = alpha.astype(np.float32)
    if bg is not None:
        b = np.array(bg, float)
        a = rgba[..., 3:4]
        rgba[..., :3] = rgba[..., :3] * a + b * (1 - a)
        rgba[..., 3] = 1.0

    # box-average down for antialiasing
    small = rgba.reshape(size, SS, size, SS, 4).mean(axis=(1, 3))
    img = (np.clip(small, 0, 1) * 255).astype(np.uint8)
    from PIL import Image
    Image.fromarray(img, "RGBA").save(path)
    return path


def shared_bounds(meshes, margin=1.06):
    """One centre/radius for a set of meshes, so a family of shots share scale."""
    pts = np.concatenate([m.vertices for m in meshes if len(m.vertices)])
    centre = (pts.min(0) + pts.max(0)) / 2
    radius = np.abs(pts - centre).max() * margin
    return centre, radius
