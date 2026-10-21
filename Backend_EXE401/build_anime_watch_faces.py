"""Build five small, original 1-bit TFT sprite layouts for the bundled gallery."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ROOT / "Frontend_EXE401" / "assets" / "samples"
MARKET = ROOT / "EXE401_Database" / "market_templates.json"


def sprite(kind):
    width, height = 48, 64
    pixels = [[0] * width for _ in range(height)]

    def dot(x, y):
        if 0 <= x < width and 0 <= y < height:
            pixels[y][x] = 1

    def ellipse(cx, cy, rx, ry):
        for y in range(max(0, cy - ry), min(height, cy + ry + 1)):
            for x in range(max(0, cx - rx), min(width, cx + rx + 1)):
                if ((x-cx)/rx)**2 + ((y-cy)/ry)**2 <= 1:
                    dot(x, y)

    def line(x1, y1, x2, y2, thickness=1):
        steps = max(abs(x2-x1), abs(y2-y1), 1)
        for i in range(steps + 1):
            x = round(x1 + (x2-x1)*i/steps)
            y = round(y1 + (y2-y1)*i/steps)
            for d in range(thickness):
                dot(x+d, y)

    ellipse(24, 51, 13, 11)
    ellipse(24, 25, 11, 13)
    line(17, 59, 13, 63, 3)
    line(30, 59, 34, 63, 3)
    if kind == "pikachu":
        line(17, 17, 9, 0, 5); line(29, 17, 39, 0, 5)
        ellipse(12, 31, 5, 5); ellipse(36, 31, 5, 5)
        line(35, 49, 47, 38, 4); line(42, 40, 37, 34, 4)
    elif kind == "naruto":
        for x in (10, 16, 23, 31, 38):
            line(x, 19, x-4, 7, 4)
        line(13, 20, 35, 20, 3)
        for y in (29, 33, 37):
            line(10, y, 17, y, 1); line(31, y, 39, y, 1)
    elif kind == "gojo":
        for x in range(12, 39, 5):
            line(x, 17, x + (x % 3) - 5, 3, 4)
        for y in range(23, 29):
            line(13, y, 35, y)
        line(34, 51, 46, 37, 2)
    elif kind == "han_li":
        ellipse(24, 8, 5, 8)
        line(13, 14, 35, 14, 2)
        line(36, 51, 42, 44, 2)
        ellipse(43, 42, 4, 5)
        line(16, 47, 8, 63, 3); line(32, 47, 40, 63, 3)
    elif kind == "wang_lin":
        for x in (13, 18, 24, 30, 35):
            line(x, 13, x-5, 0, 3)
        line(13, 18, 8, 55, 3); line(35, 18, 40, 59, 3)
        line(14, 47, 5, 63, 3); line(34, 47, 43, 63, 3)
    # Eye and mouth cutouts make the silhouette read at native size.
    if kind != "gojo":
        for y in (27, 28):
            for x in (19, 20, 28, 29):
                pixels[y][x] = 0
    for x in range(22, 27):
        pixels[34][x] = 0
    return ''.join(f'{sum(pixels[y][x + bit] << (7-bit) for bit in range(8)):02x}'
                   for y in range(height) for x in range(0, width, 8))


def item(t, x, y, w, h, color, value='', size=1, **extra):
    return dict(t=t, x=x, y=y, w=w, h=h, c=color, v=value, s=size, **extra)


def face(title, background, ink, tag, stats, kind, round_frame=False):
    frame = 'roundrect' if round_frame else 'rect'
    elements = [
        item('geometry', 5, 5, 310, 230, ink, g=frame, f=False),
        item('geometry', 9, 9, 302, 222, ink, g=frame, f=False),
        item('text', 18, 18, 270, 12, ink, tag),
        item('geometry', 14, 38, 205, 86, ink, g=frame, f=False),
        item('clock', 20, 56, 185, 45, ink, '@T', 5),
        item('calendar', 20, 111, 180, 16, ink, '@d/@M/@y', 2),
        item('geometry', 14, 143, 205, 1, ink, g='rect', f=True),
        item('text', 18, 155, 204, 20, ink, stats),
        item('text', 18, 183, 190, 12, ink, 'BAT 98% 28C'),
        item('bitmap', 254, 82, 48, 64, ink, sprite(kind)),
    ]
    return dict(title=title, style='color_rgb565', background=background,
                elements=elements)


FACES = [
    ('pokemon_clock.json', face('Pokemon Pikachu Edition', 0xFFE0, 0x0000,
                                'PIKACHU #025', 'LV. 50 HP 120/120', 'pikachu')),
    ('naruto_clock.json', face('Naruto Uzumaki Edition', 0xFD20, 0x0000,
                               'NARUTO #001 UZUMAKI #007', 'LV. 70 CHAKRA 150/150', 'naruto')),
    ('gojo_clock.json', face('Jujutsu Kaisen - Gojo Satoru', 0x10A9, 0xFFFF,
                             'GOJO SATORU #001', 'GRADE: SPECIAL CHAO 99%', 'gojo', True)),
    ('han_li_clock.json', face('Phàm Nhân Tu Tiên - Hàn Lập', 0x0A85, 0xFFFF,
                               'HAN LI #001', 'LEVEL: DEITY TRANS (Hóa Thần Kỳ)', 'han_li', True)),
    ('wang_lin_clock.json', face('Tiên Nghịch - Vương Lâm', 0x4800, 0xFFFF,
                                 'WANG LIN #001', 'LEVEL: ASCENDANT (Toàn Anh/Hóa Thần)', 'wang_lin', True)),
]


def main():
    SAMPLES.mkdir(parents=True, exist_ok=True)
    for name, design in FACES:
        (SAMPLES / name).write_text(json.dumps(design, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    templates = json.loads(MARKET.read_text(encoding='utf-8'))
    titles = {design['title'] for _, design in FACES}
    titles.update({'Pham Nhan Tu Tien - Han Li', 'Tien Nghich - Wang Lin'})
    templates = [t for t in templates if not (t.get('author') == 'AnimeStudio' and
                 t.get('design_json', {}).get('title') in titles)]
    for index, (_, design) in enumerate(FACES):
        templates.append(dict(author='AnimeStudio', thumbnail_url='', seed_key=f'anime_builtin_{index}', design_json=design,
                              likes=0, timestamp='2026-10-19T08:00:00Z'))
    MARKET.write_text(json.dumps(templates, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
