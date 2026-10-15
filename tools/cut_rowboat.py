"""Cuts the owner's rowboat picture (docs/rowboat_sheet.jpg: pixel art in 33.3-px blocks on
magenta, drawn at the ranger's 3/4 angle) into the game's rowboat, at the picture's own detail
(56 x 19), drawn 32 px long in the game (Boat.hull_scale: 2 m; shrinking the picture itself to
32 px lost its lines):
assets/boats/rowboat.png (the whole boat) and rowboat_front.png (its near side, drawn over the
ranger sitting in it; Boat.hull_front).

1. Each block is read at its middle (clear of the JPEG's blur): 56 x 19 pixels, the magenta ones
   transparent, the colours snapped to the picture's own few.
2. The front: in each column, from the bottom of the hull up past its outline and planks to the
   first dark line, the rim, then LIFT more to its inner edge. Along the boat that's the straight rim; at the bow it climbs with the
   curve, so the whole curved nose is in front (the owner: the cut follows the nose).
3. Both on a 60 x 24 canvas, the boat in its middle.
Re-run after the picture changes:  python tools/cut_rowboat.py
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SHEET = os.path.join(HERE, '..', 'docs', 'rowboat_sheet.jpg')
OUT = os.path.join(HERE, '..', 'assets', 'boats')
BLOCK = 2000 / 60.0  # (the picture's pixel size)
ORIGIN = (0.0, 262 - 7 * 2000 / 60.0)  # (where its grid starts: found from the colour edges)
CANVAS = (60, 24)
LIFT = 3  # (the cut goes 3 pixels above the outer rim, to its inner edge: the owner)


def lum(c):
    return c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11


def read(im):
    """The picture's pixels (each block's middle), magenta ones transparent."""
    bg = im.getpixel((10, 10))
    cols = int(im.size[0] / BLOCK)
    rows = int((im.size[1] - ORIGIN[1]) / BLOCK)
    grid = Image.new('RGBA', (cols, rows), (0, 0, 0, 0))
    for r in range(rows):
        for c in range(cols):
            cx, cy = int((c + 0.5) * BLOCK + ORIGIN[0]), int((r + 0.5) * BLOCK + ORIGIN[1])
            ps = [im.getpixel((cx + dx, cy + dy)) for dx in (-6, 0, 6) for dy in (-6, 0, 6)]
            avg = tuple(sum(p[i] for p in ps) // 9 for i in range(3))
            if sum(abs(a - b) for a, b in zip(avg, bg)) > 90:
                grid.putpixel((c, r), avg + (255,))
    grid = grid.crop(grid.getbbox())
    # The picture's own colours: snapped to its few.
    flat = grid.convert('RGB').quantize(10, method=Image.Quantize.MEDIANCUT).convert('RGB')
    clean = Image.new('RGBA', grid.size, (0, 0, 0, 0))
    for y in range(grid.size[1]):
        for x in range(grid.size[0]):
            if grid.getpixel((x, y))[3]:
                clean.putpixel((x, y), flat.getpixel((x, y)) + (255,))
    return clean


def front_mask(boat):
    """In each column, from the rim down."""
    w, h = boat.size
    p = boat.load()
    mask = Image.new('L', boat.size, 0)
    for x in range(w):
        y = h - 1
        while y >= 0 and p[x, y][3] == 0:  # (below the boat)
            y -= 1
        while y >= 0 and p[x, y][3] and lum(p[x, y]) < 45:  # (the hull's bottom outline)
            y -= 1
        while y >= 0 and p[x, y][3] and lum(p[x, y]) >= 45:  # (up the planks)
            y -= 1
        rim = (y if y >= 0 and p[x, y][3] else y + 1) - LIFT
        for yy in range(max(rim, 0), h):
            if p[x, yy][3]:
                mask.putpixel((x, yy), 255)
    return mask


if __name__ == '__main__':
    boat = read(Image.open(SHEET).convert('RGB'))
    mask = front_mask(boat)
    whole = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
    at = ((CANVAS[0] - boat.size[0]) // 2, (CANVAS[1] - boat.size[1]) // 2)
    whole.paste(boat, at)
    front = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
    front.paste(boat, at, mask)
    whole.save(os.path.join(OUT, 'rowboat.png'))
    front.save(os.path.join(OUT, 'rowboat_front.png'))
    print('rowboat', boat.size, 'at', at)
