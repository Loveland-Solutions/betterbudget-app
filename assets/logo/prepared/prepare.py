#!/usr/bin/env python3
"""Makes the app-ready art in this folder from the owner's vectors in ../Images.

Run it again after any of those vectors changes:

    python3 assets/logo/prepared/prepare.py

It needs `rsvg-convert` (brew install librsvg) to find where each drawing sits
on its page. Nothing here is fetched.

What it does to each picture (owner, 2026-10-08: "From those you should be able
to create the dark modes and everything you need"):

- crops the page to the drawing (the Savings pictures to a square, so all four
  sit the same way in a step);
- sets every navy to one navy and every green to one green, since the traced
  shapes differ a little from one to the next;
- writes a night copy: navy becomes near-white, green becomes the lighter green;
- takes out what the owner took out of the later pictures themselves: the "$"
  on the Safety net coin and the word on the debt ball (pictures 3 and 4 came
  with theirs already gone);
- drops leftovers of the tracing: specks with no area, and the sliver left in
  each round coin of picture 3;
- removes the drawing program's own notes from the file.

The logo's coins are left exactly as drawn.
"""

import re
import struct
import subprocess
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
IMAGES = HERE.parent / "Images"
BRAND = HERE.parents[2] / "app" / "assets" / "brand"
WORDMARK = BRAND / "wordmark.svg"

NAVY, GREEN = "#13305A", "#4DB594"
NIGHT_WHITE, NIGHT_GREEN = "#F7F9FC", "#5FC9A3"
# "Budget" on a light page: the logo's green is too faint for letters there.
WORD_GREEN_DAY = "#17825F"
SHADOW_DAY, SHADOW_NIGHT = "#b1b1b1", "#0A1A38"

FILL = re.compile(r'(fill\s*[:=]\s*"?)(#[0-9a-fA-F]{6})')
PATH = re.compile(r"<path\b[^>]*?/>", re.S)


def kind(color: str) -> str:
    r, g, b = (int(color[i : i + 2], 16) for i in (1, 3, 5))
    if r < 70 and g < 80 and b > 70:
        return "navy"
    if g > 150 and r < 120:
        return "green"
    if min(r, g, b) > 235:
        return "white"
    return "other"


def path_fill(tag: str) -> str:
    m = FILL.search(tag)
    return kind(m.group(2)) if m else "other"


def path_d(tag: str) -> str:
    return re.search(r'\bd="([^"]*)"', tag, re.S).group(1)


def without_editor_notes(svg: str) -> str:
    svg = re.sub(r"<!--.*?-->", "", svg, flags=re.S)
    svg = re.sub(r"<sodipodi:namedview\b.*?(?:/>|</sodipodi:namedview>)", "", svg, flags=re.S)
    svg = re.sub(r'\s+(?:inkscape|sodipodi):[\w-]+="[^"]*"', "", svg)
    svg = re.sub(r'\s+xmlns:(?:inkscape|sodipodi)="[^"]*"', "", svg)
    return re.sub(r"<defs\b[^>]*/>", "", svg)


def drop_paths(svg: str, gone) -> str:
    return PATH.sub(lambda m: "" if gone(m.group(0)) else m.group(0), svg)


def first_shape_only(svg: str, ids) -> str:
    """Keeps the outline of these paths and drops what was cut into them."""

    found = set()

    def fix(m):
        tag = m.group(0)
        hit = [i for i in ids if f'id="{i}"' in tag]
        if not hit:
            return tag
        found.update(hit)
        d = path_d(tag)
        parts = [p for p in re.split(r"(?=[mM])", d.strip()) if p.strip()]
        return tag.replace(d, parts[0].strip())

    out = PATH.sub(fix, svg)
    # A picture saved again from the drawing program can renumber its shapes.
    assert found == set(ids), f"shapes not found: {sorted(set(ids) - found)}"
    return out


def recolor(svg: str, colors: dict) -> str:
    return FILL.sub(lambda m: m.group(1) + colors.get(kind(m.group(2)), m.group(2)), svg)


def png_alpha_box(png: bytes):
    """The box around everything that isn't transparent, in pixels."""
    assert png[:8] == b"\x89PNG\r\n\x1a\n"
    pos, data, w, h = 8, b"", 0, 0
    while pos < len(png):
        n, tag = struct.unpack_from(">I4s", png, pos)
        body = png[pos + 8 : pos + 8 + n]
        if tag == b"IHDR":
            w, h, depth, ctype = struct.unpack_from(">IIBB", body)
            assert (depth, ctype) == (8, 6), "expected 8-bit RGBA"
        elif tag == b"IDAT":
            data += body
        pos += 12 + n
    raw = zlib.decompress(data)
    stride, prev = w * 4, bytearray(w * 4)
    x0, y0, x1, y1 = w, h, -1, -1
    for y in range(h):
        f = raw[y * (stride + 1)]
        row = bytearray(raw[y * (stride + 1) + 1 : (y + 1) * (stride + 1)])
        if f == 1:
            for i in range(4, stride):
                row[i] = (row[i] + row[i - 4]) & 255
        elif f == 2:
            for i in range(stride):
                row[i] = (row[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                left = row[i - 4] if i >= 4 else 0
                row[i] = (row[i] + ((left + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = row[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                row[i] = (row[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        alpha = row[3::4]
        if any(alpha):
            xs = [x for x in range(w) if alpha[x] > 8]
            if xs:
                x0, x1 = min(x0, xs[0]), max(x1, xs[-1])
                y0, y1 = min(y0, y), max(y1, y)
        prev = row
    return w, h, x0, y0, x1 + 1, y1 + 1


def cropped(svg: str, square: bool, pad: float) -> str:
    """Sets the page to the drawing, with a little room around it."""
    head = re.search(r"<svg\b.*?>", svg, re.S).group(0)
    vb = [float(v) for v in re.search(r'viewBox="([^"]*)"', head).group(1).split()]
    png = subprocess.run(
        ["rsvg-convert", "-w", "640", "-"], input=svg.encode(), capture_output=True, check=True
    ).stdout
    w, h, x0, y0, x1, y1 = png_alpha_box(png)
    k = vb[2] / w
    bx, by, bw, bh = vb[0] + x0 * k, vb[1] + y0 * k, (x1 - x0) * k, (y1 - y0) * k
    if square:
        side = max(bw, bh) * (1 + 2 * pad)
        bx, by, bw, bh = bx + bw / 2 - side / 2, by + bh / 2 - side / 2, side, side
    else:
        px, py = bw * pad, bh * pad
        bx, by, bw, bh = bx - px, by - py, bw + 2 * px, bh + 2 * py
    new = re.sub(r'\s+(?:width|height|viewBox)="[^"]*"', "", head)
    new = new.replace(
        "<svg", f'<svg width="{bw:.2f}" height="{bh:.2f}" viewBox="{bx:.2f} {by:.2f} {bw:.2f} {bh:.2f}"', 1
    )
    return svg.replace(head, new, 1)


def write(name: str, svg: str) -> None:
    (HERE / name).write_text(svg)
    print(f"  {name}  {len(svg) // 1024} KB")


def savings(source: str, name: str, *, drop_white=False, outline_only=(), drop_specks=False) -> None:
    svg = without_editor_notes((IMAGES / source).read_text())
    if drop_white:
        svg = drop_paths(svg, lambda t: path_fill(t) == "white")
    if drop_specks:
        svg = drop_paths(svg, lambda t: len(path_d(t)) < 100)
    svg = first_shape_only(svg, outline_only)
    odd = sorted({m.group(2) for m in FILL.finditer(svg) if kind(m.group(2)) == "other"})
    assert not odd, f"{source}: neither navy, green nor white: {odd}"
    svg = cropped(svg, square=True, pad=0.03)
    write(f"{name}.svg", recolor(svg, {"navy": NAVY, "green": GREEN, "white": "#FFFFFF"}))
    # A white detail on a navy shape (the pig's eye) turns navy on the white pig.
    write(f"{name}-night.svg", recolor(svg, {"navy": NIGHT_WHITE, "green": NIGHT_GREEN, "white": NAVY}))


def logo() -> None:
    svg = without_editor_notes((IMAGES / "Better_Budget_Logo_Light_Mode.svg").read_text())
    svg = cropped(svg, square=False, pad=0.01)
    letters = lambda s, navy, green: s.replace("fill:#133059", f"fill:{navy}").replace(
        "fill:#50b993", f"fill:{green}"
    )
    assert "fill:#133059" in svg and "fill:#50b993" in svg and f"fill:{SHADOW_DAY}" in svg
    write("logo.svg", letters(svg, NAVY, GREEN))
    write(
        "logo-night.svg",
        letters(svg, NIGHT_WHITE, NIGHT_GREEN).replace(f"fill:{SHADOW_DAY}", f"fill:{SHADOW_NIGHT}"),
    )


def wordmark() -> None:
    """The app's own "BetterBudget" word (owner, 2026-10-08: keep it, in the new colors).
    Its first color is "Better" and its second "Budget", whatever they are now."""
    svg = without_editor_notes(WORDMARK.read_text())
    seen = list(dict.fromkeys(m.group(2).lower() for m in FILL.finditer(svg)))
    assert len(seen) == 2, seen
    two = lambda better, budget: FILL.sub(
        lambda m: m.group(1) + (better if m.group(2).lower() == seen[0] else budget), svg
    )
    write("wordmark.svg", two(NAVY, WORD_GREEN_DAY))
    write("wordmark-night.svg", two(NIGHT_WHITE, NIGHT_GREEN))


def main() -> None:
    print(f"Writing to {HERE}")
    logo()
    wordmark()
    savings("Savings_1_Safety_Net_Light_Mode.svg", "savings-safety-net", drop_white=True)
    savings(
        "Savings_2_Eliminate_Debt_Light_Mode.svg",
        "savings-eliminate-debt",
        drop_white=True,
        outline_only=("path2",),
    )
    savings(
        "Savings_3_Three_to_6_Month_Light_Mode.svg",
        "savings-three-to-six-months",
        outline_only=("path3", "path5"),
    )
    savings("Savings_4_Save_for_the_future_Light_Mode.svg", "savings-save-for-the-future", drop_specks=True)
    # What the app draws today: the sidebar is dark in every color scheme, so it
    # shows the night logo and word. The day word is kept beside it as the source
    # the next run reads.
    # The Savings page draws each step's picture, the night copy on a dark page.
    steps = ("safety-net", "eliminate-debt", "three-to-six-months", "save-for-the-future")
    for made, used in (
        ("logo-night.svg", "mark-dark.svg"),
        ("wordmark-night.svg", "wordmark-dark.svg"),
        ("wordmark.svg", "wordmark.svg"),
        *((f"savings-{s}{n}.svg",) * 2 for s in steps for n in ("", "-night")),
    ):
        (BRAND / used).write_text((HERE / made).read_text())
        print(f"  -> app/assets/brand/{used}")


if __name__ == "__main__":
    sys.exit(main())
