"""Cuts the owner's reworked pictures (docs/rework/*.jpg: pixel art on a pale green grid, with a
label under each and a soft shadow) into the game's pictures, at the sizes they already have:

1. Background out: the pale grey-green ground, its grid lines and the shadows on it are all one
   family of colours (greenish greys); every pixel of that family goes, also between pillars and
   in the blend round the dark outlines.
2. The pictures: what's left, joined where parts nearly touch (a sign, a dish); the labels
   (short, dark, colourless lines of letters) are dropped. Left to right, then top to bottom.
3. Each is shrunk into the box its old picture filled (tools/rework_targets.json or the
   size given) at twice the game's pixels (DENSITY: the owner, the game draws them at half size:
   BuildingData / AnimalData.picture_scale), standing on the box's bottom, and its colours
   snapped to the picture's own palette (so nothing is lost, and nothing blurred in between); its
   edge gets a near-black line.
4. Made from them (the owner): the closed water gate (the open one with planks where the water
   was). (The dock and drawbridge are drawn by tools/make_deck.py.)
These buildings are out of tools/building_sheet_targets.json (their entries are null there), so
re-cutting the buildings sheet never undoes them; their boxes are in tools/rework_targets.json.

Re-run after a picture changes:  python tools/cut_owner_pictures.py
"""
import json
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
SRC = os.path.join(ROOT, 'docs', 'rework')
TARGETS = {t['name']: t for t in json.load(open(os.path.join(HERE, 'rework_targets.json')))}

# picture -> what each object in it becomes: (target name in building_sheet_targets.json, or
# (path, width, height)), in reading order.
PICTURES = {
    'mangrove.jpg': ['Mangrove Eco-Lodge', 'Mangrove Waterworks Station', 'Water Gate'],
    'house_1_2.jpg': ['Ranger House (level 1)', 'Ranger House (level 2)'],
    'house_3.jpg': ['Ranger House (level 3)'],
    'polar_bear.jpg': [('assets/animals/polar_bear/polar_bear.png', 36, 24),
                       ('assets/animals/polar_bear/polar_bear_resting.png', 36, 20),
                       ('assets/animals/polar_bear/polar_bear_baby.png', 18, 13),
                       ('assets/animals/polar_bear/polar_bear_young.png', 28, 19)],
    'deep_sea.jpg': ['Deep-Ocean Outpost', 'Deep-Sea Discovery Centre'],
    'polar_stations.jpg': ['Polar Research Centre', 'Polar Research Station'],
    '../patrol_boat_sheet.png': [('assets/boats/patrol_boat.png', 42, 26)],
}


DENSITY = 2  # (twice the game's pixels, drawn at half size: nothing squeezed out: the owner)


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def ground(c):
    """The background family: the pale green-grey ground, its grid lines, the shadows on it (or
    magenta, and pink blended with it, behind the patrol boat)."""
    r, g, b = c[:3]
    if r > 150 and b > 150 and g < r - 70 and g < b - 70:
        return True
    return lum(c) > 105 and g - r >= 5 and g - b >= 7 and max(c[:3]) - min(c[:3]) < 60


def letters(c):
    return lum(c) < 110 and max(c[:3]) - min(c[:3]) < 30


def objects(im):
    """The pictures' boxes (labels left out), in reading order."""
    w, h = im.size
    p = im.load()
    fg = [[not ground(p[x, y]) for x in range(w)] for y in range(h)]
    seen = [[False] * w for _ in range(h)]
    parts = []
    for y in range(h):
        for x in range(w):
            if fg[y][x] and not seen[y][x]:
                stack, pts = [(x, y)], []
                seen[y][x] = True
                while stack:
                    cx, cy = stack.pop()
                    pts.append((cx, cy))
                    for nx in (cx - 1, cx, cx + 1):
                        for ny in (cy - 1, cy, cy + 1):
                            if 0 <= nx < w and 0 <= ny < h and fg[ny][nx] and not seen[ny][nx]:
                                seen[ny][nx] = True
                                stack.append((nx, ny))
                xs, ys = [q[0] for q in pts], [q[1] for q in pts]
                box = [min(xs), min(ys), max(xs) + 1, max(ys) + 1]
                text = sum(1 for q in pts if letters(p[q])) / len(pts)
                if len(pts) >= 12 and not (box[3] - box[1] <= 40 and text > 0.5):
                    parts.append([box, len(pts)])
    merged = True
    while merged:  # (parts that nearly touch belong together)
        merged = False
        for i in range(len(parts)):
            for j in range(i + 1, len(parts)):
                a, b = parts[i][0], parts[j][0]
                if a[0] - 4 <= b[2] and b[0] - 4 <= a[2] and a[1] - 4 <= b[3] and b[1] - 4 <= a[3]:
                    parts[i] = [[min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])], parts[i][1] + parts[j][1]]
                    del parts[j]
                    merged = True
                    break
            if merged:
                break
    boxes = [b for b, n in parts if n >= 150]
    boxes.sort(key=lambda b: (b[1] // 200, b[0]))
    return boxes


def cut(im, box):
    """The picture, the background family see-through, still at the source's size."""
    piece = im.crop(box).convert('RGBA')
    p = piece.load()
    w, h = piece.size
    for y in range(h):
        for x in range(w):
            if ground(p[x, y]):
                p[x, y] = (0, 0, 0, 0)
    for _ in range(3):  # (then the pale greyish blend left on the outside of the dark line)
        peel = [(x, y) for y in range(h) for x in range(w) if p[x, y][3] and lum(p[x, y]) >= 120
                and max(p[x, y][:3]) - min(p[x, y][:3]) < 40
                and any(not (0 <= x + dx < w and 0 <= y + dy < h) or not p[x + dx, y + dy][3]
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        for xy in peel:
            p[xy] = (0, 0, 0, 0)
    return piece


def shrink(piece, size, art):
    """Into the box `art` (x0, y0, x1, y1) of a `size` picture, standing on its bottom: averaged
    (only what's solid counts), then snapped to the piece's own colours, with a dark edge."""
    x0, y0, x1, y1 = art
    scale = min((x1 - x0) / piece.size[0], (y1 - y0) / piece.size[1])
    nw, nh = max(1, round(piece.size[0] * scale)), max(1, round(piece.size[1] * scale))
    src = piece.load()
    sw, sh = piece.size
    palette_src = Image.new('RGB', (sw, sh))
    solid = [(x, y) for y in range(sh) for x in range(sw) if src[x, y][3]]
    for x, y in solid:
        palette_src.putpixel((x, y), src[x, y][:3])
    pal_img = Image.new('RGB', (len(solid), 1))
    pal_img.putdata([src[q][:3] for q in solid])
    pal = pal_img.quantize(40, method=Image.Quantize.MEDIANCUT).getpalette()[:40 * 3]
    palette = [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)]
    small = Image.new('RGBA', (nw, nh), (0, 0, 0, 0))
    s = small.load()
    for y in range(nh):
        for x in range(nw):
            ax, bx = int(x * sw / nw), max(int(x * sw / nw) + 1, int((x + 1) * sw / nw))
            ay, by = int(y * sh / nh), max(int(y * sh / nh) + 1, int((y + 1) * sh / nh))
            cells = [src[i, j] for i in range(ax, bx) for j in range(ay, by)]
            full = [c for c in cells if c[3]]
            if len(full) * 2 < len(cells):
                continue
            # The darkest quarter wins where an outline runs through (lines stay unbroken).
            dark = [c for c in full if lum(c) < 70]
            pick = dark if len(dark) * 4 >= len(full) else full
            avg = tuple(sum(c[i] for c in pick) // len(pick) for i in range(3))
            near = min(palette, key=lambda q: (q[0] - avg[0]) ** 2 * 2 + (q[1] - avg[1]) ** 2 * 4 + (q[2] - avg[2]) ** 2 * 3)
            s[x, y] = near + (255,)
    edge = {}
    for y in range(nh):
        for x in range(nw):
            if s[x, y][3] and lum(s[x, y]) > 75 and any(
                    not (0 <= x + dx < nw and 0 <= y + dy < nh) or not s[x + dx, y + dy][3]
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                r, g, b, _ = s[x, y]
                edge[(x, y)] = (int(r * 0.25), int(g * 0.25), int(b * 0.25), 255)
    for xy, c in edge.items():
        s[xy] = c
    _drop_specks(small)
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    out.alpha_composite(small, ((x0 + x1 - nw) // 2, y1 - nh))
    return out


def _drop_specks(im, smallest=6):
    """Loose bits of a few pixels (left over from the blend round the outline) go."""
    p = im.load()
    w, h = im.size
    seen = set()
    for y in range(h):
        for x in range(w):
            if p[x, y][3] and (x, y) not in seen:
                stack, part = [(x, y)], []
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    part.append((cx, cy))
                    for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                        if 0 <= nx < w and 0 <= ny < h and p[nx, ny][3] and (nx, ny) not in seen:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
                if len(part) < smallest:
                    for q in part:
                        p[q] = (0, 0, 0, 0)


def closed_gate(gate):
    """The open water gate with planks where the water and the opening above it were: the
    planks are the gate's own top beam, row by row, repeated down."""
    out = gate.copy()
    p = out.load()
    w, h = out.size
    water = [(x, y) for y in range(h) for x in range(w)
             if p[x, y][3] and p[x, y][2] > p[x, y][0] + 40 and p[x, y][2] > 100]
    xs, ys = [q[0] for q in water], [q[1] for q in water]
    left, right, bottom = min(xs), max(xs), max(ys)
    top = min(ys)
    while top > 0 and not (p[(left + right) // 2, top - 1][3] and lum(p[(left + right) // 2, top - 1]) > 70):
        top -= 1  # (up through the opening to the beam)
    beam_bottom = top - 1
    beam = beam_bottom
    while beam > 0 and p[(left + right) // 2, beam][3] and lum(p[(left + right) // 2, beam]) > 70:
        beam -= 1
    rows = list(range(beam + 1, beam_bottom + 1)) or [beam_bottom]
    dark = p[(left + right) // 2, beam]
    for y in range(top, bottom + 1):
        source = rows[(y - top) % len(rows)]
        for x in range(left, right + 1):
            p[x, y] = p[x, source]
    for x in range(left, right + 1):  # (a dark line where the planks end at the bottom)
        p[x, bottom] = dark
    return out


if __name__ == '__main__':
    made = {}
    for name, outs in PICTURES.items():
        im = Image.open(os.path.join(SRC, name)).convert('RGB')
        boxes = objects(im)
        if len(boxes) != len(outs):
            raise SystemExit('%s: found %d pictures, expected %d: %s' % (name, len(boxes), len(outs), boxes))
        for box, target in zip(boxes, outs):
            if isinstance(target, str):
                t = TARGETS[target]
                path = t['texture'].replace('res://', '').rsplit('.', 1)[0] + '.png'
                size, art = tuple(t['size']), tuple(t['art'])
            else:
                path, w, h = target
                size, art = (w, h), (0, 0, w, h)
            size, art = tuple(v * DENSITY for v in size), tuple(v * DENSITY for v in art)
            out = shrink(cut(im, box), size, art)
            out.save(os.path.join(ROOT, path))
            made[path] = out
            print('%-24s %-40s -> %s %s' % (name, str(box), path, size))
    gate = made['assets/buildings/water_gate/water_gate_open.png']
    closed_gate(gate).save(os.path.join(ROOT, 'assets/buildings/water_gate/water_gate_closed.png'))
    print('and the closed water gate')
