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
    if len(palette) < len(own):
        # (a young one of fewer colours, like a sooty cormorant chick: its other tones are its
        # main colour made lighter or darker as the grown bird's are, so it keeps its shading)
        main = rgb(palette[0])
        base = max(lightness(own[0]), 0.05)
        for c in own[len(palette):]:
            f = lightness(c) / base
            f = f if abs(f - 1.0) >= 0.18 else (1.25 if f >= 1.0 else 0.8)
            palette.append("#%02x%02x%02x" % tuple(max(0, min(255, round(v * f + (12 if f > 1 else 0)))) for v in main))
    mapping = {}
    for i, c in enumerate(own):
        j = round(i * (len(palette) - 1) / max(len(own) - 1, 1))
        mapping[c] = palette[j]

    def target(colour: str):  # (the nearest body colour's, if it's close: drawings vary a shade)
        near = min(own, key=lambda c: distance(c, colour))
        return mapping[near] if distance(near, colour) < CLOSE else None
    # The drawing's own shading is kept: of the colours that become one young colour, the most
    # used becomes it, and the others are made as much lighter or darker as they are (the owner:
    # a sooty cormorant chick flying was one flat tone).
    used = {}
    for c in re.findall(r'fill="(#[0-9a-fA-F]{3,6})"', art):
        used[c.lower()] = used.get(c.lower(), 0) + 1
    groups = {}
    for c in used:
        t = target(c)
        if t:
            groups.setdefault(t, []).append(c)
    final = {}
    for t, members in groups.items():
        main = max(members, key=lambda c: used[c])
        for c in members:
            f = lightness(c) / max(lightness(main), 0.05)
            if c == main:
                final[c] = t
            else:
                f = f if abs(f - 1.0) >= 0.12 else (1.12 if f > 1.0 else 0.88)
                final[c] = "#%02x%02x%02x" % tuple(max(0, min(255, round(v * f + (14 if f > 1 else 0)))) for v in rgb(t))
    return re.sub(r'fill="(#[0-9a-fA-F]{3,6})"', lambda m: f'fill="{final.get(m.group(1).lower(), m.group(1))}"', art)


## How near two colours must be (0..441, straight-line RGB) to count as the same body colour.
CLOSE = 60.0


def rgb(hex_colour: str) -> tuple:
    h = hex_colour.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def distance(a: str, b: str) -> float:
    return sum((x - y) ** 2 for x, y in zip(rgb(a), rgb(b))) ** 0.5


## Babies with a shape of their own (the owner: a flamingo chick is tiny and fat, not a thin grown
## bird): sitting drawn from its own standing picture, legs tucked under; no flying picture (a
## chick can't fly yet: the data uses its standing one).
OWN_BABY_SITTING = {
    "american_flamingo": ("10", "9", "0 0 10 9", """
  <!-- American flamingo chick, sitting: grey-white fluffy down, legs tucked under -->
  <rect x="1" y="4" width="7" height="4" fill="#d6d4d0"/>
  <rect x="2" y="5" width="5" height="2" fill="#e6e4e0"/>
  <rect x="5" y="1" width="4" height="4" fill="#d6d4d0"/>
  <rect x="7" y="2" width="1" height="1" fill="#1e1a14"/>
  <rect x="9" y="2" width="1" height="2" fill="#3a3434"/>
  <rect x="2" y="8" width="5" height="1" fill="#c88a8a"/>
"""),
}


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
                if stage == "baby" and name in OWN_BABY_SITTING:
                    if pose == "sitting":
                        write(os.path.join(ROOT, folder, f"{name}_baby_sitting.svg"), *OWN_BABY_SITTING[name])
                        made += 1
                    continue
                w, h, box, art = art_of(os.path.join(ROOT, folder, source))
                write(os.path.join(ROOT, folder, f"{name}_{stage}_{pose}.svg"), w, h, box, recolour(art, own, palette))
                made += 1
    print(f"{made} young bird pictures made")
