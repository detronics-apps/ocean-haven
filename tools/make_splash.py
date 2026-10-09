"""BlueHaven's loading picture (application/boot_splash/image): the title in pixel letters
and the line under it, see-through around them; on the web a loading bar with the game's
turtle swimming along it (export_presets.cfg head_include) sits just below.
Run: python3 tools/make_splash.py"""
from PIL import Image, ImageDraw, ImageFont

W, H, PX = 240, 135, 4          # drawn small, scaled up 4x: crisp pixels
## See-through around the words: the page (and Godot's bg_color, #102c42) is the one ocean
## colour behind it, filling the whole screen in portrait and landscape alike.
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

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
img.paste(title, ((W - title.width) // 2, 34), title)
img = img.resize((W * PX, H * PX), Image.NEAREST)
# The line under it at full resolution, so it reads easily (pixel letters at this size didn't).
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
text = "restore the ocean, one step at a time"
d = ImageDraw.Draw(img)
top = (34 + title.height) * PX + 14
width = d.textlength(text, font=font)
d.text(((W * PX - width) / 2, top), text, font=font, fill=(232, 238, 214, 255), stroke_width=3, stroke_fill=(8, 24, 38, 255))
## The web page's loading bar goes just under this line (export_presets.cfg: SUB_BOTTOM).
print("subtitle bottom", top + 40)
img.save("assets/ui/splash/splash.png")
print("assets/ui/splash/splash.png", img.size)
