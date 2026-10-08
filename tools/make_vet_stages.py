"""Draws the rescue companions' six care-day pictures (newborn, young, growing, juvenile,
sub-adult, grown) as placeholder SVGs, and wires them into their RescueData
(stage_pictures + stage_points: where the eyes, mouth and wound are on each picture).

Each species is one drawing with a growth value p (0 = newborn .. 1 = grown): proportions
change with p (big head and eyes when young), colours and patterns mature. The figure is
fitted to a 96 x 96 canvas; the game scales it by RescueData.stage_sizes.

    python3 tools/make_vet_stages.py turtle        # one species
    python3 tools/make_vet_stages.py               # every species drawn here
Then: python3 tools/outline_sprites.py assets/animals/vet/*_[1-6].svg
      godot --headless --path . --import
"""
import math
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets/animals/vet")
SIZE = 96
FILL = 90  # the figure's longest side on the canvas
STAGES = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    a = [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(c2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(round(lerp(a[i], b[i], t)) for i in range(3))


class Figure:
    """Shapes in a free coordinate space, fitted onto the canvas at the end."""

    def __init__(self):
        self.shapes = []  # (kind, data, fill)
        self.points = {}

    def ellipse(self, cx, cy, rx, ry, fill, rot=0.0):
        self.shapes.append(("ellipse", (cx, cy, rx, ry, rot), fill))

    def circle(self, cx, cy, r, fill):
        self.shapes.append(("ellipse", (cx, cy, r, r, 0.0), fill))

    def poly(self, pts, fill):
        self.shapes.append(("poly", list(pts), fill))

    def mark(self, name, x, y):
        self.points[name] = (x, y)

    def _bounds(self):
        xs, ys = [], []
        for kind, d, _ in self.shapes:
            if kind == "ellipse":
                cx, cy, rx, ry, rot = d
                a = math.radians(rot)
                ex = math.sqrt((rx * math.cos(a)) ** 2 + (ry * math.sin(a)) ** 2)
                ey = math.sqrt((rx * math.sin(a)) ** 2 + (ry * math.cos(a)) ** 2)
                xs += [cx - ex, cx + ex]
                ys += [cy - ey, cy + ey]
            else:
                xs += [p[0] for p in d]
                ys += [p[1] for p in d]
        return min(xs), min(ys), max(xs), max(ys)

    def svg(self, comment):
        x0, y0, x1, y1 = self._bounds()
        s = FILL / max(x1 - x0, y1 - y0)
        ox = (SIZE - (x1 - x0) * s) / 2 - x0 * s
        oy = SIZE - 2 - (y1 - y0) * s - y0 * s  # standing on the bottom of the picture
        f = lambda x, y: (round(x * s + ox, 1), round(y * s + oy, 1))
        out = []
        for kind, d, fill in self.shapes:
            if kind == "ellipse":
                cx, cy, rx, ry, rot = d
                px, py = f(cx, cy)
                tr = f' transform="rotate({rot:g} {px:g} {py:g})"' if rot else ""
                out.append(f'  <ellipse cx="{px:g}" cy="{py:g}" rx="{round(rx * s, 1):g}" ry="{round(ry * s, 1):g}" fill="{fill}"{tr}/>')
            else:
                pts = " ".join("%g,%g" % f(x, y) for x, y in d)
                out.append(f'  <polygon points="{pts}" fill="{fill}"/>')
        points = {k: (round(f(*v)[0] / SIZE, 3), round(f(*v)[1] / SIZE, 3)) for k, v in self.points.items()}
        body = "\n".join(out)
        text = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" shape-rendering="crispEdges">\n'
                f'  <!-- {comment} -->\n{body}\n</svg>\n')
        return text, points


# ------------------------------------------------------------------------------- the species

def paddle(g, sx, sy, angle, length, width, fill, edge=None):
    """A flipper: wide near the body, tapering to a rounded tip, pointing at `angle` degrees."""
    a = math.radians(angle)
    d = (math.cos(a), math.sin(a))
    n = (-d[1], d[0])
    pts = []
    for t, w in ((0.0, 0.55), (0.25, 1.0), (0.55, 0.85), (0.8, 0.5), (1.0, 0.15)):
        pts.append((sx + d[0] * length * t + n[0] * width * w, sy + d[1] * length * t + n[1] * width * w))
    for t, w in ((1.0, 0.15), (0.8, 0.45), (0.55, 0.7), (0.25, 0.8), (0.0, 0.5)):
        pts.append((sx + d[0] * length * t - n[0] * width * w, sy + d[1] * length * t - n[1] * width * w))
    if edge:  # the pale trailing edge, just behind it
        g.poly([(x + n[0] * 1.2, y + n[1] * 1.2) for x, y in pts], edge)
    g.poly(pts, fill)
    return d, n


def turtle(p):
    """A green sea turtle, three-quarter view facing right, head up and looking at you.
    Newborn: oversized head and eyes, small round shell, short flippers, dark shell with a
    pale rim (as real green turtle hatchlings). Grown: big domed shell with clear scutes, olive
    and brown with radiating streaks, long refined flippers, a scaled head."""
    g = Figure()
    rx, ry = lerp(19, 33, p), lerp(15, 23, p)  # the shell: half its length, its height
    cx, base = 40, 66                          # middle of the shell, the shell's bottom edge
    head_r = lerp(14, 10.5, p)
    neck = lerp(2, 8, p)
    flip_len, flip_w = lerp(12, 30, p), lerp(4, 6.5, p)
    shell = mix("#2b3a33", "#5b6a33", p)        # hatchlings are dark; grown ones olive-brown
    seam = mix("#1e2a25", "#3f4a23", p)
    scute = mix("#36493f", "#768038", p)
    scute_light = mix("#435a4e", "#94914a", p)
    streak = mix("#3d5045", "#8f6b36", p)
    rim = mix("#dcdfd2", "#cdb874", p)
    belly = mix("#eceee3", "#e6d8a1", p)
    skin = mix("#33463b", "#6c7a4a", p)
    skin_dark = mix("#25332b", "#55603a", p)
    skin_light = mix("#4d6255", "#97a468", p)
    scale = mix("#5f7468", "#b9be82", p)
    edge = mix("#eef0e5", "#d2d1a2", p)
    # far side: the other front flipper and back flipper, darker, behind the body
    paddle(g, cx + rx * 0.55, base - ry * 0.35, -25, flip_len * 0.8, flip_w * 0.85, skin_dark)
    paddle(g, cx - rx * 0.7, base - 2, 160, flip_len * 0.4, flip_w * 0.75, skin_dark)
    # the belly rim and the shell's dome (seam colour underneath, scutes on top)
    g.ellipse(cx + 1, base - 1, rx * 1.0, lerp(3.2, 4.5, p), belly)
    dome = []
    for k in range(25):
        a = math.pi * k / 24
        dome.append((cx - math.cos(a) * rx, base - 2 - math.sin(a) * ry))
    g.poly(dome + [(cx + rx, base + 1), (cx - rx, base + 1)], rim)
    g.poly([(x, y + 0.2) for x, y in dome], seam)
    inner = [(cx - math.cos(math.pi * k / 24) * rx * 0.94, base - 3.5 - math.sin(math.pi * k / 24) * ry * 0.92) for k in range(25)]
    g.poly(inner, shell)
    # marginal scutes along the rim
    n = 8 + round(p * 5)
    for i in range(n):
        x = cx - rx * 0.92 + i * rx * 1.84 / (n - 1)
        g.poly([(x - rx * 0.07, base - 4), (x + rx * 0.07, base - 4), (x + rx * 0.06, base - 0.8), (x - rx * 0.06, base - 0.8)], mix(rim, scute, 0.55))
    # costal (side) scutes and vertebral (top) scutes, a lighter middle on each
    rows = ((0.36, 4, 0.19, 0.2), (0.7, 3, 0.16, 0.15))
    for height, count, w_share, h_share in rows:
        for i in range(count):
            span = 1.25 if count == 4 else 0.9
            x = cx - rx * span / 2 + i * rx * span / (count - 1)
            arc = math.sqrt(max(0.0, 1 - ((x - cx) / rx) ** 2))
            y = base - 3.5 - ry * 0.92 * arc * height
            w, h = rx * w_share, ry * h_share
            g.poly([(x - w, y), (x - w * 0.55, y - h), (x + w * 0.55, y - h), (x + w, y), (x + w * 0.55, y + h), (x - w * 0.55, y + h)], scute)
            if p >= 0.2:
                g.ellipse(x - w * 0.1, y - h * 0.15, w * 0.45, h * 0.4, scute_light)
            if p >= 0.6:  # radiating streaks on a mature shell
                g.poly([(x - 0.6, y - h * 0.6), (x + 0.6, y - h * 0.6), (x + w * 0.4, y + h * 0.8), (x + w * 0.4 - 1.4, y + h * 0.8)], streak)
    g.ellipse(cx - rx * 0.25, base - ry * 0.9, rx * 0.35, ry * 0.08, mix(scute_light, "#ffffff", 0.25))  # shine
    # near back flipper and front flipper (the wound is on the front one)
    paddle(g, cx - rx * 0.55, base - 1, 150, flip_len * 0.45, flip_w * 0.8, skin, edge)
    fx, fy = cx + rx * 0.45, base - ry * 0.2
    d, nn = paddle(g, fx, fy, 38, flip_len, flip_w, skin, edge)
    if p >= 0.35:  # scales along the flipper
        for k in range(3):
            t = 0.22 + k * 0.22
            g.ellipse(fx + d[0] * flip_len * t, fy + d[1] * flip_len * t, flip_w * 0.32, flip_w * 0.24, skin_light, 38)
    g.mark("wound", fx + d[0] * flip_len * 0.5, fy + d[1] * flip_len * 0.5)
    # neck and head, raised and turned to you
    nx, ny = cx + rx * 0.82, base - ry * 0.55
    g.poly([(nx - 3, ny + 5), (nx + neck + 2, ny - neck * 0.6 - 4), (nx + neck + 6, ny - neck * 0.6 + 4), (nx + 2, ny + 9)], skin)
    hx, hy = nx + neck + head_r * 0.55, ny - neck * 0.6 - head_r * 0.45
    g.ellipse(hx, hy, head_r, head_r * 0.9, skin)
    g.ellipse(hx + head_r * 0.45, hy + head_r * 0.2, head_r * 0.5, head_r * 0.42, skin)  # the snout
    g.ellipse(hx + head_r * 0.1, hy + head_r * 0.48, head_r * 0.72, head_r * 0.32, skin_light)  # pale jaw
    if p >= 0.3:  # head scales
        g.poly([(hx - head_r * 0.1, hy - head_r * 0.85), (hx + head_r * 0.35, hy - head_r * 0.82),
                (hx + head_r * 0.3, hy - head_r * 0.5), (hx - head_r * 0.05, hy - head_r * 0.52)], scale)
        g.ellipse(hx - head_r * 0.6, hy + head_r * 0.05, head_r * 0.2, head_r * 0.16, scale)
        g.ellipse(hx - head_r * 0.55, hy - head_r * 0.4, head_r * 0.17, head_r * 0.14, scale)
        g.ellipse(hx - head_r * 0.7, hy + head_r * 0.35, head_r * 0.15, head_r * 0.12, scale)
    eye_r = lerp(4.4, 2.8, p)
    for ex, near in ((hx - head_r * 0.25, False), (hx + head_r * 0.42, True)):
        ey = hy - head_r * 0.12
        r = eye_r * (1.0 if near else 0.85)
        g.circle(ex, ey, r + 0.7, skin_dark)
        g.circle(ex, ey, r, "#17130f")
        g.circle(ex + r * 0.32, ey - r * 0.35, r * 0.36, "#ffffff")
        g.circle(ex - r * 0.3, ey + r * 0.35, r * 0.15, "#ffffff")
        g.mark("eye_near" if near else "eye_far", ex, ey)
    my = hy + head_r * 0.5
    w = head_r * 0.7
    g.poly([(hx, my - 1.2), (hx + w * 0.5, my + 0.2), (hx + w, my - 1.6), (hx + w, my - 0.6),
            (hx + w * 0.5, my + 1.3), (hx, my - 0.2)], skin_dark)  # the smile
    g.mark("mouth", hx + head_r * 0.5, my)
    return g


SPECIES = {
    "turtle": ("home_turtle", turtle, "a green sea turtle in care, three-quarter view, growing day by day"),
}


# ---------------------------------------------------------------------------- writing it out

def write(key):
    rescue_id, draw, about = SPECIES[key]
    stage_points = []
    for i, p in enumerate(STAGES):
        text, pts = draw(p).svg(f"placeholder: {about} (day {i + 1} of 6)")
        open(os.path.join(OUT, f"{rescue_id}_{i + 1}.svg"), "w").write(text)
        stage_points.append([pts["eye_far"], pts["eye_near"], pts["mouth"], pts["wound"]])
    _wire(rescue_id, stage_points)
    print(rescue_id, "drawn:", stage_points)


def _wire(rescue_id, stage_points):
    """Points the RescueData at the six pictures and records their eyes / mouth / wound."""
    path = os.path.join(ROOT, f"data/rescues/{rescue_id}.tres")
    text = open(path).read()
    text = re.sub(r'\[ext_resource type="Texture2D" path="res://assets/animals/vet/%s_\d\.svg" id="stage_\d"\]\n' % rescue_id, "", text)
    lines = "".join(f'[ext_resource type="Texture2D" path="res://assets/animals/vet/{rescue_id}_{i + 1}.svg" id="stage_{i + 1}"]\n' for i in range(6))
    head_end = text.index("\n[resource]")
    last_ext = text.rfind("[ext_resource", 0, head_end)
    insert_at = text.index("\n", last_ext) + 1
    text = text[:insert_at] + lines + text[insert_at:]
    text = re.sub(r"^stage_pictures = .*\n", "", text, flags=re.M)
    text = re.sub(r"^stage_points = .*\n", "", text, flags=re.M)
    pics = "stage_pictures = Array[Texture2D]([%s])\n" % ", ".join(f'ExtResource("stage_{i + 1}")' for i in range(6))
    pts = "stage_points = Array[PackedVector2Array]([%s])\n" % ", ".join(
        "PackedVector2Array(%s)" % ", ".join("%g, %g" % xy for xy in four) for four in stage_points)
    at = text.index("\n", text.index("script = ", text.index("\n[resource]"))) + 1
    text = text[:at] + pics + pts + text[at:]
    text = re.sub(r"load_steps=\d+", "load_steps=%d" % (text.count("[ext_resource") + text.count("[sub_resource") + 1), text, count=1)
    open(path, "w").write(text)


if __name__ == "__main__":
    for key in (sys.argv[1:] or list(SPECIES)):
        write(key)
