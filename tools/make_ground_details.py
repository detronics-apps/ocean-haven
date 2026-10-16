"""Draws the ground's little decorative details (assets/tilesets/ground_details.png), 64x64 per
tile like the ground art (shown at half size on the 32-px grid by TerrainEdges' "GroundDetails"
layer, which picks where they go). Each mark keeps inside its tile, with a dark outline.

Rows (columns = versions, or the frames of an animation):
 0 grass:  little grass patches
 1 sand:   a pink scallop, a white spiral shell, an orange starfish, two tiny shells
 2 mud:    bird tracks, boot prints, two mud clumps
 3 rock:   small stones
 4 ice:    two little dark rocks, a pebble, the snowman (one per icy island)
 5 waves rolling up the sand and sliding back (8 frames; the water is above the tile: turned
   for other sides)
 6 waves smashing against rock (8 frames; the same)
 (a 9th, empty column: the pause before the next wave, its length picked per spot in the game)
Re-run after changing a detail:  python tools/make_ground_details.py
"""
import math
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'tilesets', 'ground_details.png')
S = 64
COLS, ROWS = 9, 7
WAVE_FRAMES = 8


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
    clumps = [(rnd.randint(14, 40), rnd.randint(26, 52)) for _ in range(2 + v % 2)]
    for x0, y0 in clumps:  # (a slightly darker patch of ground under each clump)
        c.disc(x0 + 7, y0 + 1, rnd.randint(6, 8), 2, '#758d4a')
    for x0, y0 in clumps:  # (blades a game pixel wide, lit on the left, darker at the root)
        for b in range(rnd.randint(4, 6)):
            h = rnd.randint(6, 11)
            lean = rnd.choice((-2, -1, 0, 1, 2))
            for k in range(h):
                lit, shade = (('#46622a', '#3e5825') if k < 2 else
                              ('#678f3a', '#5a7f33') if k < h - 3 else ('#a8c864', '#93b552'))
                x = x0 + b * 3 + round(lean * k / h)
                c.dot(x, y0 - k, lit)
                c.dot(x + 1, y0 - k, shade)
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
    """A wave running up onto the sand from the water above and sliding back (the owner): a curve
    that starts and ends at the water's edge, fully there only at its peak in the middle and
    fading away towards both sides; the wet sand it leaves fades as it pulls back."""
    c = Cell()
    reach = [2, 6, 10, 14, 15, 13, 9, 5][f]
    alpha = [150, 220, 255, 255, 230, 190, 150, 110][f]
    for x in range(2, S - 2):
        u = (x - 2) / (S - 5)  # (0 .. 1 across)
        bulge = math.sin(math.pi * u)  # (0 at both ends, 1 in the middle)
        edge = round(reach * bulge + math.sin(x / 5.0 + f) * 0.8 * bulge)
        # (full only at the peak, gone by the sides: nothing within 12 px of them, where the
        # coast's rounded corners curve away, then easing in; the owner)
        ramp = min(1.0, max(0.0, (min(x, S - 1 - x) - 12) / 18.0))
        fade = bulge ** 1.5 * ramp
        for y in range(0, edge):  # (wet sand behind the foam)
            c.dot(x, y, (150, 128, 90, int(70 * fade)))
        for y in range(edge, edge + (2 if f < 5 else 1)):
            c.dot(x, y, (250, 252, 255, int(alpha * fade)))
        if f in (2, 3, 4) and x % 9 in (0, 1):
            c.dot(x, edge + 2, (250, 252, 255, int(alpha * fade) // 2))
    return c


def side_fade(x):
    """1 in the middle of the tile, nothing within 12 px of its sides (where the coast's rounded
    corners curve away), easing in between (shared by the waves and the spray)."""
    ramp = min(1.0, max(0.0, (min(x, S - 1 - x) - 12) / 18.0))
    return math.sin(math.pi * x / (S - 1)) ** 1.5 * ramp


def splash_frame(f):
    """A wave smashing against the rock at one point (the water above; the owner: at points, not
    along the whole edge): a burst of foam where it hits, spray thrown up and out over the rock in
    a fan, then the drops falling back and fizzing away. Nothing near the tile's sides."""
    c = Cell()
    hit = 26  # (where it hits: a little off the middle, so turned tiles hit at different points)
    rnd = random.Random(7)
    burst = [1, 3, 5, 4, 3, 2, 1, 0][f]
    band_alpha = [150, 230, 255, 240, 190, 140, 90, 0][f]
    for x in range(hit - 10, hit + 11):
        near = 1.0 - abs(x - hit) / 11.0
        for y in range(round(burst * near) + (1 if burst else 0)):
            c.dot(x, y, (250, 252, 255, int(band_alpha * near)))
    # (spray: drops thrown out in a fan from the hit, up over the rock, and falling back)
    drops = [(rnd.uniform(-1.0, 1.0), rnd.uniform(0.4, 1.0)) for _ in range(34)]
    travel = [0, 0, 6, 11, 14, 15, 15, 15][f]
    fall = [0, 0, 0, 0, 2, 4, 6, 8][f]
    alpha = [0, 0, 255, 255, 220, 160, 100, 50][f]
    for spread, power in drops:
        if alpha == 0:
            continue
        x = hit + spread * travel * 1.1
        y = travel * power * (1.0 - abs(spread) * 0.5) - fall * power * 0.5
        if y < 0:
            continue
        a = int(alpha * (1.0 - abs(spread) * 0.4))
        c.dot(round(x), round(y), (250, 252, 255, a))
        if f in (2, 3) and power > 0.7:
            c.dot(round(x - spread), round(y) - 1, (250, 252, 255, a // 2))  # (a streak as it flies)
    return c


if __name__ == '__main__':
    sheet = Image.new('RGBA', (S * COLS, S * ROWS), (0, 0, 0, 0))
    rows = [grass, sand, mud, rock, ice]
    for r, draw in enumerate(rows):
        for v in range(8):
            for (x, y), col in draw(v, random.Random(100 * r + v)).px.items():
                sheet.putpixel((v * S + x, r * S + y), col)
    for f in range(WAVE_FRAMES):
        for (x, y), col in wave_frame(f).px.items():
            sheet.putpixel((f * S + x, 5 * S + y), col)
    for f in range(WAVE_FRAMES):
        for (x, y), col in splash_frame(f).px.items():
            sheet.putpixel((f * S + x, 6 * S + y), col)
    sheet.save(OUT)
    print('ground details written to', os.path.normpath(OUT))
