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
    # (softer than the sheet: fewer tufts at less contrast, so the grass patches on top stand out;
    # the owner: halfway between the sheet's and a faded one)
    t = Tile('#7f9652', rnd, ['#78914c', '#859b55'])
    for x, y in places(rnd, rnd.randint(13, 18), 8, 6):  # (tufts of thin blades)
        c = '#667e3d' if rnd.random() < 0.82 else '#9bb062'
        for b in range(rnd.randint(2, 4)):
            h = rnd.randint(3, 5)
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


FACES = os.path.join(HERE, '..', 'assets', 'tilesets', 'terrain_faces.png')
FACE_H = 32  # (a face up to 16 game pixels tall; TerrainEdges.MAX_FACE)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def rock_face(rnd):
    """Two courses of stones (each lit on its left, shaded on its right, dark joints), a lit top
    edge and a dark wet foot (the picture's last 6 rows: TerrainEdges.FOOT)."""
    base = rgb('#8a8074')
    im = Image.new('RGB', (S, FACE_H))
    px = im.load()
    for top, bottom, widths, offset in ((0, 16, [14, 18, 12, 20], 0), (16, FACE_H, [16, 14, 18, 16], 8)):
        start = -offset
        for w in widths + widths[:1]:
            for X in range(start, start + w):
                cx = X - start
                f = 0.5 if cx >= w - 2 else 0.72 if cx >= w - 6 else 1.02 if cx < 2 else 0.86
                for y in range(top, bottom):
                    g = 0.5 if (y == 16 or y == 17) and cx < w - 2 else f
                    if y < 4:
                        g = 1.2  # (the top edge, catching the light)
                    elif y >= FACE_H - 6:
                        g = 0.5 if cx >= w - 2 else 0.6
                    elif g == 0.86 and rnd.random() < 0.06:
                        g = rnd.choice((0.78, 0.94))  # (a little grain on the stone)
                    px[X % S, y] = shade(base, g)
            start += w
    return im


def grass_face(rnd):
    """An earth bank under the grass: the grass's edge (blades hanging over here and there),
    earth with specks, small stones and roots, darker and damp at the foot."""
    grass, earth = rgb('#7f9652'), shade(rgb('#78593a'), 1.12)
    im = Image.new('RGB', (S, FACE_H), earth)
    px = im.load()
    for x in range(S):
        lip = 4 + (rnd.choice((1, 2, 3)) if rnd.random() < 0.3 else 0)
        for y in range(FACE_H):
            if y < lip:
                px[x, y] = shade(grass, 0.86 if y < 2 else 0.72)
            elif y >= FACE_H - 4:
                px[x, y] = shade(earth, 0.66)
            elif rnd.random() < 0.1:
                px[x, y] = shade(earth, 0.82)
    for _ in range(4):  # (small stones in the bank)
        x, y = rnd.randrange(2, S - 6), rnd.randrange(9, FACE_H - 8)
        for dx in range(4):
            for dy in range(3):
                px[x + dx, y + dy] = rgb('#9a8f80') if dy < 2 else rgb('#6b6156')
    for _ in range(3):  # (roots)
        x, y = rnd.randrange(S), rnd.randrange(6, FACE_H - 10)
        for k in range(rnd.randint(3, 6)):
            px[(x + k) % S, y + k // 2] = shade(earth, 0.6)
    return im


def ice_face(rnd):
    """The edge of a floe: white on top, pale blue with facets, the ice under the water deeper
    blue at the foot."""
    im = Image.new('RGB', (S, FACE_H), (204, 230, 241))
    px = im.load()
    x = rnd.randrange(4, 10)
    while x < S - 2:
        for y in range(2, FACE_H - 4):
            px[x, y] = (168, 208, 226)
            px[x + 1, y] = (226, 243, 250)
        x += rnd.randrange(14, 22)
    for x in range(S):
        for y in range(2):
            px[x, y] = (246, 251, 253)
        for y in range(FACE_H - 4, FACE_H):
            px[x, y] = (118, 176, 201)
    return im


def bank_face(base, rnd):
    """A low bank of mud or sand: its top edge, then darker."""
    im = Image.new('RGB', (S, FACE_H))
    px = im.load()
    for x in range(S):
        for y in range(FACE_H):
            f = 0.86 if y < 2 else 0.64
            px[x, y] = shade(base, f * (0.9 if rnd.random() < 0.08 else 1.0))
    return im


def faces():
    """The faces where a higher ground stands above the one south of it (TerrainEdges), a row
    each in TerrainEdges.FACE_ROWS' order: rock, grass, ice, mud, sand; one tile wide and
    tileable, so faces side by side join up."""
    out = Image.new('RGB', (S, FACE_H * 5))
    for row, im in enumerate([rock_face(random.Random(501)), grass_face(random.Random(502)),
                              ice_face(random.Random(503)), bank_face(rgb('#78593a'), random.Random(504)),
                              bank_face(shade(rgb('#e5d19e'), 0.95), random.Random(505))]):
        out.paste(im, (0, FACE_H * row))
    out.save(FACES)


if __name__ == '__main__':
    faces()
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
