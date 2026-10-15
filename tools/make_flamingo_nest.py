"""Draws the flamingo's mud-mound nest (assets/animals/flamingo/mud_nest.png): pixel art at twice
the game's pixels like the buildings (drawn at half size by MangroveEcosystem, 14 x 12 in the
game), the owner: its detail to match the rest of the game. A little cone of mud in the mud's own
colours, lit from the left, a darker hollow on top with a single egg in it, a near-black line round.

Re-run after a change:  python tools/make_flamingo_nest.py
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'animals', 'flamingo', 'mud_nest.png')
W, H = 28, 24


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


LIGHT, MID, DARK, WET = rgb('#8f6d49'), rgb('#77583a'), rgb('#5f4530'), rgb('#4f3a27')
RIM, HOLLOW, HOLLOW_LO = rgb('#a5835c'), rgb('#4a3522'), rgb('#3a2a1b')
EGG, EGG_SHADE, EGG_SHINE = rgb('#f3eee0'), rgb('#d6cdb8'), rgb('#ffffff')
LINE = rgb('#1f140b')


def inside_ellipse(x, y, cx, cy, rx, ry):
    return ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0


if __name__ == '__main__':
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    p = im.load()
    top_y, bottom_y = 8.0, 17.5
    for y in range(H):
        for x in range(W):
            t = min(1.0, max(0.0, (y + 0.5 - top_y) / (bottom_y - top_y)))
            half = 9.0 + 3.0 * t  # (wider at the foot)
            body = top_y <= y + 0.5 <= bottom_y and abs(x + 0.5 - 14) <= half
            if body or inside_ellipse(x, y, 14, bottom_y, 12, 3.6) or inside_ellipse(x, y, 14, top_y, 9, 3.4):
                side = (x + 0.5 - 14) / half if half else 0  # (-1 left, 1 right)
                colour = LIGHT if side < -0.35 else MID if side < 0.4 else DARK
                if y + 0.5 > bottom_y + 1.2:
                    colour = WET  # (the wet foot in the mud)
                p[x, y] = colour
    for y in range(H):  # the rim and the hollow on top, the egg in it
        for x in range(W):
            if inside_ellipse(x, y, 14, top_y, 9, 3.4) and not inside_ellipse(x, y, 14, top_y, 7, 2.4):
                p[x, y] = RIM
            elif inside_ellipse(x, y, 14, top_y, 7, 2.4):
                p[x, y] = HOLLOW_LO if y + 0.5 < top_y else HOLLOW
    for y in range(H):
        for x in range(W):
            if inside_ellipse(x, y, 14, top_y - 0.5, 2.6, 2.1):
                p[x, y] = EGG_SHADE if (x > 14 and y > top_y - 1) else EGG
    p[13, 6] = EGG_SHINE
    line = set()
    for _ in range(2):  # (a line two pixels wide: one game pixel)
        solid = {(x, y) for y in range(H) for x in range(W) if p[x, y][3]}
        for x, y in solid:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < W and 0 <= ny < H and (nx, ny) not in solid:
                    line.add((nx, ny))
        for xy in line:
            p[xy] = LINE
    im.save(OUT)
    print('flamingo nest drawn:', os.path.normpath(OUT))
