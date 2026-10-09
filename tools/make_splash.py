"""BlueHaven's loading picture (application/boot_splash/image): the title in pixel letters
over a dark ocean with a few waves; the web page's spinning globe and swimming turtle
(export_presets.cfg head_include) sit in the space below the title.
Run: python3 tools/make_splash.py"""
from PIL import Image, ImageDraw, ImageFont
import random

W, H, PX = 240, 135, 4          # drawn small, scaled up 4x: crisp pixels
OCEAN_TOP, OCEAN_BOTTOM = (16, 44, 66), (10, 30, 48)
img = Image.new("RGB", (W, H))
d = ImageDraw.Draw(img)
for y in range(H):
    t = y / H
    d.line((0, y, W, y), fill=tuple(int(a + (b - a) * t) for a, b in zip(OCEAN_TOP, OCEAN_BOTTOM)))
random.seed(7)
for i in range(26):  # little wave crests
    x, y = random.randrange(W), random.randrange(70, H - 4)
    d.line((x, y, x + 3, y), fill=(42, 92, 120))
    d.point((x + 1, y - 1), fill=(60, 120, 150))
for i in range(30):  # bubbles / light flecks in the upper water
    x, y = random.randrange(W), random.randrange(4, 60)
    d.point((x, y), fill=(36, 80, 108))

def pixel_text(text, size, colour_top, colour_bottom, outline):
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
    box = font.getbbox(text)
    w, h = box[2] - box[0] + 4, box[3] - box[1] + 4
    mask = Image.new("L", (w, h))
    ImageDraw.Draw(mask).text((2 - box[0], 2 - box[1]), text, font=font, fill=255)
    mask = mask.point(lambda v: 255 if v > 110 else 0)
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    px = out.load()
    m = mask.load()
    for y in range(h):
        for x in range(w):
            if m[x, y]:
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    if px[x + 1 + dx, y + 1 + dy][3] == 0:
                        px[x + 1 + dx, y + 1 + dy] = outline + (255,)
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(int(a + (b - a) * t) for a, b in zip(colour_top, colour_bottom))
        for x in range(w):
            if m[x, y]:
                px[x + 1, y + 1] = c + (255,)
    return out

title = pixel_text("BlueHaven", 30, (190, 245, 240), (60, 190, 210), (8, 24, 38))
img.paste(title, ((W - title.width) // 2, 16), title)
sub = pixel_text("restore the ocean, one island at a time", 8, (230, 236, 210), (200, 210, 190), (8, 24, 38))
img.paste(sub, ((W - sub.width) // 2, 16 + title.height + 4), sub)
img = img.resize((W * PX, H * PX), Image.NEAREST)
img.save("assets/ui/splash/splash.png")
print("assets/ui/splash/splash.png", img.size)
