"""Draws the young birds' flying and sitting pictures (AnimalData.young_flying_sprites /
young_sitting_sprites) from the grown bird's own flying and sitting drawings, recoloured in
the colours of that young bird's standing picture (baby and young each), then outlines them
like every placeholder sprite (tools/outline_sprites.py).

The recolouring maps the grown bird's body colours, the biggest first, onto the young one's;
the darkest pixels (eyes, wing tips) stay as they are.

    python3 tools/make_young_birds.py
Then: godot --headless --path . --import
"""
import colorsys
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import outline_sprites  # noqa: E402

## folder, the grown bird's flying picture, its sitting picture, its standing picture (whose
## main colours are the ones recoloured), the file name start.
BIRDS = [
    ("assets/animals/seabird", "red_footed_booby.svg", "red_footed_booby_perched.svg", "red_footed_booby_standing.svg", "red_footed_booby"),
    ("assets/animals/cormorant", "cormorant.svg", "cormorant_perched.svg", "cormorant_standing.svg", "cormorant"),
    ("assets/animals/tern", "arctic_tern.svg", "arctic_tern_sitting.svg", "arctic_tern_standing.svg", "arctic_tern"),
    ("assets/animals/skua", "arctic_skua.svg", "arctic_skua_sitting.svg", "arctic_skua_standing.svg", "arctic_skua"),
    ("assets/animals/flamingo", "american_flamingo_flying.svg", "american_flamingo_sitting.svg", "american_flamingo.svg", "american_flamingo"),
]
## A colour covering at least this share of a standing bird is a body colour (not a beak, legs, eye).
BODY_SHARE = 0.12
## Darker than this stays as drawn (eyes, black tips).
KEEP_BELOW = 0.16


def art_of(path: str):
    text = open(path).read()
    kept = re.search(r'<g id="art" data-size="([\d.]+) ([\d.]+)" data-box="([^"]+)">(.*)</g>\s*</svg>\s*$', text, re.S)
    return kept.group(1), kept.group(2), kept.group(3), re.sub(r"<!--.*?-->", "", kept.group(4), flags=re.S)


def lightness(hex_colour: str) -> float:
    h = hex_colour.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)[1]


def colours(art: str) -> list:
    """The body colours of a standing bird, the one covering most of it first."""
    area = {}
    for w, h, c in re.findall(r'width="([\d.]+)" height="([\d.]+)" fill="(#[0-9a-fA-F]{3,6})"', art):
        area[c.lower()] = area.get(c.lower(), 0.0) + float(w) * float(h)
    total = sum(area.values()) or 1.0
    found = [c for c in area if area[c] / total >= BODY_SHARE and lightness(c) >= KEEP_BELOW]
    return sorted(found, key=lambda c: area[c], reverse=True)


def recolour(art: str, own: list, palette: list) -> str:
    """The grown bird's body colours (`own`) become the young one's (`palette`); the rest stays."""
    if not own or not palette:
        return art
    mapping = {}
    for i, c in enumerate(own):
        j = round(i * (len(palette) - 1) / max(len(own) - 1, 1))
        mapping[c] = palette[j]

    def swap(colour: str) -> str:  # (the nearest body colour, if it's close: drawings vary a shade)
        near = min(own, key=lambda c: distance(c, colour))
        return mapping[near] if distance(near, colour) < CLOSE else colour
    return re.sub(r'fill="(#[0-9a-fA-F]{3,6})"', lambda m: f'fill="{swap(m.group(1).lower())}"', art)


## How near two colours must be (0..441, straight-line RGB) to count as the same body colour.
CLOSE = 60.0


def rgb(hex_colour: str) -> tuple:
    h = hex_colour.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def distance(a: str, b: str) -> float:
    return sum((x - y) ** 2 for x, y in zip(rgb(a), rgb(b))) ** 0.5


def write(path: str, w: str, h: str, box: str, art: str) -> None:
    open(path, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{box}" '
                          f'shape-rendering="crispEdges">{art}</svg>\n')
    outline_sprites.process(path)


if __name__ == "__main__":
    made = 0
    for folder, flying, sitting, standing, name in BIRDS:
        own = colours(art_of(os.path.join(ROOT, folder, standing))[3])
        for stage in ["baby", "young"]:
            palette = colours(art_of(os.path.join(ROOT, folder, f"{name}_{stage}.svg"))[3])
            for pose, source in [("flying", flying), ("sitting", sitting)]:
                w, h, box, art = art_of(os.path.join(ROOT, folder, source))
                write(os.path.join(ROOT, folder, f"{name}_{stage}_{pose}.svg"), w, h, box, recolour(art, own, palette))
                made += 1
    print(f"{made} young bird pictures made")
