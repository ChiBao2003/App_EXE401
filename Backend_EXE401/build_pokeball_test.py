"""Generate an importable large Poké Ball watch face for the 320x240 TFT."""
import json
from pathlib import Path


def lower_hemisphere_bitmap():
    width, height = 180, 90
    row_bytes = (width + 7) // 8
    image = bytearray(row_bytes * height)
    # This is the lower half of a 180x180 disk. The TFT paints set bits white
    # and clear bits in the face's background colour.
    for y in range(height):
        relative_y = y + 0.5
        for x in range(width):
            relative_x = x + 0.5 - width / 2
            if relative_x * relative_x + relative_y * relative_y <= 90 * 90:
                image[y * row_bytes + x // 8] |= 1 << (7 - x % 8)
    return image.hex()


def element(kind, x, y, w, h, color, **extra):
    return dict(t=kind, x=x, y=y, w=w, h=h, c=color, **extra)


def main():
    face = {
        'title': 'Poke Ball XL - Test',
        'background': '0x10A9',
        'elements': [
            element('geometry', 63, 17, 194, 194, 0x0000, g='circle', f=True),
            element('geometry', 70, 24, 180, 180, 0xF800, g='circle', f=True),
            element('bitmap', 70, 114, 180, 90, 0xFFFF, v=lower_hemisphere_bitmap()),
            element('geometry', 63, 105, 194, 14, 0x0000, g='rect', f=True),
            element('geometry', 136, 91, 48, 48, 0x0000, g='circle', f=True),
            element('geometry', 143, 98, 34, 34, 0xFFFF, g='circle', f=True),
            element('geometry', 151, 106, 18, 18, 0x0000, g='circle', f=False),
            element('clock', 125, 216, 70, 12, 0xFFFF, v='@T', s=1),
        ],
    }
    output = Path(__file__).resolve().parents[1] / 'Frontend_EXE401' / 'assets' / 'samples' / 'pokeball_xl_test.json'
    output.write_text(json.dumps(face, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(output)


if __name__ == '__main__':
    main()
