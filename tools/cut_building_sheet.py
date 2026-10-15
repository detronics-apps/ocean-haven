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
   Loose bits lying wholly below the picture (a label under it) go too; with "see_through" the
   plain grey fill inside it goes as well (the turtle areas: the sand shows through).
4. Each picture is fitted, keeping its shape, into the box the old picture's art filled
   (targets: "size" of the whole picture, "art" = that box), standing on the box's bottom, and
   saved as a PNG beside the old picture's path (.svg -> .png).

The plants sheet (docs/plants_sheet.webp, tools/plant_sheet_targets.json: trees by stage, the
willow, kelp, coral, seagrass) is cut the same way with `trees`: dark magenta shadows under the
trees count as background (the game draws its own), pale fill is kept (the Pisonia's pale trunk),
and rows go by the pictures' bottoms (trees of every height stand on one line).

Re-run after a sheet changes:  python tools/cut_building_sheet.py      (buildings)
                               python tools/cut_building_sheet.py trees
"""
import json
import os
import sys
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
TREES = len(sys.argv) > 1 and sys.argv[1] == 'trees'
SHEET = os.path.join(ROOT, 'docs', 'plants_sheet.webp' if TREES else 'buildings_sheet.webp')
TARGETS = os.path.join(HERE, 'plant_sheet_targets.json' if TREES else 'building_sheet_targets.json')


def is_bg(p):
    r, g, b = p[:3]
    if r > 150 and b > 150 and g < r - 70 and g < b - 70:  # (magenta, and pink blended with it)
        return True
    # (the trees' shadows: dark magenta)
    return TREES and r > 90 and b > 90 and g < 0.3 * min(r, b) and abs(r - b) < 0.35 * max(r, b)


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
            dark = sum(1 for p in pts if lum(px[p]) < 90) / len(pts)
            label = (bh <= 14 and dark > 0.5) if TREES else (bh <= 22 and text > 0.15)  # (trees: dark letters)
            if len(pts) >= 4 and not label:
                boxes.append([box, len(pts)])
    gap = 8 if TREES else 1  # (a picture's loose bits join it: a flag, a sign, a willow's dots)
    merged = True
    while merged:
        merged = False
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                (a, na), (b, nb) = boxes[i], boxes[j]
                if a[0] - gap <= b[2] and b[0] - gap <= a[2] and a[1] - gap <= b[3] and b[1] - gap <= a[3]:
                    boxes[i] = [(min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])), na + nb]
                    del boxes[j]
                    merged = True
                    break
            if merged:
                break
    boxes = [b for b, n in boxes if n >= (20 if TREES else 40) and b[3] - b[1] > (8 if TREES else 12)]
    if TREES:  # (rows by where the pictures stand, then left to right)
        boxes.sort(key=lambda b: (b[3] // (h // 2 + 1), b[0]))
    else:
        boxes.sort(key=lambda b: (b[1] // 120, b[0]))  # (rows of the sheet, then left to right)
    return boxes


def tree_cut(im, box):
    """Trees' outlines don't close (leaves), so: only the magenta and the shadows go, then the
    pink-tinted pixels (the compression's blend with the magenta) are peeled off the edges."""
    W, H = im.size
    piece = im.crop((max(0, box[0] - 2), max(0, box[1] - 2), min(W, box[2] + 2), min(H, box[3] + 2))).convert('RGBA')
    p = piece.load()
    w, h = piece.size
    for y in range(h):
        for x in range(w):
            r, g, b = p[x, y][:3]
            # (also strong magenta anywhere: the gaps between roots and branches; coral pinks keep)
            if is_bg(p[x, y]) or (r > 60 and b > 50 and g < 0.45 * min(r, b) and abs(r - b) < 0.5 * max(r, b)):
                p[x, y] = (0, 0, 0, 0)
    for _ in range(3):
        peel = []
        for y in range(h):
            for x in range(w):
                q = p[x, y]
                if q[3] and q[0] - q[1] > 25 and q[2] - q[1] > 15 and any(
                        not (0 <= x + dx < w and 0 <= y + dy < h) or p[x + dx, y + dy][3] == 0
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    peel.append((x, y))
        for x, y in peel:
            p[x, y] = (0, 0, 0, 0)
    return piece.crop(piece.getbbox())


def cut(im, box, see_through=False):
    if TREES:
        return tree_cut(im, box)
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
    grow = [] if TREES else [(x, y) for y in range(h) for x in range(w) if outside[y][x]]
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
    if see_through:
        for y in range(h):
            for x in range(w):
                q = p[x, y]
                if q[3] and lum(q) > 140 and max(q[:3]) - min(q[:3]) < 0.13 * max(q[:3]):
                    p[x, y] = (0, 0, 0, 0)
        for _ in range(3):  # (then the greyish specks left at its edges)
            peel = [(x, y) for y in range(h) for x in range(w) if p[x, y][3] and lum(p[x, y]) > 110
                    and max(p[x, y][:3]) - min(p[x, y][:3]) < 0.2 * max(p[x, y][:3])
                    and any(0 <= x + dx < w and 0 <= y + dy < h and p[x + dx, y + dy][3] == 0
                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
            for xy in peel:
                p[xy] = (0, 0, 0, 0)
    return drop_below(trim_label(piece.crop(piece.getbbox())))


def drop_below(piece):
    """Loose bits wholly below the biggest part (a label under the picture) go."""
    a = piece.getchannel('A').load()
    w, h = piece.size
    seen, parts = set(), []
    for y in range(h):
        for x in range(w):
            if a[x, y] and (x, y) not in seen:
                stack, pts = [(x, y)], []
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    pts.append((cx, cy))
                    for nx in (cx - 1, cx, cx + 1):
                        for ny in (cy - 1, cy, cy + 1):
                            if 0 <= nx < w and 0 <= ny < h and a[nx, ny] and (nx, ny) not in seen:
                                seen.add((nx, ny))
                                stack.append((nx, ny))
                parts.append(pts)
    main = max(parts, key=len)
    bottom = max(y for _, y in main)
    p = piece.load()
    for pts in parts:
        if min(y for _, y in pts) > bottom - 2 and pts is not main:
            for xy in pts:
                p[xy] = (0, 0, 0, 0)
    return piece.crop(piece.getbbox())


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


def rim(front):
    """The near side's top edge as the boat's rim (the owner): a dark line along every column of
    the near side, nothing else."""
    p = front.load()
    w, h = front.size
    for x in range(w):
        for y in range(h):
            if p[x, y][3] > 100:
                p[x, y] = (59, 36, 22, 255)
                break


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
    return outline(out) if TREES else out


def outline(im):
    """A crisp 1-px dark line round the picture (the trees' own line is lost in the cut and the
    shrinking): a near-black shade of the colour it borders, as on the owner's sheet."""
    p = im.load()
    w, h = im.size
    line = {}
    for y in range(h):
        for x in range(w):
            if p[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= x + dx < w and 0 <= y + dy < h and p[x + dx, y + dy][3]:
                    r, g, b = p[x + dx, y + dy][:3]
                    line[(x, y)] = (int(r * 0.25), int(g * 0.25), int(b * 0.25), 255)
                    break
    for xy, c in line.items():
        p[xy] = c
    return im


if __name__ == '__main__':
    im = Image.open(SHEET).convert('RGB')
    targets = json.load(open(TARGETS))
    boxes = pictures(im)
    if len(boxes) != len(targets):
        raise SystemExit('the sheet has %d pictures, the targets %d' % (len(boxes), len(targets)))
    for box, target in zip(boxes, targets):
        if target is None:  # (the ranger, for scale only)
            continue
        out = fit(cut(im, box, target.get('see_through', False)), target)
        path = os.path.join(ROOT, target['texture'].replace('res://', '').rsplit('.', 1)[0] + '.png')
        out.save(path)
        if 'front_from' in target:  # (a boat's near side, drawn over whoever sits in it)
            front = out.copy()
            front.paste((0, 0, 0, 0), (0, 0, front.size[0], target['front_from']))
            rim(front)
            front.save(path[:-4] + '_front.png')
        print('%-40s -> %s' % (target['name'], os.path.relpath(path, ROOT)))
