"""Draws the rowboat (2 m, 32 px long) at the ranger's own 3/4 angle (the owner: the sheet's boat
was seen from too high, too much inside, too little side): mostly its side, planked, with only a
thin strip of the inside (the far rim and a seat) showing above the near rim, bow to the right.

Writes assets/boats/rowboat.png (the whole boat) and rowboat_front.png (its near side from the
rim down, drawn over the ranger sitting in it; Boat.hull_front). Light wood, so the boat colour
the player picks (a tint) shows. Re-run after changing it:  python tools/make_rowboat.py
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'boats')
W, H = 36, 20
RIM = 9  # (the near rim's row: the front half starts here)

OUTLINE = (52, 32, 20, 255)
FAR_RIM = (190, 146, 98, 255)
INSIDE = (92, 60, 36, 255)
INSIDE_DARK = (74, 47, 28, 255)
SEAT = (176, 128, 82, 255)
NEAR_RIM = (70, 44, 26, 255)
SIDE_TOP = (184, 132, 86, 255)
SIDE = (150, 102, 62, 255)
SEAM = (112, 74, 44, 255)
SIDE_LOW = (122, 82, 48, 255)

# Row -> (first x, last x) of the boat on that row.
SPANS = {
    4: (6, 27),   # far rim
    5: (4, 30),
    6: (4, 31),   # inside
    7: (4, 32),
    8: (4, 32),
    9: (3, 33),   # near rim (the bow's tip at the end)
    10: (3, 32),  # side
    11: (3, 31),
    12: (4, 30),
    13: (4, 29),
    14: (5, 28),
    15: (6, 26),
    16: (8, 24),  # keel
}


def colour(x, y):
    if y == 4:
        return OUTLINE
    if y == 5:
        return FAR_RIM
    if y in (6, 7, 8):
        if 16 <= x <= 18:
            return SEAT
        return INSIDE_DARK if y == 6 else INSIDE
    if y == RIM:
        return NEAR_RIM
    if y == 10:
        return SIDE_TOP
    if y in (12, 14):
        return SEAM if x % 9 != 4 else SIDE  # (plank seams, a break here and there)
    if y >= 15:
        return SIDE_LOW
    return SIDE


def boat():
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for y, (x0, x1) in SPANS.items():
        for x in range(x0, x1 + 1):
            im.putpixel((x, y), colour(x, y))
    # A dark outline round it all (the game's style).
    px = im.load()
    edge = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3]:
                continue
            if any(0 <= x + dx < W and 0 <= y + dy < H and px[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge.append((x, y))
    for xy in edge:
        px[xy] = OUTLINE
    return im


if __name__ == '__main__':
    whole = boat()
    whole.save(os.path.join(OUT, 'rowboat.png'))
    front = whole.copy()
    front.paste((0, 0, 0, 0), (0, 0, W, RIM))
    front.save(os.path.join(OUT, 'rowboat_front.png'))
    print('rowboat written to', os.path.normpath(OUT))
