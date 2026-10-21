import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:eink_clock/core/display/tft_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auto-fit grows text with its box and supports larger font scales', () {
    final small = normalizeTftItem({
      't': 'clock',
      'x': 0,
      'y': 0,
      'w': 120,
      'h': 40,
      's': 20,
      'a': true,
    });
    final large = normalizeTftItem({
      't': 'clock',
      'x': 0,
      'y': 0,
      'w': 320,
      'h': 160,
      's': 20,
      'a': true,
    });
    expect(
      tftTextScale(large, '12:34'),
      greaterThan(tftTextScale(small, '12:34')),
    );
    expect(tftTextScale(large, '12:34'), greaterThan(5));
  });

  test('today schedule shows task labels and sensor preview is explicit', () {
    final today = DateTime(2026, 10, 19);
    final tasks = [
      {'hour': 14, 'minute': 0, 'label': 'Work'},
      {'hour': 8, 'minute': 30, 'label': 'Study'},
    ];
    expect(tftTodayScheduleText(today, tasks), '08:30 Study\n14:00 Work');
    expect(
      tftValue({
        't': 'calendar',
        'schedulePreview': tftTodayScheduleText(today, tasks),
      }, today),
      contains('Study'),
    );
    expect(
      tftValue({'t': 'superText', 'temperaturePreview': 28}, today),
      '28C',
    );
  });

  test('extra geometry names normalize to supported wire shapes', () {
    for (final shape in [
      'Hình elip',
      'Hình thoi',
      'Ngôi sao',
      'Dấu cộng',
      'Khung bo góc',
    ]) {
      final item = normalizeTftItem({
        't': 'geometry',
        'g': shape,
        'x': 0,
        'y': 0,
        'w': 30,
        'h': 30,
      });
      expect([
        'ellipse',
        'diamond',
        'star',
        'cross',
        'roundrect',
      ], contains(item['g']));
    }
  });
  test('MSB-first rows retain padding for a non-byte-aligned image', () {
    final rgba = Uint8List(9 * 2 * 4);
    for (var i = 0; i < 18; i++) {
      rgba[i * 4 + 3] = 255;
      if (i == 0 || i == 8 || i == 10) {
        rgba[i * 4] = rgba[i * 4 + 1] = rgba[i * 4 + 2] = 255;
      }
    }
    expect(ditherRgba(rgba, 9, 2), [0x80, 0x80, 0x40, 0x00]);
  });
  test('transparent pixels use the dark bitmap background', () {
    expect(ditherRgba(Uint8List.fromList([255, 255, 255, 0]), 1, 1), [0]);
  });
  test(
    '320x240 dither can be validated as a separate full-screen background',
    () {
      final pixels = Uint8List.fromList(List.filled(320 * 240 * 4, 255));
      final bitmap = ditherRgba(pixels, 320, 240, maxBytes: 9600);
      expect(bitmap.length, 9600);
      final design = validateTftDesign({
        'background': 0,
        'background_bitmap': bitmap
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
        'elements': [
          {'t': 'clock', 'x': 0, 'y': 0, 'w': 120, 'h': 48},
        ],
      });
      expect((design['background_bitmap'] as String).length, 19200);
    },
  );
  test('Floyd-Steinberg propagates quantization error', () {
    final gray = Uint8List.fromList(
      List.generate(8, (_) => [128, 128, 128, 255]).expand((e) => e).toList(),
    );
    expect(ditherRgba(gray, 8, 1), [0xaa]);
  });
  test('bitmap validation rejects malformed hex, wrong length and overflow', () {
    Map<String, dynamic> bitmap(String hex, int w, int h) => {
      't': 'bitmap',
      'v': hex,
      'w': w,
      'h': h,
    };
    expect(() => normalizeTftItem(bitmap('gg', 1, 1)), throwsFormatException);
    expect(() => normalizeTftItem(bitmap('ff', 9, 1)), throwsFormatException);
    expect(normalizeTftItem(bitmap('ffff', 9, 1))['v'], 'ffff');
    // Bitmap 32x33 = 132 bytes is now valid under the new 9600-byte full screen limit
    expect(normalizeTftItem(bitmap('ff' * 132, 32, 33))['v'], 'ff' * 132);
    final size = fitBitmapSize(320, 240);
    expect(size.width, 320);
    expect(size.height, 240);
    expect(
      ((size.width.toInt() + 7) ~/ 8) * size.height.toInt(),
      lessThanOrEqualTo(9600),
    );
  });
  test('all backend seed templates normalize inside 320x240', () {
    final seeds =
        jsonDecode(
              File(
                '../EXE401_Database/market_templates.json',
              ).readAsStringSync(),
            )
            as List;
    expect(seeds.length, 9);
    for (final seed in seeds) {
      final items = tftTemplateItems(
        Map<String, dynamic>.from(seed['design_json'] as Map),
      );
      for (final item in items) {
        expect((item['x'] as int) + (item['w'] as int), lessThanOrEqualTo(320));
        expect((item['y'] as int) + (item['h'] as int), lessThanOrEqualTo(240));
      }
    }
  });
  test(
    'palette preserves exact primary RGB565 values and LCD transliteration',
    () {
      expect(parseTftColor('#00ff00'), 0x07e0);
      expect(parseTftColor('FD20'), 0xfd20);
      expect(parseTftColor(rgb565Hex(0xfd20)), 0xfd20);
      expect(
        validateTftDesign({
          'background': '0xFFE0',
          'elements': [
            {'t': 'clock', 'x': 0, 'y': 0, 'w': 120, 'h': 48},
          ],
        })['background'],
        0xffe0,
      );
      expect(lcdText('Lịch trình Đọc sách'), 'Lich trinh Doc sach');
    },
  );
}
