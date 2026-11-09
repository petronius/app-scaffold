"""Writes the three app icon SVGs (default, dark, tinted) into the directory given.

PLACEHOLDER artwork: a 3 x 3 grid of rounded squares with the centre one in the
accent colour, on a slate background. Replace it with the app's own icon (see
README.md in this folder); keep the three variants and the 1024 square canvas.
"""
import os
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
S = 1024                 # canvas size
CELL = 180               # square size
GAP = 44                 # space between squares
RADIUS = 40              # corner radius of each square
INK = "#F2F4F7"          # the squares
ACCENT = "#4F8EF7"       # the centre square
TOP, BOTTOM = "#3A4556", "#1C222C"   # background gradient

def squares(ink, accent):
    span = 3 * CELL + 2 * GAP
    origin = (S - span) // 2
    out = []
    for row in range(3):
        for col in range(3):
            x = origin + col * (CELL + GAP)
            y = origin + row * (CELL + GAP)
            fill = accent if (row, col) == (1, 1) else ink
            out.append(f'<rect x="{x}" y="{y}" width="{CELL}" height="{CELL}" rx="{RADIUS}" fill="{fill}"/>')
    return "".join(out)

def doc(background, ink, accent):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">'
            f'{background}{squares(ink, accent)}</svg>\n')

BACKGROUND = ('<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
              f'<stop offset="0" stop-color="{TOP}"/><stop offset="1" stop-color="{BOTTOM}"/>'
              f'</linearGradient></defs><rect width="{S}" height="{S}" fill="url(#bg)"/>')

variants = {
    # Full colour: the default iPhone and iPad icon, and the watch icon.
    "AppIcon.svg": doc(BACKGROUND, INK, ACCENT),
    # iOS dark appearance: transparent, the system supplies the background.
    "AppIcon-dark.svg": doc("", INK, ACCENT),
    # iOS tinted appearance: greyscale on transparent, the system tints by luminance.
    "AppIcon-tinted.svg": doc("", "#FFFFFF", "#9A9A9A"),
}
for name, svg in variants.items():
    with open(os.path.join(OUT, name), "w") as f:
        f.write(svg)
print("wrote " + ", ".join(variants))
