#!/usr/bin/env python3
"""Convert the preview PGMs to PNGs and tile them into one contact sheet.

Screens are scaled with NEAREST so we review actual pixels — on a 200x200
1-bit panel every pixel is a design decision, and smoothing would hide
exactly the artefacts we are looking for.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SCALE = 3
COLS = 4
PAD = 14
LABEL_H = 16
BG = 235


def main() -> int:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    pgms = sorted(out.glob("*.pgm"))
    if not pgms:
        print(f"no .pgm files in {out}", file=sys.stderr)
        return 1

    tiles = []
    for p in pgms:
        img = Image.open(p).convert("L")
        img = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
        png = p.with_suffix(".png")
        img.save(png)
        p.unlink()  # keep the directory to just the reviewable PNGs
        tiles.append((p.stem, img))

    tw, th = tiles[0][1].size
    rows = (len(tiles) + COLS - 1) // COLS
    sheet = Image.new(
        "L",
        (COLS * tw + (COLS + 1) * PAD, rows * (th + LABEL_H) + (rows + 1) * PAD),
        BG,
    )
    draw = ImageDraw.Draw(sheet)

    for i, (name, img) in enumerate(tiles):
        c, r = i % COLS, i // COLS
        x = PAD + c * (tw + PAD)
        y = PAD + r * (th + LABEL_H + PAD)
        sheet.paste(img, (x, y))
        draw.rectangle([x - 1, y - 1, x + tw, y + th], outline=140)
        draw.text((x, y + th + 3), name, fill=60)

    sheet_path = out / "contact_sheet.png"
    sheet.save(sheet_path)
    print(f"{len(tiles)} screens -> {sheet_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
