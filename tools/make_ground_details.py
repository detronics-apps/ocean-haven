"""Draws the ground's little decorative details (assets/tilesets/ground_details.png), 64x64 per
tile like the ground art (shown at half size on the 32-px grid by TerrainEdges' "GroundDetails"
layer, which picks where they go). Each mark keeps inside its tile, with a dark outline.

Rows (columns = versions, or the frames of an animation):
 0 grass:  little grass patches
 1 sand:   a pink scallop, a white spiral shell, an orange starfish, two tiny shells
 2 mud:    bird tracks, boot prints, two mud clumps
 3 rock:   small stones
 4 ice:    two little dark rocks, a pebble, the snowman (one per icy island)
 5 waves rolling up the sand (4 frames; the water is above the tile: turned for other sides)
 6 waves breaking against rock (4 frames; the same)
Re-run after changing a detail:  python tools/make_ground_details.py
"""
import math
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'tilesets', 'ground_details.png')
S = 64
COLS, ROWS = 4, 7


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


class Cell:
    def __init__(self):
        self.px = {}

    def dot(self, x, y, c):
        if 0 <= x < S and 0 <= y < S:
            self.px[(int(x), int(y))] = rgb(c) if isinstance(c, str) else c

    def disc(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.dot(x, y, c)

    def outlined(self, dark='#2b2219'):
        """A dark line round everything drawn so far (the game's style)."""
        out = dict(self.px)
        for (x, y) in self.px:
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n not in self.px and 0 <= n[0] < S and 0 <= n[1] < S:
                    out[n] = rgb(dark)
        self.px = out
        return self


def grass(v, rnd):
    c = Cell()
    for _ in range(2 + v % 2):  # (a clump of blades, darker at the root)
        x0, y0 = rnd.randint(14, 46), rnd.randint(24, 52)
        for b in range(rnd.randint(4, 7)):
            h = rnd.randint(5, 10)
            lean = rnd.choice((-2, -1, 0, 1, 2))
            for k in range(h):
                col = '#4d6a2c' if k < 2 else ('#6f9440' if k < h - 2 else '#9cbd5e')
                c.dot(x0 + b * 2 + round(lean * k / h), y0 - k, col)
    if v == 3:  # (with a little yellow flower)
        c.dot(30, 26, '#f2d23a'); c.dot(31, 26, '#f2d23a'); c.dot(30, 27, '#c9a227')
    return c


def sand(v, rnd):
    c = Cell()
    x, y = rnd.randint(18, 40), rnd.randint(22, 40)
    if v == 0:  # (a pink scallop: a fan with ribs)
        for i in range(7):
            a = math.pi * (0.15 + 0.7 * i / 6)
            for r in range(2, 8):
                c.dot(x + 8 + math.cos(a) * r, y + 8 - math.sin(a) * r, '#e9a9a6' if i % 2 else '#d78a8a')
        c.disc(x + 8, y + 9, 2, 1.2, '#c77979')
        c.outlined('#7a4448')
    elif v == 1:  # (a white spiral shell)
        c.disc(x + 6, y + 6, 5, 4, '#f3ede0')
        for t in range(18):
            a = t * 0.6
            r = 4 - t * 0.2
            c.dot(x + 6 + math.cos(a) * r, y + 6 + math.sin(a) * r * 0.8, '#bfae94')
        c.outlined('#6e604c')
    elif v == 2:  # (an orange starfish)
        for arm in range(5):
            a = -math.pi / 2 + arm * 2 * math.pi / 5
            for r in range(0, 8):
                w = 2 if r < 4 else 1
                for d in range(-w + 1, w):
                    c.dot(x + 8 + math.cos(a) * r - math.sin(a) * d, y + 8 + math.sin(a) * r + math.cos(a) * d,
                          '#f08a3c' if r < 6 else '#f6a85e')
        c.outlined('#7a3a14')
    else:  # (two tiny shells)
        c.disc(x + 3, y + 3, 2.5, 2, '#f0d9c8')
        c.disc(x + 13, y + 9, 2, 1.6, '#e6b8b0')
        c.outlined('#6e5a4c')
    return c


def mud(v, rnd):
    c = Cell()
    if v == 0:  # (bird tracks: a line of three-toed prints)
        for k in range(4):
            x, y = 14 + k * 10, 44 - k * 6 + (k % 2) * 3
            for a in (-0.6, 0, 0.6):
                for r in range(1, 5):
                    c.dot(x + math.sin(a) * r, y - math.cos(a) * r, '#4e3722')
            c.dot(x, y + 1, '#4e3722')
    elif v == 1:  # (boot prints)
        for k in range(3):
            x, y = 18 + k * 9, 46 - k * 10
            c.disc(x, y, 2.4, 3.6, '#553c25')
            c.disc(x + 4 * (1 if k % 2 else -1), y - 5, 2, 2.5, '#553c25')
    else:  # (mud clumps: round lumps, lit on top)
        for _ in range(1 + v - 2 + 1):
            x, y = rnd.randint(16, 44), rnd.randint(24, 48)
            r = rnd.randint(3, 5)
            c.disc(x, y, r, r * 0.75, '#6a4a2e')
            c.disc(x - 1, y - 1, r * 0.5, r * 0.35, '#94704c')
        c.outlined('#3a2817')
    return c


def rock(v, rnd):
    c = Cell()
    for _ in range(2 + v % 2):  # (small stones, lit on top)
        x, y = rnd.randint(14, 48), rnd.randint(20, 50)
        r = rnd.randint(2, 4)
        c.disc(x, y, r + 1, r * 0.7, '#7c7368')
        c.disc(x - 1, y - 1, r * 0.6, r * 0.35, '#a99f91')
    c.outlined('#3e3832')
    return c


def ice(v, rnd):
    c = Cell()
    if v < 2:  # (little dark rocks poking through)
        for _ in range(2):
            x, y = rnd.randint(16, 46), rnd.randint(24, 48)
            r = rnd.randint(2, 4)
            c.disc(x, y, r + 1, r * 0.7, '#5d5852')
            c.disc(x - 1, y - 1, r * 0.5, r * 0.3, '#8b857c')
        c.outlined('#2c2a28')
    elif v == 2:  # (a pebble frozen in)
        c.disc(32, 36, 3, 2, '#6b6560')
        c.outlined('#2c2a28')
    else:  # (the snowman)
        c.disc(32, 48, 9, 8, '#f7fbff')
        c.disc(32, 34, 7, 6.5, '#f7fbff')
        c.disc(32, 23, 5.5, 5, '#f7fbff')
        for y in range(40, 56):  # (shade down the right side)
            for x in range(32, 42):
                if (x, y) in c.px and x - 32 > 4:
                    c.dot(x, y, '#d6e3ee')
        c.dot(30, 22, '#1c1c22'); c.dot(34, 22, '#1c1c22')  # (coal eyes)
        for k in range(4):
            c.dot(33 + k, 25, '#e8782c')  # (a carrot nose)
        for y in (32, 36, 40):
            c.dot(32, y, '#1c1c22')  # (buttons)
        c.outlined('#5a6c7c')
    return c


def wave_frame(f):
    """Foam rolling down onto the sand from the water above, then soaking away: a curve that
    starts and ends at the water's edge (the owner: no dead stop at the tile's sides), fading
    out towards its ends."""
    c = Cell()
    reach = [4, 10, 15, 13][f]
    alpha = [255, 255, 200, 110][f]
    for x in range(2, S - 2):
        u = (x - 2) / (S - 5)  # (0 .. 1 across)
        bulge = math.sin(math.pi * u)  # (0 at both ends, 1 in the middle)
        edge = round(reach * bulge + math.sin(x / 5.0 + f) * 0.8 * bulge)
        fade = min(1.0, bulge * 2.2)  # (the ends fade out)
        for y in range(0, edge):  # (wet sand behind the foam)
            c.dot(x, y, (150, 128, 90, int(70 * fade)))
        for y in range(edge, edge + (2 if f < 3 else 1)):
            c.dot(x, y, (250, 252, 255, int(alpha * fade)))
        if f in (1, 2) and x % 9 in (0, 1):
            c.dot(x, edge + 2, (250, 252, 255, int(alpha * fade) // 2))
    return c


def splash_frame(f):
    """A wave breaking on the rock's edge (the water above): spray thrown up, falling back."""
    c = Cell()
    rnd = random.Random(7)
    drops = [(rnd.randint(2, 61), rnd.random()) for _ in range(26)]
    for x, k in drops:
        fade = min(1.0, math.sin(math.pi * x / (S - 1)) * 2.2)  # (fading out at the tile's sides)
        h = [2, 9, 6, 3][f] * (0.4 + k) * fade
        y = int(h)
        a = int([230, 255, 200, 110][f] * fade)
        c.dot(x, y, (250, 252, 255, a))
        if f in (1, 2):
            c.dot(x, y + 1, (250, 252, 255, a // 2))
    for x in range(S):  # (the foam line along the edge, fading at both ends)
        fade = min(1.0, math.sin(math.pi * x / (S - 1)) * 2.2)
        c.dot(x, 0, (250, 252, 255, int([200, 255, 180, 90][f] * fade)))
    return c


if __name__ == '__main__':
    sheet = Image.new('RGBA', (S * COLS, S * ROWS), (0, 0, 0, 0))
    rows = [grass, sand, mud, rock, ice]
    for r, draw in enumerate(rows):
        for v in range(COLS):
            for (x, y), col in draw(v, random.Random(100 * r + v)).px.items():
                sheet.putpixel((v * S + x, r * S + y), col)
    for f in range(4):
        for (x, y), col in wave_frame(f).px.items():
            sheet.putpixel((f * S + x, 5 * S + y), col)
        for (x, y), col in splash_frame(f).px.items():
            sheet.putpixel((f * S + x, 6 * S + y), col)
    sheet.save(OUT)
    print('ground details written to', os.path.normpath(OUT))
