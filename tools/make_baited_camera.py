"""The baited Deep Camera: the owner's camera picture (deep_camera.png, from the buildings sheet)
with a bait canister hung on an arm beside it (BuildingData.closed_texture), at the picture's
own pixels (twice the game's). Re-run after the camera picture is cut again."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DEEP = os.path.join(HERE, '..', 'assets', 'buildings', 'deep')

LINE = (24, 16, 24, 255)       # the near-black outline
ARM = (70, 78, 98, 255)        # the camera box's slate
RED, LIT, SHADE = (200, 74, 58, 255), (232, 120, 96, 255), (140, 44, 36, 255)
HOLE = (90, 30, 26, 255)

im = Image.open(os.path.join(DEEP, 'deep_camera.png')).convert('RGBA')
px = im.load()


def box(x0, y0, x1, y1, colour):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            px[x, y] = colour


# the arm, out from the camera box's right side
box(46, 48, 54, 51, LINE)
box(47, 49, 54, 50, ARM)
# the canister: outline, red body, lit top-left, shaded bottom-right, mesh holes
box(54, 42, 63, 57, LINE)
box(55, 43, 62, 56, RED)
box(55, 43, 62, 44, LIT)
box(55, 43, 56, 56, LIT)
box(55, 55, 62, 56, SHADE)
box(61, 45, 62, 56, SHADE)
for y in (47, 50, 53):
    for x in (57, 59):
        px[x, y] = HOLE
        px[x + 1, y] = HOLE
im.save(os.path.join(DEEP, 'deep_camera_baited.png'))
print('deep_camera_baited.png')
