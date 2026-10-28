"""Create a non-graphic couple silhouette watch face for BLE upload testing."""
import json
from pathlib import Path

WIDTH = HEIGHT = 120
pixels = [[0] * WIDTH for _ in range(HEIGHT)]


def ellipse(cx, cy, rx, ry):
    for y in range(max(0, cy-ry), min(HEIGHT, cy+ry+1)):
        for x in range(max(0, cx-rx), min(WIDTH, cx+rx+1)):
            if ((x-cx)/rx)**2 + ((y-cy)/ry)**2 <= 1:
                pixels[y][x] = 1


def main():
    # Two facing heads, shoulders and a shared embrace.
    ellipse(41, 37, 18, 23)
    ellipse(79, 37, 18, 23)
    ellipse(35, 98, 31, 39)
    ellipse(85, 98, 31, 39)
    ellipse(60, 107, 39, 13)
    # Separate the two profiles at the upper centre.
    for y in range(11, 47):
        for x in range(57, 63):
            pixels[y][x] = 0
    data = bytearray((WIDTH // 8) * HEIGHT)
    for y, row in enumerate(pixels):
        for x, bit in enumerate(row):
            if bit:
                data[y * (WIDTH // 8) + x // 8] |= 1 << (7 - x % 8)
    design = {
        'title': 'Couple Silhouette - BLE Test',
        'background': '0x4800',
        'elements': [
            {'t': 'geometry', 'g': 'roundrect', 'x': 8, 'y': 8, 'w': 304, 'h': 224, 'c': 65535, 'f': False},
            {'t': 'text', 'v': 'LOVE', 'x': 120, 'y': 16, 'w': 90, 'h': 24, 's': 3, 'c': 65535},
            {'t': 'bitmap', 'x': 100, 'y': 54, 'w': WIDTH, 'h': HEIGHT, 'c': 65535, 'v': data.hex()},
            {'t': 'clock', 'x': 110, 'y': 193, 'w': 110, 'h': 28, 's': 2, 'c': 65535},
        ],
    }
    target = Path(__file__).resolve().parents[1] / 'Frontend_EXE401' / 'assets' / 'samples' / 'couple_silhouette_test.json'
    target.write_text(json.dumps(design, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(target)


if __name__ == '__main__':
    main()
