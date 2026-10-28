"""Build a 320x240 pixel landscape as one TFT bitmap plus a live clock."""
import json
from pathlib import Path

W, H = 320, 240
pixels = [[0] * W for _ in range(H)]


def dot(x, y):
    if 0 <= x < W and 0 <= y < H:
        pixels[y][x] = 1


def line(x1, y1, x2, y2, thickness=1):
    steps = max(abs(x2-x1), abs(y2-y1), 1)
    for i in range(steps + 1):
        x = round(x1 + (x2-x1)*i/steps)
        y = round(y1 + (y2-y1)*i/steps)
        for dy in range(thickness):
            for dx in range(thickness):
                dot(x+dx, y+dy)


def rect(x, y, w, h, fill=True):
    for yy in range(y, y+h):
        for xx in range(x, x+w):
            if fill or xx in (x, x+w-1) or yy in (y, y+h-1):
                dot(xx, yy)


def ellipse(cx, cy, rx, ry, fill=True):
    for y in range(max(0, cy-ry), min(H, cy+ry+1)):
        for x in range(max(0, cx-rx), min(W, cx+rx+1)):
            d = ((x-cx)/rx)**2 + ((y-cy)/ry)**2
            if d <= 1 and (fill or d >= 0.83):
                dot(x, y)


def bitmap_hex():
    image = bytearray((W // 8) * H)
    for y, row in enumerate(pixels):
        for x, on in enumerate(row):
            if on:
                image[y * (W // 8) + x // 8] |= 1 << (7-x % 8)
    return image.hex()


def main():
    rect(4, 4, 312, 232, False)
    # Distant sun, birds and clouds.
    ellipse(50, 52, 34, 34)
    for x, y, width in ((145, 21, 22), (171, 26, 38), (264, 27, 30)):
        rect(x, y, width, 2)
    line(203, 43, 210, 39); line(210, 39, 217, 43)
    line(225, 49, 230, 46); line(230, 46, 235, 49)
    # Mountains and ground.
    for peak_x, peak_y, base_l, base_r in ((131, 68, 91, 177), (221, 82, 171, 287)):
        for y in range(peak_y, 150):
            fraction = (y-peak_y) / (150-peak_y)
            left = round(peak_x + (base_l-peak_x)*fraction)
            right = round(peak_x + (base_r-peak_x)*fraction)
            for x in range(left, right+1):
                dot(x, y)
    rect(8, 148, 304, 2)
    for x, y, width in ((90, 158, 90), (107, 168, 55), (154, 185, 56)):
        rect(x, y, width, 2)
    # Tree, small bench and foreground reeds.
    rect(39, 92, 22, 129)
    ellipse(50, 65, 40, 42)
    rect(28, 205, 45, 17)
    rect(215, 202, 92, 5); rect(215, 214, 92, 5)
    for x in (225, 258, 291):
        rect(x, 196, 6, 31)
    for x in (83, 96, 188, 198, 311):
        line(x, 213, x-3, 207); line(x, 213, x+3, 206)
    rect(6, 228, 308, 5)
    # Leave the clock panel white and draw its frame last.
    for y in range(36, 90):
        for x in range(148, 311):
            pixels[y][x] = 0
    rect(148, 36, 163, 54, False)
    layout = {
        'title': 'Pixel Landscape Edition - Compact',
        'style': 'color_rgb565',
        'background': 65535,
        'elements': [
            {'t': 'bitmap', 'x': 0, 'y': 0, 'w': W, 'h': H, 'c': 0,
             'v': bitmap_hex(), 's': 1},
            {'t': 'clock', 'x': 152, 'y': 44, 'w': 155, 'h': 40,
             'c': 0, 'v': '@T', 's': 5},
        ],
    }
    output = Path(__file__).resolve().parents[1] / 'Frontend_EXE401' / 'assets' / 'samples' / 'pixel_landscape_compact.json'
    output.write_text(json.dumps(layout, indent=2) + '\n', encoding='utf-8')
    print(output)


if __name__ == '__main__':
    main()
