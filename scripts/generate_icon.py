#!/usr/bin/env python3
"""Generate the Shadowing app icon: a bold S with a translucent shadow S
behind it, on an indigo→cyan gradient. Outputs a 1024×1024 PNG."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "ShadowingApp" / "Assets.xcassets" / "AppIcon.appiconset" / "Icon-1024.png"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_background(size, top, bottom):
    img = Image.new("RGB", (size, size), top)
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        color = lerp(top, bottom, t)
        for x in range(size):
            px[x, y] = color
    return img.convert("RGBA")


def draw_letter(canvas, char, font, fill, offset=(0, 0)):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Measure the glyph and center it.
    bbox = draw.textbbox((0, 0), char, font=font)
    glyph_w = bbox[2] - bbox[0]
    glyph_h = bbox[3] - bbox[1]
    cx = (canvas.size[0] - glyph_w) // 2 - bbox[0]
    cy = (canvas.size[1] - glyph_h) // 2 - bbox[1]
    draw.text((cx + offset[0], cy + offset[1]), char, font=font, fill=fill)

    return Image.alpha_composite(canvas, layer)


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)

    # Indigo → cyan gradient: modern, calm, music-app-ish.
    top = (99, 102, 241)     # indigo-500
    bottom = (6, 182, 212)   # cyan-500
    img = gradient_background(SIZE, top, bottom)

    font_path = "/System/Library/Fonts/SFCompact.ttf"
    try:
        font = ImageFont.truetype(font_path, size=720)
    except Exception:
        font = ImageFont.load_default()

    # Translucent shadow S behind, offset down-right.
    img = draw_letter(img, "S", font, fill=(255, 255, 255, 64), offset=(44, 36))

    # Bold white S in front.
    img = draw_letter(img, "S", font, fill=(255, 255, 255, 255), offset=(0, 0))

    img.convert("RGB").save(OUT, format="PNG", optimize=True)
    print(f"Wrote {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
