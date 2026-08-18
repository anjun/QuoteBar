#!/usr/bin/env python3
"""Draw a simple white-tile + red Q app icon and emit AppIcon.icns."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Resources"
MASTER = OUT_DIR / "AppIcon-1024.png"
ICONSET = OUT_DIR / "AppIcon.iconset"
ICNS = OUT_DIR / "AppIcon.icns"

SIZE = 1024
FILL = (248, 249, 251, 255)
MARK = (226, 52, 45, 255)
FONT = Path("/System/Library/Fonts/SFNSRounded.ttf")
CORNER = int(SIZE * 0.223)


def draw_master() -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    inset = 1
    draw.rounded_rectangle(
        [inset, inset, SIZE - 1 - inset, SIZE - 1 - inset],
        radius=CORNER,
        fill=FILL,
    )
    font = ImageFont.truetype(str(FONT), 340)
    letter = "Q"
    left, top, right, bottom = draw.textbbox((0, 0), letter, font=font)
    x = (SIZE - (right - left)) / 2 - left
    y = (SIZE - (bottom - top)) / 2 - top - 8
    draw.text((x, y), letter, font=font, fill=MARK)
    return img


def write_iconset(master: Image.Image) -> None:
    if ICONSET.exists():
        for child in ICONSET.iterdir():
            child.unlink()
    else:
        ICONSET.mkdir(parents=True)

    specs = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    for edge, name in specs:
        resized = master.resize((edge, edge), Image.Resampling.LANCZOS)
        if edge <= 32:
            resized = resized.filter(ImageFilter.SHARPEN)
        resized.save(ICONSET / name, "PNG")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    master = draw_master()
    master.save(MASTER, "PNG")
    write_iconset(master)
    print(f"wrote {MASTER}")


if __name__ == "__main__":
    main()
