#!/usr/bin/env python3
"""Build the macOS app icon the way system apps actually ship it.

Apple HIG (Tahoe / Icon Composer) says: give an unmasked square and let the
system apply the squircle. That path requires an Asset Catalog + CFBundleIconName.
A standalone CFBundleIconFile .icns is painted as-is. On Sequoia that means a
square RGB bitmap stays square in Launchpad/Dock.

System apps (Notes, Calculator) therefore pre-compose the macOS 11+ grid:
824pt continuous-rounded tile on a 1024 canvas, transparent corners, plus
Assets.car + CFBundleIconName. This script does the same.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Resources"
MASTER = OUT_DIR / "AppIcon-1024.png"
ICONSET = OUT_DIR / "AppIcon.iconset"
ICNS = OUT_DIR / "AppIcon.icns"
ASSETS_CAR = OUT_DIR / "Assets.car"
SWIFT = ROOT / "scripts" / "make-icon.swift"

SPECS = [
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


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd))
    return subprocess.run(cmd, check=True, text=True, **kwargs)


def render_master() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    run(["swift", str(SWIFT), str(MASTER)])
    image = Image.open(MASTER)
    if image.mode != "RGBA":
        raise SystemExit(f"{MASTER} must be RGBA, got {image.mode}")
    alpha = image.getchannel("A")
    if alpha.getpixel((0, 0)) > 32 or alpha.getpixel((1023, 1023)) > 32:
        raise SystemExit(f"{MASTER} corners are not transparent; Launchpad will stay square")


def write_iconset(master: Image.Image, dest: Path) -> None:
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    for edge, name in SPECS:
        resized = master.resize((edge, edge), Image.Resampling.LANCZOS)
        if edge <= 32:
            resized = resized.filter(ImageFilter.SHARPEN)
        resized.save(dest / name, "PNG")


def write_icns(master: Image.Image) -> None:
    write_iconset(master, ICONSET)
    run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)])
    shutil.rmtree(ICONSET)


def write_assets_car(master: Image.Image) -> None:
    scratch = Path(run(["mktemp", "-d"], capture_output=True).stdout.strip())
    try:
        catalog = scratch / "Assets.xcassets"
        appicon = catalog / "AppIcon.appiconset"
        appicon.mkdir(parents=True)
        (catalog / "Contents.json").write_text(
            json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
        )
        images = []
        for edge, name in SPECS:
            resized = master.resize((edge, edge), Image.Resampling.LANCZOS)
            if edge <= 32:
                resized = resized.filter(ImageFilter.SHARPEN)
            resized.save(appicon / name, "PNG")
            if name.endswith("@2x.png"):
                point = edge // 2
                scale = "2x"
            else:
                point = edge
                scale = "1x"
            images.append(
                {
                    "filename": name,
                    "idiom": "mac",
                    "scale": scale,
                    "size": f"{point}x{point}",
                }
            )
        (appicon / "Contents.json").write_text(
            json.dumps(
                {"images": images, "info": {"author": "xcode", "version": 1}},
                indent=2,
            )
            + "\n"
        )

        compiled = scratch / "out"
        compiled.mkdir()
        partial = scratch / "partial.plist"
        run(
            [
                "xcrun",
                "actool",
                str(catalog),
                "--compile",
                str(compiled),
                "--app-icon",
                "AppIcon",
                "--platform",
                "macosx",
                "--minimum-deployment-target",
                "14.0",
                "--target-device",
                "mac",
                "--output-partial-info-plist",
                str(partial),
                "--output-format",
                "human-readable-text",
                "--notices",
                "--warnings",
            ]
        )
        car = compiled / "Assets.car"
        if not car.exists():
            raise SystemExit(f"actool did not emit Assets.car in {compiled}")
        shutil.copy2(car, ASSETS_CAR)
        print(f"wrote {ASSETS_CAR}")
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def main() -> None:
    render_master()
    master = Image.open(MASTER).convert("RGBA")
    write_icns(master)
    write_assets_car(master)
    print(f"wrote {MASTER}")
    print(f"wrote {ICNS}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode)
