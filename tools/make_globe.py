"""Draws the loading screen's little globe (export_presets.cfg, "bh-globe") as a picture, for the
Clue Board's last note ("It's all connected"): the same seeded land, the same light, not turning.
Run: python tools/make_globe.py  ->  assets/ui/globe/globe.png
"""
import math
import os
import struct
import zlib

R, MW, MH = 25, 64, 32
D = 2 * R + 1
seed = 11


def rand():
    global seed
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647


blobs = [[rand() * MW, 6 + rand() * (MH - 12), 3 + rand() * 6] for _ in range(9)]
land = []
for y in range(MH):
    for x in range(MW):
        on = False
        for bx, by, br in blobs:
            dx = min(abs(x - bx), MW - abs(x - bx))
            dy = y - by
            if dx * dx + dy * dy * 2.2 < br * br:
                on = True
        land.append(on)

rows = []
spin = 0.0
for py in range(-R, R + 1):
    row = bytearray([0])  # (PNG filter: none)
    for px in range(-R, R + 1):
        nx, ny = px / R, py / R
        d = nx * nx + ny * ny
        if d > 1:
            row += bytes([0, 0, 0, 0])
            continue
        nz = math.sqrt(1 - d)
        lat = math.asin(ny)
        lon = math.asin(max(-1.0, min(1.0, nx / max(math.cos(lat), 0.01)))) + spin * 6.283
        mx = int(math.floor(((lon / 6.283) % 1 + 1) % 1 * MW)) % MW
        my = int(math.floor((lat / 3.1416 + 0.5) * (MH - 1)))
        light = max(0.0, -0.45 * nx - 0.35 * ny + 0.82 * nz)
        shade = 0.62 + round(light * 4) / 4 * 0.4
        c = [92, 170, 90] if land[my * MW + mx] else [42, 128, 176]
        if land[my * MW + mx] and (my < 4 or my > MH - 5):
            c = [230, 240, 245]
        if d > 0.86:
            shade *= 0.8
        row += bytes([min(255, int(c[0] * shade)), min(255, int(c[1] * shade)), min(255, int(c[2] * shade)), 255])
    rows.append(bytes(row))


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)


png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', D, D, 8, 6, 0, 0, 0)) \
    + chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b'')
out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'ui', 'globe', 'globe.png')
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, 'wb') as f:
    f.write(png)
print('globe', D, 'x', D, '->', os.path.normpath(out))
