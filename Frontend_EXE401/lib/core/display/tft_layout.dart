import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

const tftPalette = <String, int>{
  'Cyan': 0x07ff,
  'Neon Green': 0x07e0,
  'Trắng': 0xffff,
  'Vàng': 0xffe0,
  'Đỏ': 0xf800,
  'Cam': 0xfd20,
  'Đen': 0x0000,
};

Color rgb565Color(int color) => Color.fromARGB(
  255,
  ((color >> 11) & 31) * 255 ~/ 31,
  ((color >> 5) & 63) * 255 ~/ 63,
  (color & 31) * 255 ~/ 31,
);
String rgb565Hex(int color) => (rgb565Color(color).toARGB32() & 0xffffff)
    .toRadixString(16)
    .padLeft(6, '0');

int parseTftColor(dynamic value, [int fallback = 0xffff]) {
  if (value is num) return value.toInt().clamp(0, 65535);
  if (value is String) {
    final hex = value.replaceFirst('#', '').replaceFirst('0x', '');
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed != null) {
      if (hex.length <= 4) return parsed;
      return (((parsed >> 16) & 0xf8) << 8) |
          (((parsed >> 8) & 0xfc) << 3) |
          ((parsed & 255) >> 3);
    }
  }
  return fallback;
}

String lcdText(String value) {
  const groups = {
    'a': 'àáảãạăằắẳẵặâầấẩẫậ',
    'A': 'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬ',
    'e': 'èéẻẽẹêềếểễệ',
    'E': 'ÈÉẺẼẸÊỀẾỂỄỆ',
    'i': 'ìíỉĩị',
    'I': 'ÌÍỈĨỊ',
    'o': 'òóỏõọôồốổỗộơờớởỡợ',
    'O': 'ÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢ',
    'u': 'ùúủũụưừứửữự',
    'U': 'ÙÚỦŨỤƯỪỨỬỮỰ',
    'y': 'ỳýỷỹỵ',
    'Y': 'ỲÝỶỸỴ',
    'd': 'đ',
    'D': 'Đ',
  };
  final out = StringBuffer();
  for (final rune in value.runes) {
    final c = String.fromCharCode(rune);
    if (rune >= 32 && rune <= 126) {
      out.write(c);
      continue;
    }
    for (final group in groups.entries) {
      if (group.value.contains(c)) {
        out.write(group.key);
        break;
      }
    }
  }
  return out.toString();
}

/// One canonical schema is used by Market, Studio, preview and firmware.
Map<String, dynamic> normalizeTftItem(Map<String, dynamic> input) {
  final rawType = input['t'] ?? input['type'] ?? 'text';
  final type = rawType == 'image' ? 'bitmap' : rawType;
  if (![
    'clock',
    'text',
    'geometry',
    'calendar',
    'superText',
    'bitmap',
  ].contains(type)) {
    throw FormatException('Loại phần tử không hỗ trợ: $type');
  }
  int number(String short, String long, int fallback) =>
      ((input[short] ?? input[long] ?? fallback) as num).round();
  final x = number('x', 'x', 0).clamp(0, 319);
  final y = number('y', 'y', 0).clamp(0, 239);
  final w = number('w', 'width', type == 'clock' ? 180 : 80);
  final h = number('h', 'height', type == 'clock' ? 48 : 24);
  if (w < 1 || h < 1 || x + w > 320 || y + h > 240) {
    throw const FormatException('Phần tử phải nằm trong màn hình 320×240');
  }
  var text =
      (input['v'] ??
              input['bitmapHex'] ??
              input['textContent'] ??
              input['superContent'] ??
              input['content'] ??
              '')
          .toString();
  if (type == 'bitmap') {
    final count = ((w + 7) ~/ 8) * h;
    if (count > 9600 ||
        text.length != count * 2 ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
      throw const FormatException(
        'Bitmap cần đúng số byte MSB-first, tối đa 9600 byte (320×240)',
      );
    }
  } else {
    text = lcdText(text);
    if (text.length > 64) {
      throw const FormatException('Văn bản tối đa 64 ký tự');
    }
  }
  final shape = input['g'] ?? input['shape'] ?? input['geoShape'] ?? 'rect';
  final size =
      input['s'] ??
      (((input[type == 'superText' ? 'superFontSize' : 'textFontSize'] ??
                      input['fontSize'] ??
                      (type == 'clock' ? 40 : 16))
                  as num) /
              8)
          .round();
  return {
    't': type,
    'v': text,
    'g': shape == 'Hình tròn'
        ? 'circle'
        : shape == 'Hình elip'
        ? 'ellipse'
        : shape == 'Hình thoi'
        ? 'diamond'
        : shape == 'Ngôi sao'
        ? 'star'
        : shape == 'Dấu cộng'
        ? 'cross'
        : shape == 'Khung bo góc'
        ? 'roundrect'
        : shape == 'Đường thẳng'
        ? 'line'
        : shape == 'Hình tam giác'
        ? 'triangle'
        : shape == 'Khung lập phương 3D'
        ? 'cube'
        : [
            'circle',
            'ellipse',
            'diamond',
            'star',
            'cross',
            'line',
            'rect',
            'roundrect',
            'triangle',
            'cube',
          ].contains(shape)
        ? shape
        : 'rect',
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    's': (size as num).toInt().clamp(1, 20),
    'a': input['a'] ?? input['autoFit'] ?? false,
    'c': parseTftColor(
      input['c'] ?? input['color565'] ?? input['color'],
      type == 'clock' ? 0x07ff : 0xffff,
    ),
    'i': input['i'] ?? input['textInvert'] ?? input['imageInvert'] ?? false,
    'f': input['f'] ?? input['fill'] ?? (input['geoFill'] == 'Tô đặc'),
  };
}

List<Map<String, dynamic>> tftTemplateItems(Map<String, dynamic> design) {
  final elements = design['elements'];
  if (elements is! List ||
      elements.length > 12 ||
      (elements.isEmpty && design['background_bitmap'] == null)) {
    throw const FormatException('Thiết kế cần từ 1 đến 12 phần tử');
  }
  return elements
      .map((e) => normalizeTftItem(Map<String, dynamic>.from(e as Map)))
      .toList();
}

Map<String, dynamic> validateTftDesign(Object? value) {
  if (value is! Map) throw const FormatException('JSON phải là một object');
  final design = Map<String, dynamic>.from(value);
  final rawBackground = design['background'] ?? design['bg_color'] ?? 0;
  final background =
      rawBackground is String &&
          RegExp(r'^(?:0[xX]|#)?[0-9a-fA-F]{1,4}$').hasMatch(rawBackground)
      ? int.parse(
          rawBackground.replaceFirst(RegExp(r'^(?:0[xX]|#)'), ''),
          radix: 16,
        )
      : rawBackground;
  if (background is! int || background < 0 || background > 65535) {
    throw const FormatException('background phải là số RGB565 từ 0 đến 65535');
  }
  final backgroundBitmap = design['background_bitmap'];
  if (backgroundBitmap != null &&
      (backgroundBitmap is! String ||
          backgroundBitmap.length != 19200 ||
          !RegExp(r'^[0-9a-fA-F]+$').hasMatch(backgroundBitmap))) {
    throw const FormatException(
      'background_bitmap phải là bitmap 320×240 MSB-first, 9600 byte hex',
    );
  }
  return {
    'title': (design['title'] ?? 'Mặt đồng hồ JSON').toString(),
    'background': background,
    'background_bitmap': backgroundBitmap,
    'elements': tftTemplateItems(design),
  };
}

String tftValue(Map<String, dynamic> item, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(now.hour)}:${two(now.minute)}';
  var value = item['t'] == 'clock'
      ? time
      : item['t'] == 'calendar'
      ? (item['schedulePreview'] ?? 'CHUA CO LICH HOM NAY').toString()
      : item['t'] == 'superText'
      ? (item['temperaturePreview'] == null
            ? '--C'
            : '${item['temperaturePreview']}C')
      : item['v'] as String;
  for (final entry in {
    '@T': time,
    '@h': '${now.hour}',
    '@m': '${now.minute}',
    '@s': '${now.second}',
    '@d': '${now.day}',
    '@M': '${now.month}',
    '@y': '${now.year}',
  }.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value;
}

String tftTodayScheduleText(DateTime now, List<Map<String, dynamic>> entries) {
  final sorted =
      entries
          .where((entry) => entry['hour'] is int && entry['minute'] is int)
          .toList()
        ..sort(
          (a, b) => ((a['hour'] as int) * 60 + a['minute'] as int).compareTo(
            (b['hour'] as int) * 60 + b['minute'] as int,
          ),
        );
  if (sorted.isEmpty) return 'CHUA CO LICH HOM NAY';
  return sorted
      .map(
        (entry) =>
            '${(entry['hour'] as int).toString().padLeft(2, '0')}:${(entry['minute'] as int).toString().padLeft(2, '0')} ${lcdText((entry['label'] ?? '').toString())}',
      )
      .join('\n');
}

int tftTextScale(Map<String, dynamic> item, String value) {
  final limit = (item['s'] as num).toInt().clamp(1, 20);
  if (item['a'] != true) return limit;
  final width = (item['w'] as num).toInt();
  final height = (item['h'] as num).toInt();
  for (var scale = limit; scale >= 1; scale--) {
    final columns = width ~/ (6 * scale);
    final rows = height ~/ (8 * scale);
    if (columns < 1 || rows < 1) continue;
    var usedRows = 1;
    var usedColumns = 0;
    for (final code in value.codeUnits) {
      if (code == 10) {
        usedRows++;
        usedColumns = 0;
      } else {
        if (usedColumns == columns) {
          usedRows++;
          usedColumns = 0;
        }
        usedColumns++;
      }
    }
    if (usedRows <= rows) return scale;
  }
  return 1;
}

/// Keep the requested dimensions within the physical 320×240 canvas.
Size fitBitmapSize(int width, int height) {
  return Size(width.clamp(1, 320).toDouble(), height.clamp(1, 240).toDouble());
}

Uint8List ditherRgba(
  Uint8List rgba,
  int width,
  int height, {
  int maxBytes = 9600,
}) {
  if (width < 1 ||
      height < 1 ||
      rgba.length != width * height * 4 ||
      ((width + 7) ~/ 8) * height > maxBytes) {
    throw const FormatException('Kích thước bitmap không hợp lệ');
  }
  final gray = List<double>.generate(
    width * height,
    (i) =>
        ((299 * rgba[i * 4] + 587 * rgba[i * 4 + 1] + 114 * rgba[i * 4 + 2]) /
            1000) *
        rgba[i * 4 + 3] /
        255,
  );
  final rowBytes = (width + 7) ~/ 8;
  final result = Uint8List(rowBytes * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x;
      final next = gray[i] < 128 ? 0.0 : 255.0;
      final error = gray[i] - next;
      if (next != 0) result[y * rowBytes + x ~/ 8] |= 1 << (7 - x % 8);
      if (x + 1 < width) gray[i + 1] += error * 7 / 16;
      if (y + 1 < height) {
        if (x > 0) gray[i + width - 1] += error * 3 / 16;
        gray[i + width] += error * 5 / 16;
        if (x + 1 < width) gray[i + width + 1] += error / 16;
      }
    }
  }
  return result;
}

Future<String> processImageTo1BitHex(
  Uint8List bytes,
  int width,
  int height, {
  int maxBytes = 9600,
}) async {
  if (width < 1 || height < 1 || ((width + 7) ~/ 8) * height > maxBytes) {
    throw FormatException('Ảnh bitmap tối đa $maxBytes byte');
  }
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: width,
    targetHeight: height,
  );
  final frame = await codec.getNextFrame();
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      frame.image,
      Rect.fromLTWH(
        0,
        0,
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw const FormatException('Không đọc được ảnh');
      return ditherRgba(
        data.buffer.asUint8List(),
        width,
        height,
        maxBytes: maxBytes,
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } finally {
      image.dispose();
      picture.dispose();
    }
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}

class TftPreview extends StatelessWidget {
  final Map<String, dynamic> design;
  final DateTime? now;
  const TftPreview({super.key, required this.design, this.now});
  @override
  Widget build(BuildContext context) {
    try {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: CustomPaint(
          painter: TftPreviewPainter(
            tftTemplateItems(design),
            background: parseTftColor(
              design['background'] ?? design['bg_color'],
              0,
            ),
            backgroundBitmap: design['background_bitmap'] as String?,
            now: now,
          ),
        ),
      );
    } catch (_) {
      return const Center(
        child: Text(
          'Mẫu cần cập nhật định dạng TFT',
          textAlign: TextAlign.center,
        ),
      );
    }
  }
}

class TftPreviewPainter extends CustomPainter {
  final List<Map<String, dynamic>> items;
  final int background;
  final String? backgroundBitmap;
  final DateTime now;
  TftPreviewPainter(
    this.items, {
    this.background = 0,
    this.backgroundBitmap,
    DateTime? now,
  }) : now = now ?? DateTime.now();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 240);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 320, 240));
    canvas.drawColor(rgb565Color(background), BlendMode.src);
    if (backgroundBitmap != null) {
      paintTftItem(
        canvas,
        {
          't': 'bitmap',
          'v': backgroundBitmap!,
          'x': 0,
          'y': 0,
          'w': 320,
          'h': 240,
          'c': 0xffff,
          'i': false,
        },
        now,
        background,
      );
    }
    for (final item in items) {
      paintTftItem(canvas, item, now, background);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TftPreviewPainter oldDelegate) => true;
}

void paintTftItem(
  Canvas canvas,
  Map<String, dynamic> item,
  DateTime now,
  int background,
) {
  final x = (item['x'] as num).toDouble(), y = (item['y'] as num).toDouble();
  final w = (item['w'] as num).toDouble(), h = (item['h'] as num).toDouble();
  final rect = Rect.fromLTWH(x, y, w, h);
  final inverse = item['i'] == true;
  final fg = rgb565Color(inverse ? 0 : item['c'] as int);
  final bg = rgb565Color(inverse ? 0xffff : background);
  final paint = Paint()
    ..color = fg
    ..isAntiAlias = false;
  if (item['t'] == 'geometry') {
    paint.style = item['f'] == true ? PaintingStyle.fill : PaintingStyle.stroke;
    if (item['g'] == 'circle') {
      final r = math.min(w, h) / 2;
      canvas.drawCircle(Offset(x + r, y + r), r, paint);
    } else if (item['g'] == 'line') {
      canvas.drawLine(Offset(x, y), Offset(x + w - 1, y + h - 1), paint);
    } else if (item['g'] == 'triangle') {
      final path = Path()
        ..moveTo(x + w / 2, y)
        ..lineTo(x, y + h - 1)
        ..lineTo(x + w - 1, y + h - 1)
        ..close();
      canvas.drawPath(path, paint);
    } else if (item['g'] == 'ellipse') {
      canvas.drawOval(rect, paint);
    } else if (item['g'] == 'diamond') {
      final path = Path()
        ..moveTo(x + w / 2, y)
        ..lineTo(x + w - 1, y + h / 2)
        ..lineTo(x + w / 2, y + h - 1)
        ..lineTo(x, y + h / 2)
        ..close();
      canvas.drawPath(path, paint);
    } else if (item['g'] == 'cross') {
      final bar = math.max(1.0, math.min(w, h) / 3);
      final path = Path()
        ..addRect(Rect.fromLTWH(x + (w - bar) / 2, y, bar, h))
        ..addRect(Rect.fromLTWH(x, y + (h - bar) / 2, w, bar));
      canvas.drawPath(path, paint);
    } else if (item['g'] == 'star') {
      final path = Path();
      for (var point = 0; point < 10; point++) {
        final angle = -math.pi / 2 + point * math.pi / 5;
        final radius = point.isEven ? 0.5 : 0.22;
        final px = x + w / 2 + math.cos(angle) * w * radius;
        final py = y + h / 2 + math.sin(angle) * h * radius;
        if (point == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    } else if (item['g'] == 'cube') {
      final depth = math.max(1.0, math.min(w, h) / 4);
      final front = Rect.fromLTWH(x, y + depth, w - depth, h - depth);
      final back = Rect.fromLTWH(x + depth, y, w - depth, h - depth);
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(front, paint);
      canvas.drawRect(back, paint);
      for (final (a, b) in [
        (front.topLeft, back.topLeft),
        (front.topRight, back.topRight),
        (front.bottomLeft, back.bottomLeft),
        (front.bottomRight, back.bottomRight),
      ]) {
        canvas.drawLine(a, b, paint);
      }
    } else if (item['g'] == 'roundrect') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(item['f'] == true ? 0 : 0.5),
          const Radius.circular(8),
        ),
        paint,
      );
    } else {
      canvas.drawRect(rect.deflate(item['f'] == true ? 0 : 0.5), paint);
    }
    return;
  }
  if (item['t'] == 'bitmap') {
    final hex = item['v'] as String;
    final rowBytes = (w.toInt() + 7) ~/ 8;
    canvas.drawRect(rect, Paint()..color = bg);
    for (var py = 0; py < h; py++) {
      for (var px = 0; px < w; px++) {
        final offset = (py * rowBytes + px ~/ 8) * 2;
        final byte = int.parse(hex.substring(offset, offset + 2), radix: 16);
        if (byte & (1 << (7 - px % 8)) != 0) {
          canvas.drawRect(Rect.fromLTWH(x + px, y + py, 1, 1), paint);
        }
      }
    }
    return;
  }
  if (inverse) canvas.drawRect(rect, Paint()..color = bg);
  canvas.save();
  canvas.clipRect(rect);
  final value = tftValue(item, now);
  final scale = tftTextScale(item, value);
  var dx = 0, dy = 0;
  for (final rune in value.runes) {
    if (rune == 10) {
      dx = 0;
      dy += 8 * scale;
      continue;
    }
    if (dx + 6 * scale > w) {
      dx = 0;
      dy += 8 * scale;
    }
    if (dy + 8 * scale > h) break;
    final text = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(rune),
        style: TextStyle(
          color: fg,
          fontFamily: 'monospace',
          fontSize: 8.0 * scale,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(x + dx, y + dy));
    text.dispose();
    dx += 6 * scale;
  }
  canvas.restore();
}
