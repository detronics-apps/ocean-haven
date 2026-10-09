"""Cuts the owner's rescue-stage sheet (docs/rescue_stages_sheet.jpg: one row per animal, six
care days from left to right; the turtle row starts with an extra "hatching from the egg"
picture) into clean pixel-art PNGs for the vet room, and wires them into the RescueData.

For every sprite: the flat background is removed by a flood fill from the edges (so light
colours inside the animal stay), the JPEG blur is snapped back to the art's pixel grid (PIXEL
sheet pixels per art pixel) and the colours are reduced to a small palette. All six stages of
an animal share one square canvas at the same scale, standing on its bottom edge, so the
growth from day to day is the sheet's own (RescueData.stage_sizes are all 1).

Eyes are found automatically (the near-black pupils); the mouth and the wound are set per
animal below (MOUTH / WOUND: a share of the figure's box) and checked on the preview.

    pip install pillow numpy
    python3 tools/cut_rescue_sheet.py            # writes assets/animals/vet/<rescue>_<1-6>.png
    godot --headless --path . --import
"""
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SHEET = os.path.join(ROOT, "docs/rescue_stages_sheet.jpg")
OUT = os.path.join(ROOT, "assets/animals/vet")
PIXEL = 4          # sheet pixels per art pixel
BG_TOLERANCE = 34  # how far from the background colour still counts as background
COLOURS = 28       # palette size per animal
## Rows top to bottom, and the pictures in each row (the turtle's first is it hatching).
ROWS = [("home_turtle", True), ("mangrove_flamingo", False), ("kelp_otter", False),
        ("polar_seal", False), ("reef_seahorse", False), ("deep_sixgill", False)]
## Where its mouth and its wound are, as a share of the figure's box (x from the left, y
## from the top), for each animal.
MOUTH = {"home_turtle": (0.86, 0.42), "mangrove_flamingo": (0.93, 0.2), "kelp_otter": (0.83, 0.33),
         "polar_seal": (0.88, 0.36), "reef_seahorse": (0.93, 0.18), "deep_sixgill": (0.92, 0.55)}
WOUND = {"home_turtle": (0.62, 0.8), "mangrove_flamingo": (0.6, 0.85), "kelp_otter": (0.62, 0.9),
         "polar_seal": (0.72, 0.93), "reef_seahorse": (0.55, 0.6), "deep_sixgill": (0.86, 0.62)}


## Eyes set by hand (share of the canvas, per stage: [far eye, near eye]) where finding them
## automatically picks up a nose, gills or a beak; one visible eye is given twice.
EYES = {
    "kelp_otter": [[(0.51, 0.69), (0.64, 0.69)], [(0.64, 0.49), (0.79, 0.475)], [(0.69, 0.45), (0.835, 0.44)],
                   [(0.69, 0.435), (0.84, 0.43)], [(0.754, 0.40), (0.87, 0.415)], [(0.717, 0.33), (0.87, 0.315)]],
    "mangrove_flamingo": [[(0.535, 0.56)] * 2, [(0.577, 0.385)] * 2, [(0.643, 0.31)] * 2,
                          [(0.65, 0.26)] * 2, [(0.68, 0.22)] * 2, [(0.67, 0.14)] * 2],
    "deep_sixgill": [[(0.64, 0.766)] * 2, [(0.742, 0.73)] * 2, [(0.80, 0.735)] * 2,
                     [(0.81, 0.71)] * 2, [(0.81, 0.71)] * 2, [(0.826, 0.69)] * 2],
}


def bands(v, gap):
    out, start, last = [], None, None
    for i, on in enumerate(v):
        if on:
            start = i if start is None else start
            last = i
        elif start is not None and i - last > gap:
            out.append((start, last))
            start = None
    if start is not None:
        out.append((start, last))
    return out


def sprites(img, bg):
    """The sheet's sprites as boxes: one list of (x0, y0, x1, y1) per row."""
    diff = np.abs(img - bg).sum(axis=2) > 40
    rows = []
    for y0, y1 in bands(diff.any(axis=1), 15):
        boxes = [(x0, y0, x1, y1) for x0, x1 in bands(diff[y0:y1 + 1].any(axis=0), 15)]
        rows.append(boxes)
    return rows


def cut(img, bg, box):
    """The sprite in `box` with its background flooded away: RGBA, still at sheet scale."""
    x0, y0, x1, y1 = box
    pad = 6
    crop = img[max(0, y0 - pad):y1 + pad + 1, max(0, x0 - pad):x1 + pad + 1]
    near_bg = np.abs(crop - bg).sum(axis=2) < BG_TOLERANCE * 3
    h, w = near_bg.shape
    outside = np.zeros_like(near_bg)
    stack = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or outside[y, x] or not near_bg[y, x]:
            continue
        outside[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., :3] = crop.clip(0, 255)
    rgba[..., 3] = np.where(outside, 0, 255)
    return rgba


def to_pixels(rgba):
    """Back onto the art's pixel grid: each PIXEL x PIXEL block becomes its most common colour."""
    h, w = rgba.shape[:2]
    gh, gw = h // PIXEL, w // PIXEL
    out = np.zeros((gh, gw, 4), dtype=np.uint8)
    for gy in range(gh):
        for gx in range(gw):
            block = rgba[gy * PIXEL:(gy + 1) * PIXEL, gx * PIXEL:(gx + 1) * PIXEL].reshape(-1, 4)
            solid = block[block[:, 3] > 0]
            if len(solid) * 2 < len(block):
                continue  # mostly background
            core = solid[:, :3].astype(int)
            out[gy, gx, :3] = np.median(core, axis=0)
            out[gy, gx, 3] = 255
    return out


def palette(images, count):
    """One small palette for all of an animal's pictures (so its colours stay the same)."""
    pixels = np.concatenate([im[im[..., 3] > 0][:, :3] for im in images])
    strip = Image.fromarray(pixels.reshape(1, -1, 3).astype(np.uint8))
    quant = strip.quantize(colors=count, method=Image.Quantize.MEDIANCUT)
    pal = np.array(quant.getpalette()[:count * 3]).reshape(-1, 3)
    result = []
    for im in images:
        out = im.copy()
        solid = out[..., 3] > 0
        colours = out[solid][:, :3].astype(int)
        nearest = ((colours[:, None, :] - pal[None, :, :]) ** 2).sum(axis=2).argmin(axis=1)
        out[solid, :3] = pal[nearest]
        result.append(out)
    return result


def eyes(im):
    """The pupils: dark blobs with a white highlight in or right beside them (the art's eyes
    have one; nostrils, gills and mouths don't), biggest first; one eye (three-quarter view)
    gives the same point twice."""
    sums = im[..., :3].astype(int).sum(axis=2)
    solid = im[..., 3] > 0
    dark = solid & (sums < 170)
    white = solid & (sums > 660)
    seen = np.zeros_like(dark)
    blobs = []
    h, w = dark.shape
    for y in range(h):
        for x in range(w):
            if dark[y, x] and not seen[y, x]:
                stack, cells = [(y, x)], []
                while stack:
                    cy, cx = stack.pop()
                    if cy < 0 or cx < 0 or cy >= h or cx >= w or seen[cy, cx] or not dark[cy, cx]:
                        continue
                    seen[cy, cx] = True
                    cells.append((cy, cx))
                    stack += [(cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)]
                ys, xs = zip(*cells)
                y0, y1, x0, x1 = max(min(ys) - 1, 0), min(max(ys) + 2, h), max(min(xs) - 1, 0), min(max(xs) + 2, w)
                if len(cells) >= 12 and white[y0:y1, x0:x1].any():
                    blobs.append((len(cells), (sum(xs) / len(xs) + 0.5, sum(ys) / len(ys) + 0.5)))
    blobs.sort(reverse=True)
    found = [b[1] for b in blobs[:2] if b[0] * 3 >= blobs[0][0]] if blobs else []  # a second eye only if eye-sized
    found.sort()
    found = [(x / PIXEL, y / PIXEL) for x, y in found]  # (found at sheet scale)
    return found if len(found) == 2 else found * 2


def bbox(im):
    ys, xs = np.where(im[..., 3] > 0)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def main():
    img = np.asarray(Image.open(SHEET).convert("RGB")).astype(int)
    bg = np.median(img.reshape(-1, 3), axis=0)
    rows = sprites(img, bg)
    for (rescue_id, hatching), boxes in zip(ROWS, rows):
        raw = [cut(img, bg, b) for b in boxes]
        cuts = [to_pixels(r) for r in raw]
        found_eyes = [eyes(r) for r in raw]
        extra = cuts[0] if hatching else None
        stages = cuts[1:] if hatching else cuts
        stage_eyes = found_eyes[1:] if hatching else found_eyes
        side = max(max(im.shape[0], im.shape[1]) for im in stages) + 2
        points = []
        for i, im in enumerate(stages):
            canvas = np.zeros((side, side, 4), dtype=np.uint8)
            h, w = im.shape[:2]
            ox, oy = (side - w) // 2, side - h - 1  # centred, standing on the bottom
            canvas[oy:oy + h, ox:ox + w] = im
            Image.fromarray(canvas).save(os.path.join(OUT, f"{rescue_id}_{i + 1}.png"))
            bx0, by0, bx1, by1 = bbox(canvas)
            at = lambda share: (round((bx0 + (bx1 - bx0) * share[0]) / side, 3), round((by0 + (by1 - by0) * share[1]) / side, 3))
            if rescue_id in EYES:
                e = [tuple(xy) for xy in EYES[rescue_id][i]]
            else:
                e = [(round((ex + ox) / side, 3), round((ey + oy) / side, 3)) for ex, ey in stage_eyes[i]]
            assert len(e) == 2, (rescue_id, i, "no eyes found")
            points.append(e + [at(MOUTH[rescue_id]), at(WOUND[rescue_id])])
        if extra is not None:
            canvas = np.zeros((side, side, 4), dtype=np.uint8)
            h, w = extra.shape[:2]
            canvas[side - h - 1:side - 1, (side - w) // 2:(side - w) // 2 + w] = extra
            Image.fromarray(canvas).save(os.path.join(OUT, f"{rescue_id}_hatching.png"))
        wire(rescue_id, points, extra is not None)
        print(rescue_id, side, "px:", points)


def wire(rescue_id, points, hatching):
    """Points its RescueData at the six PNGs (and the hatching picture) with their points."""
    path = os.path.join(ROOT, f"data/rescues/{rescue_id}.tres")
    text = open(path).read()
    text = re.sub(r'\[ext_resource type="Texture2D" path="res://assets/animals/vet/%s_[^"]+" id="stage_[^"]+"\]\n' % rescue_id, "", text)
    names = [f"{rescue_id}_{i + 1}.png" for i in range(6)] + ([f"{rescue_id}_hatching.png"] if hatching else [])
    ids = [f"stage_{i + 1}" for i in range(6)] + (["stage_hatching"] if hatching else [])
    lines = "".join(f'[ext_resource type="Texture2D" path="res://assets/animals/vet/{n}" id="{i}"]\n' for n, i in zip(names, ids))
    head_end = text.index("\n[resource]")
    last_ext = text.rfind("[ext_resource", 0, head_end)
    at = text.index("\n", last_ext) + 1
    text = text[:at] + lines + text[at:]
    for key in ("stage_pictures", "stage_points", "stage_sizes", "hatching_picture"):
        text = re.sub(r"^%s = .*\n" % key, "", text, flags=re.M)
    block = "stage_pictures = Array[Texture2D]([%s])\n" % ", ".join(f'ExtResource("stage_{i + 1}")' for i in range(6))
    block += "stage_sizes = PackedFloat32Array(1, 1, 1, 1, 1, 1)\n"
    block += "stage_points = Array[PackedVector2Array]([%s])\n" % ", ".join(
        "PackedVector2Array(%s)" % ", ".join("%g, %g" % xy for xy in four) for four in points)
    if hatching:
        block += 'hatching_picture = ExtResource("stage_hatching")\n'
    at = text.index("\n", text.index("script = ", text.index("\n[resource]"))) + 1
    text = text[:at] + block + text[at:]
    text = re.sub(r"load_steps=\d+", "load_steps=%d" % (text.count("[ext_resource") + text.count("[sub_resource") + 1), text, count=1)
    open(path, "w").write(text)


if __name__ == "__main__":
    main()
