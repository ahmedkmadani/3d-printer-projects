#!/usr/bin/env python3
"""Render the Jota mark to the Android launcher icons.

    .venv/bin/python jota/app/tool/make_icon.py

The mark is a circle with `Jota` inside it (docs/brand.md). This draws the SAME
geometry lib/design/mark.dart draws — ink ring, serif word, proportional stroke
— from the same bundled Plex Serif, so the icon and the in-app mark cannot
drift apart.

Inverted for the launcher: an outlined ring on paper disappears against a light
wallpaper, and a launcher icon has to hold its own shape against anything. So
the disc is ink and the word is knocked out, which is the same inversion the
product uses for "selected" everywhere else.
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
FONT = os.path.join(APP, "assets", "fonts", "IBMPlexSerif-Regular.ttf")
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

# Supersample, then downsample: the ring and the serif stems are thin enough
# that drawing them straight at 48px gives a stair-stepped circle.
SS = 8


def render(px: int) -> Image.Image:
    n = px * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # A hair inside the canvas so the disc's own edge is not clipped by it.
    pad = n * 0.02
    d.ellipse([pad, pad, n - pad, n - pad], fill=INK)

    # Same proportion as JotaMark: the word fills a little under a third of the
    # diameter. Measured and centred on the INK BOX rather than the font's
    # metrics — a serif's ascent leaves the word visibly high otherwise.
    font = ImageFont.truetype(FONT, int(n * 0.30))
    box = d.textbbox((0, 0), "Jota", font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    d.text((n / 2 - w / 2 - box[0], n / 2 - h / 2 - box[1]), "Jota",
           font=font, fill=PAPER)

    return img.resize((px, px), Image.LANCZOS)


def main() -> None:
    if not os.path.exists(FONT):
        raise SystemExit(f"font not found: {FONT}")

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
