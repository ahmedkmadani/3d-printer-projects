#!/usr/bin/env python3
"""Render the Jota mark to the Android launcher icons.

    .venv/bin/python jota/app/tool/make_icon.py

The mark is a ring with thoughts in it: the ring is your head — the same
hairline ring the device draws round its wordmark when it sleeps — and the
five dots of unequal size, unequally placed, are what is in it. `Jota` is
Sudanese Arabic for *many thoughts, all at once* (docs/brand.md).

It was a paper disc with the dots and no ring; on a pale wallpaper the
disc's edge vanished and the dots floated. The ring gives the head an edge
on any wallpaper and in either theme.

THE NUMBERS BELOW ARE THE NUMBERS IN lib/design/marks.dart. Change both or
neither: the icon a person taps and the mark they then see must be one thing.

Three renders per density:
  ic_launcher / ic_launcher_round  legacy icons (Android < 8): paper disc,
                                   ring, thoughts
  ic_launcher_foreground           adaptive foreground: ring and thoughts on
                                   transparent, inside the 66/108 safe zone
  ic_launcher_monochrome           the same shapes in one colour, for
                                   Android 13 themed icons
plus mipmap-anydpi-v26/ic_launcher.xml (+_round) and the background colour.

The smallest dot decides everything: at mdpi it is under 3 px across, so the
mark is supersampled and checked at 48 before anything else.
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
RES = os.path.join(APP, "android", "app", "src", "main", "res")

INK = (35, 32, 28, 255)       # #23201C, theme.dart light ink
PAPER = (246, 241, 232, 255)  # #F6F1E8, theme.dart light bg
CLEAR = (0, 0, 0, 0)

# mdpi is the 48 dp baseline for legacy icons; adaptive layers are 108 dp.
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
ADAPTIVE = {k: round(v * 108 / 48) for k, v in SIZES.items()}

SS = 8  # supersample factor

# Fractions of the mark's diameter — lib/design/marks.dart kThoughts.
DOTS = (
    (0.395, 0.415, 0.098),
    (0.585, 0.600, 0.070),
    (0.660, 0.335, 0.055),
    (0.315, 0.640, 0.040),
    (0.470, 0.235, 0.030),
)
RING = 0.44     # kMarkRing
STROKE = 0.032  # kMarkStroke


def draw_mark(d: ImageDraw.ImageDraw, cx: float, cy: float, diam: float,
              ink) -> None:
    r = RING * diam
    w = max(1.0, STROKE * diam)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=ink, width=round(w))
    for x, y, rad in DOTS:
        px, py, pr = cx + (x - 0.5) * diam, cy + (y - 0.5) * diam, rad * diam
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=ink)


def legacy(px: int) -> Image.Image:
    n = px * SS
    img = Image.new("RGBA", (n, n), CLEAR)
    d = ImageDraw.Draw(img)
    pad = n * 0.02
    d.ellipse([pad, pad, n - pad, n - pad], fill=PAPER)
    # The mark sits a little inside the disc so the ring reads as a ring, not
    # as the disc's rim.
    draw_mark(d, n / 2, n / 2, n * 0.84, INK)
    return img.resize((px, px), Image.LANCZOS)


def adaptive_foreground(px: int, ink) -> Image.Image:
    n = px * SS
    img = Image.new("RGBA", (n, n), CLEAR)
    d = ImageDraw.Draw(img)
    # Safe zone is the inner 66/108 = 0.611 of the canvas. The ring's outer
    # edge (0.44 + 0.016) must land inside 0.305 of the canvas, so the mark
    # is drawn at 0.305 / 0.456 = 0.67 of the canvas — a hair under.
    draw_mark(d, n / 2, n / 2, n * 0.66, ink)
    return img.resize((px, px), Image.LANCZOS)


def main() -> None:
    for folder, px in SIZES.items():
        out_dir = os.path.join(RES, folder)
        os.makedirs(out_dir, exist_ok=True)
        icon = legacy(px)
        for name in ("ic_launcher.png", "ic_launcher_round.png"):
            icon.save(os.path.join(out_dir, name))
        apx = ADAPTIVE[folder]
        adaptive_foreground(apx, INK).save(
            os.path.join(out_dir, "ic_launcher_foreground.png"))
        adaptive_foreground(apx, (0, 0, 0, 255)).save(
            os.path.join(out_dir, "ic_launcher_monochrome.png"))
        print(f"  {folder:16} legacy {px}  adaptive {apx}")

    v26 = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(v26, exist_ok=True)
    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        '</adaptive-icon>\n'
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(v26, name), "w") as f:
            f.write(xml)

    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, "ic_launcher_background.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="ic_launcher_background">#F6F1E8</color>\n'
                '</resources>\n')

    preview = os.path.join(APP, "..", "renders", "jota_mark.png")
    os.makedirs(os.path.dirname(preview), exist_ok=True)
    legacy(512).save(preview)
    print(f"  preview          512x512 -> {os.path.normpath(preview)}")


if __name__ == "__main__":
    main()
