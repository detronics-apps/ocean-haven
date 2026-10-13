"""Cuts the owner's buildings sheet (docs/buildings_sheet.webp: every building on magenta, in the
order of tools/building_sheet_targets.json, the ranger first for scale) into the game's building
pictures, at the sizes they had in the game (the owner: their original sizes).

1. Background = magenta and anything blended with it (the compression's pink fringe).
2. Pictures = big blobs of non-background, in reading order; labels (one line of purple
   letters, at most 22 px tall) are dropped, and a label touching a picture's bottom is trimmed.
3. In each picture everything outside its outer dark outline goes: a flood fill from the box's
   edge through every pixel that isn't outline (the outline thickened by a pixel, so a gap can't
   let it in), then the plain grey / beige fill joined to the outside (between pillars, under a
   jetty), then the last ring just outside the line. White or coloured specks outside the black
   line go with it; inside stays solid. A picture whose outline doesn't close (the dock) only
   loses its magenta.
4. Each picture is fitted, keeping its shape, into the box the old picture's art filled
   (targets: "size" of the whole picture, "art" = that box), standing on the box's bottom, and
   saved as a PNG beside the old picture's path (.svg -> .png).

Re-run after the sheet changes:  python tools/cut_building_sheet.py
"""
import json
import os
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
SHEET = os.path.join(ROOT, 'docs', 'buildings_sheet.webp')
TARGETS = os.path.join(HERE, 'building_sheet_targets.json')


def is_bg(p):
    r, g, b = p[:3]
    return r > 150 and b > 150 and g < r - 70 and g < b - 70  # (magenta, and pink blended with it)


def lum(p):
    return p[0] * 0.3 + p[1] * 0.59 + p[2] * 0.11


def purple(p):
    return p[0] - p[1] > 30 and p[2] - p[1] > 30


def pictures(im):
    """The pictures' boxes in reading order (labels left out)."""
    w, h = im.size
    px = im.load()
    fg = [[not is_bg(px[x, y]) for x in range(w)] for y in range(h)]
    seen = [[False] * w for _ in range(h)]
    boxes = []
    for y in range(h):
        for x in range(w):
            if not fg[y][x] or seen[y][x]:
                continue
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
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
            bh = box[3] - box[1]
            text = sum(1 for p in pts if purple(px[p])) / len(pts)
            if len(pts) >= 40 and bh > 12 and not (bh <= 22 and text > 0.15):
                boxes.append(box)
    merged = True  # (a picture's loose bits, a flag or a sign, join it)
    while merged:
        merged = False
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                a, b = boxes[i], boxes[j]
                if a[0] - 1 <= b[2] and b[0] - 1 <= a[2] and a[1] - 1 <= b[3] and b[1] - 1 <= a[3]:
                    boxes[i] = (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))
                    del boxes[j]
                    merged = True
                    break
            if merged:
                break
    boxes.sort(key=lambda b: (b[1] // 120, b[0]))  # (rows of the sheet, then left to right)
    return boxes


def cut(im, box):
    x0, y0, x1, y1 = box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2
    crop = im.crop((x0, y0, x1, y1))
    w, h = crop.size
    c = crop.load()
    dark = Image.new('L', (w, h), 0)
    d = dark.load()
    for y in range(h):
        for x in range(w):
            if not is_bg(c[x, y]) and lum(c[x, y]) < 75:
                d[x, y] = 255
    wall = dark.filter(ImageFilter.MaxFilter(3)).load()
    outside = [[False] * w for _ in range(h)]
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    for x, y in stack:
        outside[y][x] = True
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not outside[ny][nx] and not wall[nx, ny]:
                outside[ny][nx] = True
                stack.append((nx, ny))

    def plain(q):
        return lum(q) > 95 and (max(q) - min(q)) < 0.22 * max(q)
    grow = [(x, y) for y in range(h) for x in range(w) if outside[y][x]]
    while grow:
        x, y = grow.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not outside[ny][nx] and not d[nx, ny] and plain(c[nx, ny]):
                outside[ny][nx] = True
                grow.append((nx, ny))
    piece = crop.convert('RGBA')
    p = piece.load()
    for y in range(h):
        for x in range(w):
            near = any(0 <= x + dx < w and 0 <= y + dy < h and outside[y + dy][x + dx]
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if is_bg(c[x, y]) or outside[y][x] or (near and not d[x, y]):
                p[x, y] = (0, 0, 0, 0)
    solid = sum(1 for y in range(h) for x in range(w) if not is_bg(c[x, y]))
    kept = sum(1 for a in piece.getchannel('A').get_flattened_data() if a)
    if kept < 0.5 * solid:  # (the outline didn't close: only the magenta goes)
        piece = crop.convert('RGBA')
        p = piece.load()
        for y in range(h):
            for x in range(w):
                if is_bg(c[x, y]):
                    p[x, y] = (0, 0, 0, 0)
    return trim_label(piece.crop(piece.getbbox()))


def trim_label(piece):
    """Rows of purple letters touching the bottom (a label) go."""
    p = piece.load()
    w, h = piece.size
    cut_at = h
    for y in range(h - 1, -1, -1):
        row = [p[x, y] for x in range(w) if p[x, y][3]]
        if row and sum(1 for q in row if purple(q)) / len(row) <= 0.25:
            break
        cut_at = y
    if cut_at < h:
        piece = piece.crop((0, 0, w, cut_at))
        piece = piece.crop(piece.getbbox())
    return piece


def fit(piece, target):
    """The picture at the old one's size: as big as fits in its art box, standing on its bottom."""
    w, h = target['size']
    x0, y0, x1, y1 = target['art']
    scale = min((x1 - x0) / piece.size[0], (y1 - y0) / piece.size[1])
    nw, nh = max(1, round(piece.size[0] * scale)), max(1, round(piece.size[1] * scale))
    small = piece.resize((nw, nh), Image.LANCZOS)
    alpha = small.getchannel('A').point(lambda a: 255 if a >= 110 else 0)  # (crisp edges)
    small.putalpha(alpha)
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    out.alpha_composite(small, ((x0 + x1 - nw) // 2, y1 - nh))
    return out


if __name__ == '__main__':
    im = Image.open(SHEET).convert('RGB')
    targets = json.load(open(TARGETS))
    boxes = pictures(im)
    if len(boxes) != len(targets):
        raise SystemExit('the sheet has %d pictures, the targets %d' % (len(boxes), len(targets)))
    for box, target in zip(boxes, targets):
        if target is None:  # (the ranger, for scale only)
            continue
        out = fit(cut(im, box), target)
        path = os.path.join(ROOT, target['texture'].replace('res://', '').rsplit('.', 1)[0] + '.png')
        out.save(path)
        print('%-40s -> %s' % (target['name'], os.path.relpath(path, ROOT)))
