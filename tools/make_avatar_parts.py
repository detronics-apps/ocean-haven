"""Draws every avatar part (the ranger's and the people's) as pixel art, laid out on the owner's
character sheets (measured in the sheet's own pixel blocks) at about one tile tall (a tile is
about 2 m): the face about two thirds as wide as the body with its arms, a chin that narrows in
steps, big low eyes (2 x 3) with a white highlight down their left side, and the hair making up
the top of the head.

Each part is a strip of 32x36 frames, feet on the bottom rows: front, side (facing right), side
mid-step, back. Hair has 8 frames: 0-3 the part in front of the face, 4-7 the part behind the
body (long hair, ponytails, big curls); tops and jackets 8 too: 4-7 the sleeve on the near arm in
the side views, drawn over that arm (arm.png), which is drawn over the body. Tinted parts are drawn in grey (shaded, with an outline)
and coloured in the game by the player's choice (Sprite2D.modulate), so the outline is always a
darker shade of the part's own colour. Shoes, glasses, the badge and the face are drawn in colour.

The shapes below are written in the first layout's rows; `lowered` turns them into the final
ones (the owner): the head one row shorter above the eyes (rows 0-6 down one, merging into row
7) and everything from the shoulders down (rows 18-28) one lower, merging into row 29 so the
feet stay put, which leaves row 18 for a one-pixel neck.

Only the front is ever chosen in the creator: the side and back views follow from the same
choices. Re-run after changing a shape:  python tools/make_avatar_parts.py
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'characters', 'avatar')
W, H = 32, 36
FRONT, SIDE, STEP, BACK = range(4)
VIEWS = (FRONT, SIDE, STEP, BACK)
# Grey levels of a tinted part.
LIGHT, BASE, SHADE, DEEP, LINE = 255, 222, 178, 140, 40  # (a near-black line, like the owner's buildings)


def rows(spec):
    """{(x, y)} from [(y0, y1, [(x0, x1), ...]), ...] (all inclusive)."""
    out = set()
    for y0, y1, spans in spec:
        for y in range(y0, y1 + 1):
            for x0, x1 in spans:
                out.update((x, y) for x in range(x0, x1 + 1))
    return out


def box(x0, y0, x1, y1):
    return rows([(y0, y1, [(x0, x1)])])


# (the neck between the chin and the collar: no clothes' outline is drawn over it)
NECK_SHOWS = {(x, 18) for x in range(14, 18)}


def drop(y):
    """A row of the first layout in the final one (see the top)."""
    return y + 1 if y <= 6 or 18 <= y <= 28 else y


def lowered(cells):
    """A mask {(x, y)} or pixels {(x, y): v} moved to the final rows. Rows that merge keep the
    row that didn't move; a mask running across rows 17-18 also fills the new row 18 (no gap)."""
    if isinstance(cells, dict):
        out = {(x, drop(y)): v for (x, y), v in cells.items() if drop(y) != y}
        out.update({p: v for p, v in cells.items() if drop(p[1]) == p[1]})
        return out
    out = {(x, drop(y)) for x, y in cells}
    out |= {(x, 18) for x, y in cells if y == 17 and (x, 18) in cells}
    return out


def shaded(mask, details=None):
    """Grey pixels: lit on the top-left edges, shaded on the bottom-right, an outline round it."""
    mask, details = lowered(mask), lowered(details or {})
    px = {}
    for x, y in mask:
        if (x + 1, y) not in mask or (x, y + 1) not in mask:
            px[(x, y)] = SHADE
        elif (x - 1, y) not in mask or (x, y - 1) not in mask:
            px[(x, y)] = LIGHT
        else:
            px[(x, y)] = BASE
    for p, v in (details or {}).items():
        if p in mask:
            px[p] = v
    for x, y in mask:
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in mask and n not in NECK_SHOWS and 0 <= n[0] < W and 0 <= n[1] < H:
                px[n] = LINE
    return {p: (v, v, v, 255) for p, v in px.items()}


def coloured(mask, base, shade, line):
    mask = lowered(mask)
    px = {}
    for x, y in mask:
        px[(x, y)] = shade if (x + 1, y) not in mask or (x, y + 1) not in mask else base
    for x, y in mask:
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in mask and n not in px and 0 <= n[0] < W and 0 <= n[1] < H:
                px[n] = line
    return px


def save(name, frames):
    """frames: a list of {(x, y): rgba}, one per frame."""
    image = Image.new('RGBA', (W * len(frames), H), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        for (x, y), c in frame.items():
            if 0 <= x < W and 0 <= y < H:
                image.putpixel((i * W + x, y), tuple(c) if len(c) == 4 else tuple(c) + (255,))
    image.save(os.path.join(OUT, name + '.png'))


def jag(mask, every=3):
    """A wavy edge: every few rows the outer pixels go out one."""
    out = set(mask)
    for x, y in mask:
        if y % every == 0:
            if (x - 1, y) not in mask:
                out.add((x - 1, y))
            if (x + 1, y) not in mask:
                out.add((x + 1, y))
    return out


# --- The body (skin): face, arms and hands, legs and feet ---
# The face (rows 8-17) narrows in steps to the chin; hair and hats sit on rows 0-9 round it.
FACE_FRONT = rows([(8, 8, [(12, 19)]), (9, 15, [(11, 20)]), (16, 16, [(12, 19)]), (17, 17, [(13, 18)])])
FACE_SIDE = rows([(8, 8, [(12, 19)]), (9, 15, [(11, 21)]), (16, 16, [(12, 20)]), (17, 17, [(14, 19)]),
                  (13, 13, [(22, 22)])])  # (a nose)
# The top of the head, under the hair (it shows with the bald style and under short cuts); every
# style's crown covers it.
SCALP_FRONT = rows([(4, 4, [(13, 18)]), (5, 5, [(12, 19)]), (6, 8, [(11, 20)])])
# (from the side: as wide as the face, rounded at the back, the forehead in line with the face)
SCALP_SIDE = rows([(4, 4, [(13, 18)]), (5, 5, [(12, 20)]), (6, 8, [(11, 21)])])
NECK = box(14, 17, 17, 18)  # (one pixel showing between the chin and the collar)
# (the arms are drawn on their own, so their outline shows them apart from the body)
TORSO_FRONT = rows([(18, 18, [(12, 19)]), (19, 26, [(11, 20)])])
# (a row below the shoulders, which round off into their outside: the owner)
# (the shoulders round off into them: their top row is narrower)
SHOULDERS = [(19, 19, [(9, 10), (21, 22)])]
ARMS_FRONT = rows(SHOULDERS + [(20, 27, [(8, 10), (21, 23)])])
LEGS_FRONT = rows([(27, 32, [(11, 14), (17, 20)])])
TORSO_SIDE = rows([(18, 18, [(12, 19)]), (19, 26, [(11, 20)])])
ARM_SIDE = box(14, 20, 16, 27)
ARM_STEP = box(16, 20, 18, 26)
LEGS_SIDE = rows([(27, 31, [(14, 17)]), (32, 32, [(14, 18)])])
LEGS_STEP = rows([(27, 29, [(12, 14), (16, 18)]), (30, 32, [(11, 13), (17, 19)])])
ARMS = {FRONT: ARMS_FRONT, SIDE: ARM_SIDE, STEP: ARM_STEP, BACK: ARMS_FRONT}


def seamed(px):
    """The arms' inner outline (against the body, front and back) as a soft seam, not a dark
    line, so they look part of the body (the owner's sheet)."""
    for (x, y), c in px.items():
        if 20 <= y <= 22 and (x in (11, 20) and c[0] == LINE or x in (10, 21) and c[0] in (SHADE, LIGHT) and y > 20):
            px[(x, y)] = (BASE, BASE, BASE, 255)  # (the top of the arm is part of the body: no seam)
        elif x in (11, 20) and 23 <= y <= 28 and c[0] == LINE:
            px[(x, y)] = (DEEP, DEEP, DEEP, 255)
    return px


def body(view):
    if view in (FRONT, BACK):
        px = shaded(TORSO_FRONT | LEGS_FRONT)
        px.update(seamed(shaded(ARMS_FRONT)))
        px.update(shaded(FACE_FRONT | SCALP_FRONT | NECK))
    else:
        px = shaded(TORSO_SIDE | (LEGS_SIDE if view == SIDE else LEGS_STEP))
        px.update(shaded(FACE_SIDE | SCALP_SIDE | NECK))
    return px


# (front and back: the hands, on the arm layer so the trousers never cover them)
HANDS = rows([(26, 27, [(8, 10), (21, 23)])])


def near_arm(view):
    """The arm nearest the viewer in the side views (skin), its own layer over the clothes; from
    the front and back, the hands."""
    return shaded(ARMS[view]) if view in (SIDE, STEP) else shaded(HANDS)


def sleeve(view, to):
    """A sleeve on the near arm, down to row `to` (frames 4-7 of a top or jacket)."""
    if view not in (SIDE, STEP) or to < 19:
        return {}
    return shaded({(x, y) for x, y in ARMS[view] if y <= to + 1})  # (the arms start a row lower)


MOUTH = (150, 78, 70, 255)
WHITE = (255, 255, 255, 255)
EYE_TOP, EYE_BOTTOM = 11, 13
EYES_FRONT = (12, 18)  # (left columns of the two eyes, each 2 wide)
EYE_SIDE = 18


def face(view):
    """Untinted: the white highlight down each eye's left side, and the mouth."""
    px = {}
    if view == FRONT:
        for x in EYES_FRONT:
            px.update({(x, y): WHITE for y in range(EYE_TOP, EYE_TOP + 2)})
        px.update({(15, 16): MOUTH, (16, 16): MOUTH})
    elif view in (SIDE, STEP):
        px.update({(EYE_SIDE, y): WHITE for y in range(EYE_TOP, EYE_TOP + 2)})
        px.update({(19, 16): MOUTH, (20, 16): MOUTH})
    return px


def eyes(view):
    """Tinted with the eye colour: dark, round the highlight."""
    dark = (110, 110, 110, 255)
    lefts = EYES_FRONT if view == FRONT else (EYE_SIDE,) if view in (SIDE, STEP) else ()
    cells = set()
    for x in lefts:
        cells |= box(x + 1, EYE_TOP, x + 1, EYE_BOTTOM) | box(x, EYE_TOP + 2, x, EYE_BOTTOM)
    return {p: dark for p in cells}


# --- Hair: (in front of the face, behind the body) per view ---
CROWN_FRONT = rows([(2, 2, [(12, 19)]), (3, 3, [(10, 21)]), (4, 7, [(9, 22)]),
                    (8, 8, [(9, 11), (14, 17), (20, 22)]), (9, 11, [(9, 10), (21, 22)])])
CROWN_SIDE = rows([(2, 2, [(11, 18)]), (3, 3, [(10, 20)]), (4, 7, [(9, 21)]),
                   (8, 8, [(9, 13), (17, 20)]), (9, 13, [(9, 12)])])
CROWN_BACK = rows([(2, 2, [(12, 19)]), (3, 3, [(10, 21)]), (4, 15, [(9, 22)]), (16, 16, [(10, 21)])])
CURLS_FRONT = rows([(1, 1, [(11, 12), (14, 17), (19, 20)]), (2, 2, [(10, 21)]), (3, 8, [(8, 23)]),
                    (9, 9, [(8, 11), (13, 14), (17, 18), (20, 23)]), (10, 11, [(8, 10), (21, 23)])])
CURLS_SIDE = rows([(1, 1, [(10, 11), (13, 15), (17, 19)]), (2, 2, [(9, 20)]), (3, 8, [(8, 21)]),
                   (9, 9, [(8, 13), (17, 20)]), (10, 14, [(8, 12)])])
CURLS_BACK = rows([(1, 1, [(11, 12), (14, 17), (19, 20)]), (2, 15, [(8, 23)]),
                   (16, 16, [(9, 11), (14, 17), (20, 22)])])
BIG_ROUND = rows([(0, 0, [(11, 20)]), (1, 1, [(9, 22)]), (2, 2, [(7, 24)]), (3, 14, [(6, 25)]),
                  (15, 16, [(7, 24)]), (17, 17, [(9, 22)]), (18, 18, [(10, 12), (15, 16), (19, 21)])])
# (from the side the big curls stay behind the head, never over the face)
BIG_SIDE = rows([(0, 0, [(9, 15)]), (1, 1, [(7, 16)]), (2, 2, [(6, 16)]), (3, 14, [(5, 13)]),
                 (15, 16, [(6, 13)]), (17, 17, [(7, 12)])])


def curl_dots(mask):
    return {(x, y): SHADE for x, y in mask if (x * 3 + y * 2) % 7 == 0}


def strands(mask):
    return {(x, y): SHADE for x, y in mask if x % 3 == 0 and y > 5}


def braid(x0, y0, y1):
    mask = box(x0, y0, x0 + 2, y1)
    return mask, {(x, y): SHADE for x, y in mask if (x - x0 + y) % 3 == 0}


def faded(cells):
    """Short hair thinning out over the skin: {(x, y): alpha}, drawn see-through (tinted too)."""
    return {p: (DEEP, DEEP, DEEP, a) for p, a in lowered(cells).items()}


def fade_sides(x_cols, y0, y1):
    """Columns of hair fading out row by row from y0 down to y1."""
    return {(x, y): int(210 - 150 * (y - y0) / max(1, y1 - y0)) for x in x_cols for y in range(y0, y1 + 1)}


def hair_style(name):
    """Eight frames: front-layer views, then back-layer views."""
    front, back = [], []
    for view in VIEWS:
        f, b, fd, bd, see = set(), set(), {}, {}, {}
        side = view in (SIDE, STEP)
        crown = CROWN_SIDE if side else CROWN_BACK if view == BACK else CROWN_FRONT
        if name == 'short':
            f = crown
        elif name == 'bald':
            pass  # (the scalp, drawn with the skin)
        elif name == 'fade':  # (full on top, the sides faded short)
            if side:
                f = rows([(3, 3, [(12, 18)]), (4, 4, [(11, 20)]), (5, 6, [(11, 21)])])
                see = fade_sides((11, 12), 7, 12)
            elif view == BACK:
                f = rows([(3, 3, [(12, 19)]), (4, 4, [(11, 20)]), (5, 7, [(10, 21)])])
                see = fade_sides(range(11, 21), 8, 15)
            else:
                f = rows([(3, 3, [(12, 19)]), (4, 4, [(11, 20)]), (5, 6, [(10, 21)])])
                see = fade_sides((11, 20), 7, 11)
            fd = strands(f)
        elif name == 'army':  # (a short buzz cut, close to the head)
            if side:
                f = rows([(4, 4, [(13, 18)]), (5, 5, [(12, 20)]), (6, 6, [(11, 21)])])
                see = fade_sides((11, 12), 7, 11)
            elif view == BACK:
                f = rows([(4, 4, [(13, 18)]), (5, 11, [(11, 20)])])
                see = fade_sides(range(11, 21), 12, 15)
            else:
                f = rows([(4, 4, [(13, 18)]), (5, 6, [(11, 20)])])
                see = fade_sides((11, 20), 7, 9)
            fd = {(x, y): SHADE for x, y in f if (x + y) % 2 == 0}
        elif name == 'cropped':
            f = rows([(3, 3, [(11, 19)]), (4, 4, [(10, 20)]), (5, 6, [(9, 21)]), (7, 12, [(9, 11)])]) if side else \
                rows([(3, 3, [(11, 20)]), (4, 14, [(9, 22)]), (15, 15, [(10, 21)])]) if view == BACK else \
                rows([(3, 3, [(11, 20)]), (4, 4, [(10, 21)]), (5, 6, [(9, 22)]), (7, 10, [(9, 10), (21, 22)])])
        elif name in ('long', 'wavy'):
            end = 23 if name == 'long' else 25
            if view == FRONT:
                f = crown | rows([(9, end, [(8, 10), (21, 23)])])
                b = rows([(6, end + 1, [(8, 23)])])
            elif side:
                f = crown
                b = rows([(6, end + 1, [(7, 13)])])
            else:
                f = crown | rows([(4, end + 1, [(8, 23)])])
            if name == 'wavy':
                f, b = jag(f), jag(b)
            fd, bd = strands(f), strands(b)
        elif name == 'ponytail':  # (high, tied at the back of the head)
            f = crown
            if view == FRONT:
                b = rows([(3, 5, [(20, 23)]), (6, 10, [(22, 25)]), (11, 15, [(23, 25)]), (16, 17, [(23, 24)])])
            elif side:
                b = rows([(3, 5, [(6, 9)]), (6, 11, [(4, 7)]), (12, 16, [(4, 5)])])
            else:
                f = crown | box(14, 2, 17, 18)
                fd = {(x, 3): DEEP for x in range(14, 18)}
            bd = strands(b)
        elif name == 'side_ponytail':
            f = crown
            if view == FRONT:
                b = rows([(7, 9, [(21, 23)]), (10, 21, [(22, 24)]), (22, 22, [(22, 23)])])
            elif side:
                b = rows([(7, 21, [(5, 8)]), (22, 22, [(6, 7)])])
            else:
                f = crown | rows([(7, 21, [(7, 9)])])
            bd = strands(b)
        elif name == 'braid':
            f = crown
            if view == FRONT:
                plait, fd = braid(20, 9, 25)
                f = crown | plait
            elif side:
                b, bd = braid(7, 9, 25)
            else:
                plait, fd = braid(8, 9, 25)
                f = crown | plait
        elif name == 'curly':
            f = CURLS_SIDE if side else CURLS_BACK if view == BACK else CURLS_FRONT
            fd = curl_dots(f)
        elif name == 'big_curls':
            if view == FRONT:
                f, b = CURLS_FRONT, BIG_ROUND
            elif side:
                f, b = CURLS_SIDE, BIG_SIDE
            else:
                f = BIG_ROUND
            fd, bd = curl_dots(f), curl_dots(b)
        px = shaded(f, fd) if f else {}
        px.update({p: c for p, c in faded(see).items() if p not in px})
        front.append(px)
        back.append(shaded(b, bd) if b else {})
    save('hair_' + name, front + back)


# --- Hats ---
def hat(name):
    frames = []
    for view in VIEWS:
        side = view in (SIDE, STEP)
        d = {}
        if name == 'ranger_hat':
            m = rows([(0, 0, [(11, 18)]), (1, 4, [(10, 19)]), (5, 5, [(6, 23)]), (6, 6, [(4, 25)]), (7, 7, [(6, 23)])]) if side else \
                rows([(0, 0, [(12, 19)]), (1, 4, [(11, 20)]), (5, 5, [(7, 24)]), (6, 6, [(5, 26)]), (7, 7, [(7, 24)])])
            d = {(x, 4): DEEP for x in range(0, 32)}
        elif name == 'cap':
            if side:
                m = rows([(1, 1, [(11, 17)]), (2, 2, [(10, 19)]), (3, 6, [(9, 20)]), (6, 6, [(21, 25)]), (7, 7, [(21, 24)])])
            elif view == BACK:
                m = rows([(1, 1, [(12, 19)]), (2, 2, [(10, 21)]), (3, 4, [(9, 22)]), (5, 6, [(9, 13), (18, 22)])])
            else:
                m = rows([(1, 1, [(12, 19)]), (2, 2, [(10, 21)]), (3, 7, [(9, 22)])])
                d = {(x, y): LIGHT for x in range(9, 23) for y in (6, 7)}
            if not side:
                d.update({(15, y): SHADE for y in range(1, 5)})
        elif name == 'bucket_hat':
            m = rows([(1, 1, [(11, 18)]), (2, 4, [(10, 19)]), (5, 5, [(8, 21)]), (6, 6, [(7, 22)]), (7, 7, [(6, 23)])]) if side else \
                rows([(1, 1, [(12, 19)]), (2, 4, [(11, 20)]), (5, 5, [(9, 22)]), (6, 6, [(8, 23)]), (7, 7, [(7, 24)])])
            d = {(x, 4): SHADE for x in range(0, 32)}
        elif name == 'sun_hat':
            m = rows([(0, 0, [(11, 18)]), (1, 3, [(10, 19)]), (4, 4, [(5, 24)]), (5, 5, [(2, 27)]), (6, 6, [(3, 26)])]) if side else \
                rows([(0, 0, [(12, 19)]), (1, 3, [(11, 20)]), (4, 4, [(6, 25)]), (5, 5, [(3, 28)]), (6, 6, [(4, 27)])])
            d = {(x, 3): DEEP for x in range(0, 32)}
        elif name == 'safari_cap':
            if side:
                m = rows([(0, 0, [(10, 19)]), (1, 4, [(9, 20)]), (5, 5, [(18, 24)]), (5, 9, [(7, 9)])])
            else:
                m = rows([(0, 0, [(11, 20)]), (1, 4, [(10, 21)]), (5, 5, [(8, 23)]), (6, 6, [(9, 22)])])
                d = {(15, y): SHADE for y in range(1, 5)}
        frames.append(shaded(m, d))
    save(name, frames)


# --- Tops (the shirt colour), jackets, bottoms ---
def top(name):
    sleeve_to = {'t_shirt': 20, 'jumper': 24, 'shirt': 23, 'tank_top': 18}[name]
    frames = []
    for view in VIEWS:
        d = {}
        sleeves = {}
        if view in (FRONT, BACK):
            if name == 'tank_top':
                m = rows([(18, 18, [(13, 13), (18, 18)]), (19, 26, [(12, 19)])])
            else:
                m = TORSO_FRONT
                sleeves = seamed(shaded(rows(SHOULDERS + [(20, sleeve_to + 1, [(8, 10), (21, 23)])]),
                                 {(x, 25): SHADE for x in (8, 9, 10, 21, 22, 23)} if name == 'jumper' else None))
            if name == 'jumper':
                d = {(x, y): SHADE for x in range(11, 21) for y in (25, 26) if x % 2 == 0}
            if view == FRONT and name == 'shirt':
                d = {(13, 18): LIGHT, (18, 18): LIGHT, (15, 20): DEEP, (15, 23): DEEP}
            if view == FRONT and name in ('t_shirt', 'jumper'):
                d.update({(x, 18): DEEP for x in range(14, 18)})
        else:
            m = rows([(18, 18, [(14, 15)]), (19, 26, [(12, 19)])]) if name == 'tank_top' else TORSO_SIDE
        px = shaded(m, d)
        px.update(sleeves)
        frames.append(px)
    save('top_' + name, frames + [sleeve(v, sleeve_to) for v in VIEWS])


def jacket(name):
    frames = []
    for view in VIEWS:
        d = {}
        sleeves = {}
        if name == 'vest':
            if view == FRONT:
                m = rows([(18, 26, [(11, 14), (17, 20)])])
                d = {(x, 18): LIGHT for x in range(11, 21)}
            elif view == BACK:
                m = TORSO_FRONT
            else:
                m = TORSO_SIDE
        else:  # (a zip jacket with long sleeves)
            if view in (FRONT, BACK):
                m = TORSO_FRONT
                sleeves = seamed(shaded(rows(SHOULDERS + [(20, 25, [(8, 10), (21, 23)])])))
                if view == FRONT:
                    d = {(x, y): DEEP for x in (15, 16) for y in range(19, 27)}
                    d.update({(x, 18): LIGHT for x in (12, 13, 18, 19)})
            else:
                m = TORSO_SIDE
        px = shaded(m, d)
        px.update(sleeves)
        frames.append(px)
    save('jacket_' + name, frames + [sleeve(v, 24 if name == 'zip' else 0) for v in VIEWS])


def bottoms(name):
    frames = []
    for view in VIEWS:
        if name == 'trousers':
            if view in (FRONT, BACK):
                m = rows([(26, 28, [(11, 20)]), (29, 31, [(11, 14), (17, 20)])])
            elif view == SIDE:
                m = rows([(26, 28, [(12, 19)]), (29, 31, [(13, 18)])])
            else:
                m = rows([(26, 27, [(11, 19)]), (28, 29, [(12, 14), (16, 18)]), (30, 31, [(11, 13), (17, 19)])])
        else:
            if view in (FRONT, BACK):
                m = rows([(26, 28, [(11, 20)]), (29, 29, [(11, 14), (17, 20)])])
            elif view == SIDE:
                m = rows([(26, 29, [(12, 19)])])
            else:
                m = rows([(26, 27, [(11, 19)]), (28, 29, [(12, 14), (16, 18)])])
        frames.append(shaded(m))
    save('bottoms_' + name, frames)


BOOT = ((112, 74, 50), (84, 54, 36), (48, 30, 20))


def shoes(name):
    frames = []
    for view in VIEWS:
        if view in (FRONT, BACK):  # (as wide as the legs, as on the owner's sheet)
            spots = [(11, 14), (17, 20)]
        elif view == SIDE:
            spots = [(14, 18)]
        else:
            spots = [(10, 13), (17, 20)]
        if name == "boots":
            frames.append(coloured(rows([(32, 34, spots)]), *BOOT))
        else:  # (sandals: a sole and a strap, the feet showing)
            px = {}
            for x0, x1 in spots:
                px.update({(x, 34): BOOT[1] for x in range(x0, x1 + 1)})
                px.update({(x, 32): (60, 140, 140) for x in range(x0 + 1, x1)})
            frames.append(px)
    save('shoes_' + name, frames)


GLASS_FRAME = (40, 38, 46)
LENS = (34, 36, 48)
SHINE = (120, 132, 156)


def glasses(name):
    """Round the eyes (2 x 4): a frame one pixel out from them, and a bridge or an arm."""
    frames = []
    for view in VIEWS:
        px = {}
        if view == BACK:
            frames.append(px)
            continue
        wide = 4 if name == 'round' else 3  # (round ones as wide as they're tall)
        if view in (SIDE, STEP):
            lenses = [EYE_SIDE - 1]
            px.update({(x, EYE_TOP + 1): GLASS_FRAME for x in range(12, EYE_SIDE - 1)})
        else:
            lenses = [EYES_FRONT[0] - 1 - (wide - 3), EYES_FRONT[1] - 1]
            px.update({(x, EYE_TOP + 1): GLASS_FRAME for x in range(EYES_FRONT[0] + 3, EYES_FRONT[1] - 1)})
        for x0 in lenses:
            x1, y0, y1 = x0 + wide, EYE_TOP - 1, EYE_BOTTOM + 1
            for x in range(x0, x1 + 1):
                for y in range(y0, y1 + 1):
                    edge = x in (x0, x1) or y in (y0, y1)
                    if name == 'round' and x in (x0, x1) and y in (y0, y1):
                        continue
                    if edge:
                        px[(x, y)] = GLASS_FRAME
                    elif name == 'sunglasses':
                        px[(x, y)] = LENS
            if name == 'sunglasses':
                px[(x0 + 1, y0 + 1)] = SHINE
        frames.append(px)
    save('glasses_' + name, frames)


def backpack():
    frames = []
    for view in VIEWS:
        d = {}
        if view == FRONT:  # (hidden behind them, as on the owner's sheet)
            frames.append({})
            continue
        if view == BACK:
            m = rows([(17, 27, [(11, 20)])])
            d = {(x, 20): DEEP for x in range(11, 21)}
            d.update({(x, y): SHADE for x in range(12, 20) for y in (22, 25)})
            d.update({(x, y): SHADE for x in (12, 19) for y in range(22, 26)})
        else:
            m = rows([(17, 27, [(6, 10)])])
            d = {(x, 19): DEEP for x in range(6, 11)}
        frames.append(shaded(m, d))
    save('backpack', frames)


GOLD = ((240, 200, 70), (180, 130, 30), (110, 70, 20))


RIBBON = (58, 120, 196)


def badge():
    """The Ocean Day badge: a round gold medal on a blue ribbon, the ocean blue at its centre;
    forward on the chest from the side, clear of the arm."""
    frames = []
    for view in VIEWS:
        if view == BACK:
            frames.append({})
            continue
        cx = 12 if view == FRONT else 17
        disc = box(cx, 21, cx + 3, 24) - {(cx, 21), (cx + 3, 21), (cx, 24), (cx + 3, 24)}
        px = coloured(disc, *GOLD)
        px[(cx + 1, drop(22))] = RIBBON  # (the ocean, in the middle)
        for y in (19, 20):  # (the ribbon above it)
            px[(cx + 1, drop(y))] = RIBBON
            px[(cx + 2, drop(y))] = RIBBON
        frames.append(px)
    save('badge_ocean_day', frames)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    save('skin', [body(v) for v in VIEWS])
    save('arm', [near_arm(v) for v in VIEWS])
    save('face', [face(v) for v in VIEWS])
    save('eyes', [eyes(v) for v in VIEWS])
    for style in ('short', 'long', 'ponytail', 'curly', 'big_curls', 'wavy', 'side_ponytail', 'braid', 'cropped',
                  'bald', 'fade', 'army'):
        hair_style(style)
    for name in ('ranger_hat', 'cap', 'bucket_hat', 'sun_hat', 'safari_cap'):
        hat(name)
    for name in ('t_shirt', 'jumper', 'shirt', 'tank_top'):
        top(name)
    for name in ('vest', 'zip'):
        jacket(name)
    for name in ('trousers', 'shorts'):
        bottoms(name)
    for name in ('boots', 'sandals'):
        shoes(name)
    for name in ('round', 'square', 'sunglasses'):
        glasses(name)
    backpack()
    badge()
    print('avatar parts written to', os.path.normpath(OUT))
