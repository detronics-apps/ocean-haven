"""Draws the ground as pixel art matched to the owner's terrain sheet (docs/terrain_sheet.jpg):
64x64 pictures per 32x32 tile (the sheet's fine lines are half a game pixel wide), shown on the
same grid by TerrainEdges' art layer at half size. Each ground has the sheet's colours, as many
marks and as much contrast as the sheet's tile (measured: how much of it is lighter or darker
than its base, and by how much), and VARIANTS versions made up differently (picked per cell,
some mirrored) so there's no repeating pattern; every mark keeps inside its own tile, so any
version sits beside any other without a seam.

- shallow and mid water: a very faint speckle only (the moving white waves play over all water);
- sand: grains, soft blotches, light specks, a band of grains, now and then pink shells;
- grass: tufts of thin upright blades, dark and light, yellow and orange flowers (no white);
- rock: long cracks with a light edge and a branch, pale flat patches, pebble clusters;
- ice: long branching cracks, white with a pale blue shadow, or pale blue;
- mud: pebbles (a pale highlight, a dark rim), rings where puddles were, pale specks;

Writes assets/tilesets/terrain_art.png (a row per ground, in the tileset's order: shallow, sand,
grass, rock, ice, mud, mid water; a column per version) and assets/tilesets/terrain_tiles.png
(the 32x32 tiles of the Ground layer itself, which only the game's logic, the minimap and the
rounded edges' colours use: each ground's first version at half size). Deep water is no tile.
Re-run after changing a ground:  python tools/make_terrain_tiles.py
"""
import math
import os
import random
from PIL import Image

HERE = os.path.dirname(__file__)
ART = os.path.join(HERE, '..', 'assets', 'tilesets', 'terrain_art.png')
TILES = os.path.join(HERE, '..', 'assets', 'tilesets', 'terrain_tiles.png')
DEEP = os.path.join(HERE, '..', 'assets', 'tilesets', 'deep_water.png')
S = 64  # (pixels per tile in the art: a game pixel is 2 of them)
VARIANTS = 8
MARGIN = 2  # (marks keep this far in from the tile's edges)


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


class Tile:
    def __init__(self, base, rnd, speckle):
        self.im = Image.new('RGB', (S, S), rgb(base))
        for _ in range(S * S // 20 if speckle else 0):  # (a soft speckle all over, as on the sheet)
            self.dot(rnd.randrange(S), rnd.randrange(S), rgb(rnd.choice(speckle)))

    def dot(self, x, y, colour):
        if 0 <= x < S and 0 <= y < S:
            self.im.putpixel((int(x), int(y)), rgb(colour) if isinstance(colour, str) else colour)

    def line(self, points, colour, dx=0, dy=0):
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            steps = max(abs(x1 - x0), abs(y1 - y0), 1)
            for i in range(steps + 1):
                self.dot(round(x0 + (x1 - x0) * i / steps) + dx, round(y0 + (y1 - y0) * i / steps) + dy, colour)

    def box(self, x, y, w, h, colour):
        for dx in range(w):
            for dy in range(h):
                self.dot(x + dx, y + dy, colour)


def places(rnd, count, w=0, h=0):
    """`count` places for marks w x h big, spread over the tile (a jittered grid), inside it."""
    side = max(1, math.ceil(math.sqrt(count)))
    span = S - 2 * MARGIN
    cells = [(cx, cy) for cx in range(side) for cy in range(side)]
    rnd.shuffle(cells)
    out = []
    for cx, cy in cells[:count]:
        x = MARGIN + int((cx + rnd.random()) * span / side)
        y = MARGIN + int((cy + rnd.random()) * span / side)
        out.append((min(x, S - MARGIN - 1 - w), min(max(y, MARGIN + h), S - MARGIN - 1)))
    return out


def wave(t, rnd, x, y, length, light, dark, rise, under=(1, 2), tilt=0.0):
    phase = rnd.random() * math.pi
    pts = [(x + i, y - round(math.sin(phase + i / length * math.pi * 1.4) * rise + i * tilt)) for i in range(length)]
    t.line(pts[2:-1], dark, *under)
    t.line(pts, light)


def shallow(rnd, v):
    """No marks (the moving white waves, SeaWaves, play over all the water), only a very faint
    speckle so it isn't flat (the owner)."""
    return Tile('#578990', rnd, ['#5b8d94', '#54868d'])


def mid_water(rnd, v):
    return Tile('#3c5f72', rnd, ['#3f6276', '#3a5c6f'])


def sand(rnd, v):
    t = Tile('#e5d19e', rnd, ['#dcc893', '#ecd9a8'])
    for x, y in places(rnd, rnd.randint(14, 18), 4, 4):  # (soft blotches)
        n = rnd.choice((3, 4))
        t.box(x, y - n + 1, n, n, rnd.choice(['#d6c28d', '#ecdbab', '#dac793']))
    for x, y in places(rnd, rnd.randint(110, 140)):
        c = rnd.choice(['#c4ab79', '#cbb382', '#bea472'])
        t.dot(x, y, c)
        if rnd.random() < 0.3:
            t.dot(x + 1, y, c)
    for x, y in places(rnd, rnd.randint(8, 12)):
        t.dot(x, y, '#fdf3d8')
    if v % 2 == 0:  # (a band of grains running across)
        x0, y0, n = rnd.randint(6, 20), rnd.randint(40, 56), rnd.randint(16, 26)
        for i in range(n):
            if rnd.random() < 0.6:
                t.dot(x0 + i + rnd.randint(-1, 1), y0 - i * 0.7 + rnd.randint(-1, 1), '#c1a774')
    if v in (3, 6):  # (pink shells)
        x, y = places(rnd, 1, 10, 6)[0]
        for ox, oy in ((0, 0), (5, 3), (2, 6))[:rnd.randint(2, 3)]:
            t.box(x + ox, y - 6 + oy, 3, 3, '#c79a9b')
            t.dot(x + ox + 1, y - 6 + oy + 1, '#f2dedc')
            t.dot(x + ox + 2, y - 6 + oy + 2, '#a77c80')
    return t


def grass(rnd, v):
    t = Tile('#7f9652', rnd, ['#76904b', '#879d57'])
    for x, y in places(rnd, rnd.randint(18, 24), 8, 6):  # (tufts of thin blades)
        c = '#5e7637' if rnd.random() < 0.82 else '#a5b968'
        for b in range(rnd.randint(2, 4)):
            h = rnd.randint(3, 6)
            lean = rnd.choice((-1, 0, 0, 1))
            t.line([(x + b * 2, y), (x + b * 2 + lean, y - h)], c)
    for x, y in places(rnd, rnd.choice((0, 0, 0, 1, 1)), 2, 2):  # (a rare flower: the owner, too many)
        c = rnd.choice(['#f2d23a'] * 6 + ['#e8962c'])  # (no white: it read as static)
        t.box(x, y - 1, 2, 2, c)
    return t


def crack(t, rnd, x, y, length, colour, edge=None, step=(1, 1), dy=0, thick=False, branch=True):
    """A long thin crack wandering along `step`, with a branch; `edge` = a light pixel beside it."""
    pts = [(x, y)]
    for _ in range(length):
        nx = x + (step[0] if rnd.random() < 0.7 else 0)
        ny = y + (step[1] if rnd.random() < 0.8 else 0)
        if not (MARGIN <= nx < S - MARGIN and MARGIN <= ny < S - MARGIN):
            break
        x, y = nx, ny
        pts.append((x, y))
    if edge:
        t.line(pts[::2], edge, 1, 0)
    t.line(pts, colour, 0, dy)
    if thick:  # (twice as wide along its middle)
        t.line(pts[len(pts) // 4: 3 * len(pts) // 4], colour, 1, dy)
    if branch and len(pts) > 6:
        bx, by = pts[rnd.randint(len(pts) // 3, 2 * len(pts) // 3)]
        n = rnd.randint(4, 9)
        end = (min(max(bx - step[0] * n, MARGIN), S - MARGIN - 1), min(max(by + n // 2, MARGIN), S - MARGIN - 1))
        t.line([(bx, by), end], colour, 0, dy)


def rock(rnd, v):
    t = Tile('#8a8074', rnd, ['#80766b', '#938a7e'])
    for x, y in places(rnd, rnd.randint(3, 5), 8, 3):  # (pale flat patches)
        t.box(x, y - 2, rnd.randint(3, 7), rnd.randint(2, 3), rnd.choice(['#958b7e', '#9a9083']))
    for x, y in places(rnd, rnd.randint(2, 3), 0, 0):  # (a few thin cracks, softer than the sheet)
        step = rnd.choice(((1, 1), (-1, 1), (1, 1)))
        crack(t, rnd, x, y, rnd.randint(12, 24), '#6e655b', '#998f82', step, branch=rnd.random() < 0.3)
    for x, y in places(rnd, rnd.randint(0, 2), 6, 4):  # (pebble clusters)
        for dx, dy in rnd.sample(((0, 0), (3, 0), (1, 2), (4, 2), (0, 4), (5, 4)), 3):
            t.box(x + dx, y - 4 + dy, 2, 1, '#aaa092')
            t.dot(x + dx, y - 3 + dy, '#6e655b')
    return t


def ice(rnd, v):
    t = Tile('#e5eef3', rnd, ['#dfe8ef', '#edf3f7'])
    for i in range(rnd.randint(1, 2)):
        # (from near an edge, inwards and down, never all meeting in the middle)
        x = rnd.choice((rnd.randint(MARGIN, 14), rnd.randint(S - 15, S - MARGIN - 1), rnd.randint(16, S - 17)))
        y = rnd.randint(MARGIN, 20) if i == 0 else rnd.randint(20, 44)
        step = (1, 1) if x < S // 2 else (-1, 1)
        n = rnd.randint(16, 30)
        if rnd.random() < 0.7:
            state = rnd.getstate()
            crack(t, rnd, x, y, n, '#d2dee7', step=step, dy=1)  # (its pale blue shadow)
            rnd.setstate(state)
            crack(t, rnd, x, y, n, '#f6f9fb', step=step)
        else:
            crack(t, rnd, x, y, n, '#cfdbe5', step=step)
    return t


def mud(rnd, v):
    t = Tile('#78593a', rnd, ['#71533a', '#7e5f40'])
    for x, y in places(rnd, rnd.randint(2, 4), 4, 3):  # (pebbles: a pale top, a dark rim under)
        w = rnd.randint(2, 3)
        t.box(x, y - 2, w, 2, '#957a5a')
        t.box(x, y, w, 1, '#62482f')
        t.dot(x + w, y - 1, '#62482f')
        t.dot(x, y - 2, '#a98e6c')
    for x, y in places(rnd, 1 if v % 3 == 0 else 0, 12, 9):  # (now and then a ring where a puddle was)
        w, h = rnd.randint(10, 14), rnd.randint(7, 10)
        for i in range(48):
            a = i / 48 * math.tau
            px, py = x + w / 2 + math.cos(a) * w / 2, y - h / 2 + math.sin(a) * h / 2
            t.dot(round(px), round(py), '#8e7252' if math.sin(a) < 0.3 else '#674b31')
    for x, y in places(rnd, rnd.randint(4, 6)):
        t.dot(x, y, '#8a6f52')
    return t


if __name__ == '__main__':
    grounds = [shallow, sand, grass, rock, ice, mud, mid_water]
    art = Image.new('RGB', (S * VARIANTS, S * len(grounds)))
    tiles = Image.new('RGB', (32 * len(grounds), 32))
    for row, draw in enumerate(grounds):
        for v in range(VARIANTS):
            picture = draw(random.Random(1000 * row + v), v).im
            art.paste(picture, (S * v, S * row))
            if v == 0:
                tiles.paste(picture.resize((32, 32), Image.BOX), (32 * row, 0))
    art.save(ART)
    tiles.save(TILES)
    # The deep ocean has no tile: a faint speckle laid over it (SeaWaves), the owner's very subtle
    # texture on every water.
    deep = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    rnd = random.Random(77)
    for _ in range(S * S // 20):
        deep.putpixel((rnd.randrange(S), rnd.randrange(S)), rnd.choice([(255, 255, 255, 12), (0, 0, 0, 16)]))
    deep.save(DEEP)
    print('ground art written to', os.path.normpath(ART), 'and', os.path.normpath(TILES))
