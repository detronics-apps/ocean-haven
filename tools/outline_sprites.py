"""Gives the placeholder sprites one consistent look: a 1-pixel outline round every shape, in
a darker shade of that shape's own colour (a "selective outline", as SNES-era cosy pixel art
does), so animals, buildings and items read clearly on sand, grass and water alike.

The picture grows by 1 px on every side (the viewBox moves out, so its middle stays put).
Re-running it is safe: the outline is rebuilt from the original drawing kept in <g id="art">.
Half-see-through shapes (shadows, water) get no outline.

    python3 tools/outline_sprites.py              # every folder in FOLDERS
    python3 tools/outline_sprites.py assets/animals/seal/ringed_seal.svg
Then: godot --headless --path . --import
"""
import colorsys
import glob
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FOLDERS = ["assets/animals", "assets/buildings", "assets/boats", "assets/items", "assets/environment", "assets/effects"]
## Pieces laid edge to edge (an outline would show a seam between them).
SKIP = ["dock_plank.svg", "drawbridge_closed.svg", "drawbridge_open.svg"]
OFFSETS = [(-1, 0), (1, 0), (0, -1), (0, 1)]
NAMED = {"white": "#ffffff", "black": "#000000"}


def darker(hex_colour: str) -> str:
    h = NAMED.get(hex_colour.lower(), hex_colour).lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
    # Darker and a touch cooler: outlines of pale things stay soft, never pure black.
    r, g, b = colorsys.hsv_to_rgb(hue, min(1.0, sat * 1.15 + 0.08), val * 0.42 + 0.06)
    b = min(1.0, b + 0.04)
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))


def outline_copy(art: str) -> str:
    art = re.sub(r"<!--.*?-->", "", art, flags=re.S)
    # No outline for half-see-through shapes (a self-closing tag with an opacity below 1).
    art = re.sub(r'<[a-z]+\b[^>]*(?:fill-)?opacity="0?\.\d+"[^>]*/>', "", art)
    return re.sub(r'(fill|stroke)="(#[0-9a-fA-F]{3,6}|white|black)"', lambda m: f'{m.group(1)}="{darker(m.group(2))}"', art)


def process(path: str) -> bool:
    text = open(path).read()
    head = re.match(r"\s*(<svg\b[^>]*>)", text, re.S)
    if not head:
        return False
    svg_tag = head.group(1)
    kept = re.search(r'<g id="art" data-size="([\d.]+) ([\d.]+)" data-box="([^"]+)">(.*)</g>\s*</svg>\s*$', text, re.S)
    if kept:
        w, h, box, art = float(kept.group(1)), float(kept.group(2)), kept.group(3), kept.group(4)
    else:
        w = float(re.search(r'\bwidth="([\d.]+)"', svg_tag).group(1))
        h = float(re.search(r'\bheight="([\d.]+)"', svg_tag).group(1))
        box_match = re.search(r'viewBox="([^"]+)"', svg_tag)
        box = box_match.group(1) if box_match else f"0 0 {w:g} {h:g}"
        art = text[head.end():text.rindex("</svg>")]
    bx, by, bw, bh = (float(v) for v in box.split())
    px = bw / w  # one screen pixel in viewBox units
    py = bh / h
    new_tag = svg_tag
    new_tag = re.sub(r'\bwidth="[\d.]+"', f'width="{w + 2:g}"', new_tag, count=1)
    new_tag = re.sub(r'\bheight="[\d.]+"', f'height="{h + 2:g}"', new_tag, count=1)
    new_box = f"{bx - px:g} {by - py:g} {bw + 2 * px:g} {bh + 2 * py:g}"
    new_tag = re.sub(r'viewBox="[^"]+"', f'viewBox="{new_box}"', new_tag) if 'viewBox="' in new_tag \
        else new_tag.replace("<svg", f'<svg viewBox="{new_box}"', 1)
    line = outline_copy(art)
    rings = "".join(f'<g transform="translate({dx * px:g} {dy * py:g})">{line}</g>' for dx, dy in OFFSETS)
    out = (f'{new_tag}\n  <!-- outline: made by tools/outline_sprites.py from the drawing in "art" -->\n'
           f'  <g id="outline">{rings}</g>\n'
           f'  <g id="art" data-size="{w:g} {h:g}" data-box="{box}">{art}</g>\n</svg>\n')
    if out != text:
        open(path, "w").write(out)
        return True
    return False


if __name__ == "__main__":
    files = sys.argv[1:] or [f for folder in FOLDERS for f in glob.glob(os.path.join(ROOT, folder, "**", "*.svg"), recursive=True)]
    files = [f for f in files if os.path.basename(f) not in SKIP]
    changed = sum(process(f) for f in files)
    print(f"{changed} of {len(files)} sprites outlined")
