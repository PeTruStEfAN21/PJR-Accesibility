"""The app icon, from the brand logo: the ear with the "e" in it, white on the logo's turquoise.

Writes, from app/assets/brand/echo-logo.svg:
  - Android launcher icons: the legacy tiles (mipmap-*/ic_launcher.png) and the adaptive icon
    (ic_launcher_foreground.png + mipmap-anydpi-v26/ic_launcher.xml, background colour in values/colors.xml)
  - the Android notification icon (drawable-*/ic_notification.png: white on transparent, as Android tints it)
  - the iOS icon set (every size in AppIcon.appiconset/Contents.json)

Needs Chrome (it renders the SVG) and Pillow:

    pip install pillow
    python tools/app_icon.py
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG = os.path.join(ROOT, "app", "assets", "brand", "echo-logo.svg")
ANDROID_RES = os.path.join(ROOT, "app", "android", "app", "src", "main", "res")
IOS_SET = os.path.join(ROOT, "app", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

# EchoPalette.turquoise, the logo's colour.
TURQUOISE = "#10A9B6"
MASTER = 1024

# The ear and the "e" are the logo's first four paths; with the 11-wide stroke they span this box.
MARK_BOX = (27.5, 22.5, 142.5, 167.5)

LAUNCHER_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND_SIZES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
NOTIFICATION_SIZES = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}


def chrome():
    for candidate in (
        os.environ.get("CHROME"),
        shutil.which("chrome"),
        shutil.which("google-chrome"),
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    ):
        if candidate and os.path.exists(candidate):
            return candidate
    sys.exit("Chrome not found: set CHROME to its path")


def mark_paths():
    svg = open(SVG, encoding="utf-8").read()
    return "".join(f'<path d="{d}"/>' for d in re.findall(r'<path d="([^"]+)"', svg)[:4])


def icon_svg(*, background, mark_height):
    """The mark centred in a MASTER × MASTER square, [mark_height] as a share of the side."""
    left, top, right, bottom = MARK_BOX
    scale = MASTER * mark_height / (bottom - top)
    width = (right - left) * scale
    tx = (MASTER - width) / 2 - left * scale
    ty = (MASTER - MASTER * mark_height) / 2 - top * scale
    rect = f'<rect width="{MASTER}" height="{MASTER}" fill="{TURQUOISE}"/>' if background else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{MASTER}" height="{MASTER}" viewBox="0 0 {MASTER} {MASTER}">'
        f"{rect}<g transform=\"translate({tx:.3f} {ty:.3f}) scale({scale:.5f})\" fill=\"none\" stroke=\"#ffffff\" "
        f'stroke-width="11" stroke-linecap="round" stroke-linejoin="round">{mark_paths()}</g></svg>'
    )


def render(svg):
    """Rasterises the SVG with Chrome, keeping transparency."""
    with tempfile.TemporaryDirectory() as tmp:
        page = os.path.join(tmp, "icon.html")
        shot = os.path.join(tmp, "icon.png")
        with open(page, "w", encoding="utf-8") as f:
            f.write(f'<!doctype html><html><body style="margin:0;background:transparent">{svg}</body></html>')
        subprocess.run(
            [
                chrome(),
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--default-background-color=00000000",
                "--force-device-scale-factor=1",
                f"--window-size={MASTER},{MASTER}",
                f"--user-data-dir={os.path.join(tmp, 'profile')}",
                f"--screenshot={shot}",
                "file:///" + page.replace(os.sep, "/"),
            ],
            check=True,
            capture_output=True,
        )
        return Image.open(shot).convert("RGBA").copy()


def save(image, path, size, *, opaque=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = image.resize((size, size), Image.LANCZOS)
    if opaque:
        out = out.convert("RGB")
    out.save(path, optimize=True)


def main():
    tile = render(icon_svg(background=True, mark_height=0.56))
    foreground = render(icon_svg(background=False, mark_height=0.44))
    notification = render(icon_svg(background=False, mark_height=0.84))

    for density, size in LAUNCHER_SIZES.items():
        save(tile, os.path.join(ANDROID_RES, f"mipmap-{density}", "ic_launcher.png"), size)
    for density, size in FOREGROUND_SIZES.items():
        save(foreground, os.path.join(ANDROID_RES, f"mipmap-{density}", "ic_launcher_foreground.png"), size)
    for density, size in NOTIFICATION_SIZES.items():
        save(notification, os.path.join(ANDROID_RES, f"drawable-{density}", "ic_notification.png"), size)

    anydpi = os.path.join(ANDROID_RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            "</adaptive-icon>\n"
        )
    with open(os.path.join(ANDROID_RES, "values", "colors.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            f'    <color name="ic_launcher_background">{TURQUOISE}</color>\n'
            "</resources>\n"
        )

    with open(os.path.join(IOS_SET, "Contents.json"), encoding="utf-8") as f:
        images = json.load(f)["images"]
    for entry in {i["filename"]: i for i in images if i.get("filename")}.values():
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        # iOS icons carry no alpha channel.
        save(tile, os.path.join(IOS_SET, entry["filename"]), round(points * scale), opaque=True)
    print("App icons written for Android and iOS.")


if __name__ == "__main__":
    main()
