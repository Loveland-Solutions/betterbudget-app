#!/usr/bin/env python3
"""Makes the app icons: the logo's night form on a navy tile, for macOS and Windows.

The owner asked for "a nice one with the new icon" (2026-10-09). The tile is
the logo's own navy, the sidebar's, lit a little from above; the logo is the
form drawn for dark ground (white B, green B, the coins), so it is still a
light shape when macOS's dark style turns every tile charcoal. Before this:
the logo on a white tile (2026-10-08), and before that the bee.

Run from the repo root; needs rsvg-convert (`brew install librsvg`) and sips:
    python3 design/icon/app_icon.py
It writes the PNGs into app/macos/Runner/Assets.xcassets/AppIcon.appiconset and
app/windows/runner/resources/app_icon.ico. Windows draws an icon as it is, with no
margin of its own and no shadow, so its tile fills the square and casts none.
"""
import pathlib
import shutil
import struct
import subprocess

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
LOGO = ROOT / "assets/logo/prepared/logo-night.svg"
ICONSET = ROOT / "app/macos/Runner/Assets.xcassets/AppIcon.appiconset"
ICO = ROOT / "app/windows/runner/resources/app_icon.ico"

# The tile macOS expects inside a 1024 canvas, and the logo's height in it:
# 620 makes the logo 61% of the tile wide, with room for the coins' shadow.
MAC = dict(TILE=824, AT=100, RADIUS=185, LOGO_H=620, SHADOW=True)
# Windows: the same tile and logo, grown to fill the square.
WINDOWS = dict(TILE=1000, AT=12, RADIUS=225, LOGO_H=752, SHADOW=False)


def svg(TILE, AT, RADIUS, LOGO_H, SHADOW):
    LOGO_W = LOGO_H * 489 / 600  # the logo's own proportions
    under_tile = 'filter="url(#under-tile)"' if SHADOW else ""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#1D4479"/>
      <stop offset="1" stop-color="#0E2445"/>
    </linearGradient>
    <radialGradient id="light" cx="0.5" cy="0" r="0.9">
      <stop offset="0" stop-color="#fff" stop-opacity="0.14"/>
      <stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </radialGradient>
    <filter id="under-tile" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="12"/>
      <feOffset dy="10"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.28"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="under-logo" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="9"/>
      <feOffset dy="8"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.22"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <rect x="{AT}" y="{AT}" width="{TILE}" height="{TILE}" rx="{RADIUS}" fill="url(#tile)" {under_tile}/>
  <rect x="{AT}" y="{AT}" width="{TILE}" height="{TILE}" rx="{RADIUS}" fill="url(#light)"/>
  <rect x="{AT + 1}" y="{AT + 1}" width="{TILE - 2}" height="{TILE - 2}" rx="{RADIUS - 1}" fill="none" stroke="#fff" stroke-opacity="0.10" stroke-width="2"/>
  <image xlink:href="logo-night.svg" x="{512 - LOGO_W / 2:.1f}" y="{512 - LOGO_H / 2:.1f}" width="{LOGO_W:.1f}" height="{LOGO_H}" filter="url(#under-logo)"/>
</svg>
"""


def write_ico(pngs):
    """An .ico holding each size as a PNG, which Windows reads since Vista."""
    header = struct.pack("<HHH", 0, 1, len(pngs))
    offset = len(header) + 16 * len(pngs)
    entries, data = b"", b""
    for size, png in pngs:
        side = 0 if size >= 256 else size  # 0 means 256
        entries += struct.pack(
            "<BBBBHHII", side, side, 0, 0, 1, 32, len(png), offset + len(data)
        )
        data += png
    ICO.write_bytes(header + entries + data)


def main():
    # rsvg-convert only loads an image that sits beside the SVG naming it.
    beside = HERE / "logo-night.svg"
    mac_svg = HERE / "app_icon.svg"
    win_svg = HERE / "app_icon_windows.svg"
    shutil.copyfile(LOGO, beside)
    mac_svg.write_text(svg(**MAC))
    win_svg.write_text(svg(**WINDOWS))
    try:
        big = ICONSET / "app_icon_1024.png"
        subprocess.run(
            ["rsvg-convert", "-w", "1024", str(mac_svg), "-o", str(big)], check=True
        )
        for size in (16, 32, 64, 128, 256, 512):
            small = ICONSET / f"app_icon_{size}.png"
            subprocess.run(
                ["sips", "-z", str(size), str(size), str(big), "--out", str(small)],
                check=True,
                capture_output=True,
            )
        # Each Windows size drawn from the vector, not shrunk from a bitmap.
        pngs = [
            (size, subprocess.run(
                ["rsvg-convert", "-w", str(size), str(win_svg)],
                check=True, capture_output=True,
            ).stdout)
            for size in (16, 20, 24, 32, 40, 48, 64, 256)
        ]
        write_ico(pngs)
    finally:
        beside.unlink()
        mac_svg.unlink()
        win_svg.unlink()


if __name__ == "__main__":
    main()
