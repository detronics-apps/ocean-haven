"""Draws the dock and the drawbridge (the owner: redrawn to fit the rest of the game), at twice
the game's pixels like the ground and the buildings (64 x 64 a tile, drawn at half size:
BuildingData.picture_scale), in the wood colours of the owner's water gate and houses:

  assets/buildings/dock_plank.png         one dock tile on its own (the Make menu, placing)
  assets/buildings/dock_joined.png        16 dock tiles in a row, one for each way it can meet
                                          other decks (BuildingData.joined_texture): bit 1 a deck
                                          to the north, 2 east, 4 south, 8 west
  assets/buildings/drawbridge_closed.png  the lowered drawbridge on its own, and
  assets/buildings/drawbridge_joined.png  its 16, like the dock's, with its two iron straps
  assets/buildings/drawbridge_open.png    the drawbridge raised: its deck stands up on the
                                          hinge, the water shows between its two posts

Decks join into one solid deck: planks run on across tiles (four boards a tile, joints
staggered, nails at the joints, a little grain), and only a side with no deck next to it gets
the near-black edge; where there's no deck to the south, the deck's front shows (¾ view), with
pilings going down into the water.

Re-run after a change:  python tools/make_deck.py
"""
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'buildings')
S = 64
BOARD = 16  # (four boards a tile; the last two rows of each are the gap to the next)
JOINTS = [22, 54, 10, 38]  # (where each board's planks meet: staggered)


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


HI, LIGHT, MID, SHADE, GAP = rgb('#c08a55'), rgb('#a87648'), rgb('#946540'), rgb('#7a5236'), rgb('#3e2615')
LINE = rgb('#1d1004')
NAIL, GLINT = rgb('#2b1a0e'), rgb('#d3ac80')
FACE, FACE_HI, FACE_LO = rgb('#6a4429'), rgb('#82563a'), rgb('#4f3220')
STEEL, STEEL_HI, STEEL_LO, BOLT = rgb('#7c8089'), rgb('#a7adb8'), rgb('#4d5058'), rgb('#c9ced6')


def planks(straps=False):
    """The deck's top, joining on every side (no edges)."""
    im = Image.new('RGBA', (S, S))
    p = im.load()
    rnd = random.Random(7)
    for y in range(S):
        r = y % BOARD
        colour = HI if r < 2 else LIGHT if r < 6 else MID if r < 12 else SHADE if r < 14 else GAP
        for x in range(S):
            p[x, y] = colour
    for board in range(S // BOARD):
        top = board * BOARD
        for _ in range(5):  # (grain: a few long thin streaks)
            y = top + rnd.randint(3, 11)
            x0, n = rnd.randint(0, S - 1), rnd.randint(6, 14)
            for x in range(x0, x0 + n):
                p[x % S, y] = SHADE if rnd.random() < 0.8 else MID
        j = JOINTS[board]
        for y in range(top, top + BOARD - 2):  # (the joint: a dark gap, end grain either side)
            p[j, y] = GAP
            p[j + 1, y] = GAP
            p[(j - 1) % S, y] = SHADE
            p[(j + 2) % S, y] = HI
        for nx in (j - 5, j + 6):  # (two nails each side)
            for ny in (top + 4, top + 9):
                p[nx % S, ny] = NAIL
                p[(nx + 1) % S, ny] = NAIL
                p[nx % S, ny + 1] = NAIL
                p[(nx + 1) % S, ny + 1] = NAIL
                p[nx % S, ny - 1] = GLINT
    if straps:  # (the drawbridge's iron straps, bolted at every board)
        for x0 in (12, 46):
            for y in range(S):
                for x in range(x0, x0 + 6):
                    p[x, y] = STEEL_HI if x == x0 + 1 else STEEL_LO if x >= x0 + 4 else STEEL
                p[x0, y] = LINE
                p[x0 + 5, y] = LINE
            for board in range(S // BOARD):
                for dy in (5, 10):
                    p[x0 + 2, board * BOARD + dy] = BOLT
                    p[x0 + 3, board * BOARD + dy] = BOLT
    return im


def edged(top, mask):
    """The deck top with its edges: a near-black line on each side with no deck there; with no
    deck to the south, the deck's front face and its pilings into the water below."""
    im = top.copy()
    p = im.load()
    north, east, south, west = mask & 1, mask & 2, mask & 4, mask & 8
    if not north:
        for x in range(S):
            p[x, 0] = p[x, 1] = LINE
    if not west:
        for y in range(S):
            p[0, y] = p[1, y] = LINE
    if not east:
        for y in range(S):
            p[S - 1, y] = p[S - 2, y] = LINE
    if not south:
        for x in range(S):  # (the deck's front edge, its face, then the water)
            p[x, 50] = p[x, 51] = LINE
            for y in range(52, 58):
                p[x, y] = FACE_HI if y < 54 else FACE_LO if y >= 56 else FACE
            p[x, 58] = p[x, 59] = LINE
            for y in range(60, S):
                p[x, y] = (0, 0, 0, 0)
        for x in range(16, S, 16):  # (board ends on the face)
            for y in range(52, 58):
                p[x, y] = LINE
        for x0 in (6, S - 14):  # (the pilings)
            for y in range(60, S):
                for x in range(x0, x0 + 8):
                    p[x, y] = LINE if x in (x0, x0 + 7) else FACE_HI if x == x0 + 1 else FACE_LO if x >= x0 + 5 else FACE
        if not west:
            for y in range(50, 60):
                p[0, y] = p[1, y] = LINE
        if not east:
            for y in range(50, 60):
                p[S - 1, y] = p[S - 2, y] = LINE
    return im


def raised(top):
    """The drawbridge raised: its deck stands up on the hinge along the top (seen from the side,
    darker), two posts below it, the water between them."""
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    leaf = top.resize((S, 24), Image.NEAREST)
    shade = Image.new('RGBA', (S, 24), (20, 10, 0, 70))  # (its underside, out of the light)
    leaf.alpha_composite(shade)
    im.alpha_composite(leaf, (0, 2))
    p = im.load()
    for x in range(S):
        p[x, 0] = p[x, 1] = LINE
        p[x, 26] = p[x, 27] = LINE
        for y in range(28, 32):  # (the hinge beam)
            p[x, y] = STEEL_LO if y < 30 else LINE
    for y in range(0, 28):
        p[0, y] = p[1, y] = p[S - 1, y] = p[S - 2, y] = LINE
    for x0 in (0, S - 10):  # (the posts it swings on)
        for y in range(32, S):
            for x in range(x0, x0 + 10):
                edge = x in (x0, x0 + 1, x0 + 8, x0 + 9) or y >= S - 2
                p[x, y] = LINE if edge else FACE_HI if x == x0 + 2 else FACE_LO if x >= x0 + 6 else FACE
    return im


def strip(top):
    row = Image.new('RGBA', (S * 16, S), (0, 0, 0, 0))
    for mask in range(16):
        row.alpha_composite(edged(top, mask), (mask * S, 0))
    return row


if __name__ == '__main__':
    dock, bridge = planks(), planks(straps=True)
    edged(dock, 0).save(os.path.join(OUT, 'dock_plank.png'))
    strip(dock).save(os.path.join(OUT, 'dock_joined.png'))
    edged(bridge, 0).save(os.path.join(OUT, 'drawbridge_closed.png'))
    strip(bridge).save(os.path.join(OUT, 'drawbridge_joined.png'))
    raised(bridge).save(os.path.join(OUT, 'drawbridge_open.png'))
    print('dock and drawbridge drawn in', os.path.normpath(OUT))
