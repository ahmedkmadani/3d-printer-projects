#!/usr/bin/env python3
"""Render the Jota mark to the Android launcher icons.

    .venv/bin/python jota/app/tool/make_icon.py

The circle is your head; the dots are the thoughts in it. `Jota` is Sudanese
Arabic for *many thoughts, all at once* (docs/brand.md), and a scatter of
unequal dots says that where a single centred dot says the opposite — one
thought, tidily held.

Five dots, one dominant and four lesser, at unequal sizes and unequal
distances. The irregularity is the point: evenly spaced dots of one size read
as a loading indicator or a dot-matrix, and brand.md rules both out.

Paper, not ink, and no ring — the light treatment, rather than the filled disc
with the word knocked out that this file used to draw. The cost is known: on a
pale wallpaper the disc's edge nearly disappears, so what a person sees is the
dots floating rather than a badge.

The smallest dot is what decides this icon. At mdpi the disc is 48 px and that
dot is under 4 px, so every position and radius below is held clear of the rim
and checked at 48 before anything else — a scatter that dissolves into grey
mush at the size most launchers actually draw is not a mark.
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
RES = os.path.join(APP, "android", "app", "src", "main", "res")

INK = (35, 32, 28, 255)      # #23201C
PAPER = (246, 241, 232, 255)  # #F6F1E8

# Android's launcher densities. mdpi is the 48pt baseline.
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Supersample, then downsample: at mdpi the smallest dot is under 4 px across,
# and drawn straight at that size it is a square.
SS = 8

# The scatter, as (centre x, centre y, radius) in FRACTIONS of the diameter, so
# one set of numbers serves every density. Ordered largest first.
#
# Held inside radius 0.33 of centre: the furthest dot's outer edge lands at
# 0.37 against the disc's 0.48, which keeps the whole mark clear of whatever
# shape a launcher masks it into.
#
# NO TWO DOTS SHARE A HEIGHT, and no pair mirrors across the vertical axis.
# That is not fussiness. The first arrangement had two dots level either side
# of a large central one, with two more level below, and it read unmistakably
# as a face — eyes, nose, mouth. Tidying these numbers into anything
# symmetrical brings the face straight back.
DOTS = (
    (0.395, 0.415, 0.098),
    (0.585, 0.600, 0.070),
    (0.660, 0.335, 0.055),
    (0.315, 0.640, 0.040),
    (0.470, 0.235, 0.030),
)


def render(px: int) -> Image.Image:
    n = px * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # A hair inside the canvas so the disc's own edge is not clipped by it.
    pad = n * 0.02
    d.ellipse([pad, pad, n - pad, n - pad], fill=PAPER)

    for cx, cy, r in DOTS:
        x, y, rad = cx * n, cy * n, r * n
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=INK)

    return img.resize((px, px), Image.LANCZOS)


def main() -> None:
    for folder, px in SIZES.items():
        out_dir = os.path.join(RES, folder)
        os.makedirs(out_dir, exist_ok=True)
        icon = render(px)
        for name in ("ic_launcher.png", "ic_launcher_round.png"):
            icon.save(os.path.join(out_dir, name))
        print(f"  {folder:16} {px}x{px}")

    # A big one for the listing / the article, and for looking at.
    preview = os.path.join(APP, "..", "renders", "jota_mark.png")
    os.makedirs(os.path.dirname(preview), exist_ok=True)
    render(512).save(preview)
    print(f"  preview          512x512 -> {os.path.normpath(preview)}")


if __name__ == "__main__":
    main()
