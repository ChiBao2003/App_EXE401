import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/bluetooth/spp_service.dart';
import '../../core/display/tft_layout.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

enum ObjectType { clock, text, geometry, image, calendar, superText }

class DesignObject {
  final String id;
  ObjectType type;
  double x;
  double y;
  double width;
  double height;

  // Clock props
  String clockFont;

  // Text props
  String textContent;
  int textFontSize;
  bool autoFit;
  bool textInvert;

  // Geometry props
  String geoShape;
  String geoFill;
  double geoSize;
  double geoThickness;

  // Image props
  String imageSource;
  String bitmapHex;
  int color565;
  bool imageInvert;
  bool imageBackground;

  // Calendar props
  String calFont;

  // SuperText props
  String superContent;
  String superFont;
  double superFontSize;
  double superPadding;
  int superColorIndex; // 0=white, 1=black, 2=red

  DesignObject({
    required this.id,
    required this.type,
    this.x = 10,
    this.y = 10,
    this.width = 80,
    this.height = 30,
    this.clockFont = 'Outfit Mono Bold',
    this.textContent = '@T @d/@M/@y',
    this.textFontSize = 12,
    this.autoFit = true,
    this.textInvert = false,
    this.geoShape = 'Hình chữ nhật',
    this.geoFill = 'Không có',
    this.geoSize = 40,
    this.geoThickness = 1,
    this.imageSource = '',
    this.bitmapHex = '',
    this.color565 = 0xffff,
    this.imageInvert = false,
    this.imageBackground = false,
    this.calFont = 'Font5x7',
    this.superContent = '@h:@m',
    this.superFont = 'Outfit',
    this.superFontSize = 32,
    this.superPadding = 0,
    this.superColorIndex = 1,
  });

  String get label {
    switch (type) {
      case ObjectType.clock:
        return 'Đồng hồ';
      case ObjectType.text:
        return 'Văn bản';
      case ObjectType.geometry:
        return 'Hình học';
      case ObjectType.image:
        return 'Ảnh Bitmap';
      case ObjectType.calendar:
        return 'Lịch biểu';
      case ObjectType.superText:
        return 'Cảm biến';
    }
  }

  IconData get icon {
    switch (type) {
      case ObjectType.clock:
        return Icons.schedule_rounded;
      case ObjectType.text:
        return Icons.title_rounded;
      case ObjectType.geometry:
        return Icons.category_rounded;
      case ObjectType.image:
        return Icons.image_rounded;
      case ObjectType.calendar:
        return Icons.calendar_today_rounded;
      case ObjectType.superText:
        return Icons.monitor_heart_rounded;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'clockFont': clockFont,
    'textContent': textContent,
    'textFontSize': textFontSize,
    'autoFit': autoFit,
    'textInvert': textInvert,
    'geoShape': geoShape,
    'geoFill': geoFill,
    'geoSize': geoSize,
    'geoThickness': geoThickness,
    'imageSource': imageSource,
    'bitmapHex': bitmapHex,
    'color565': color565,
    'imageInvert': imageInvert,
    'imageBackground': imageBackground,
    'calFont': calFont,
    'superContent': superContent,
    'superFont': superFont,
    'superFontSize': superFontSize,
    'superPadding': superPadding,
    'superColorIndex': superColorIndex,
  };

  factory DesignObject.fromJson(Map<String, dynamic> json) {
    return DesignObject(
        id: json['id'] ?? 'obj_${DateTime.now().millisecondsSinceEpoch}',
        type: ObjectType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ObjectType.text,
        ),
        x: (json['x'] as num?)?.toDouble() ?? 10.0,
        y: (json['y'] as num?)?.toDouble() ?? 10.0,
        width: (json['width'] as num?)?.toDouble() ?? 80.0,
        height: (json['height'] as num?)?.toDouble() ?? 30.0,
      )
      ..clockFont = json['clockFont'] ?? 'Outfit Mono Bold'
      ..textContent = json['textContent'] ?? '@T @d/@M/@y'
      ..textFontSize = json['textFontSize'] ?? 12
      ..autoFit = json['autoFit'] ?? true
      ..textInvert = json['textInvert'] ?? false
      ..geoShape = json['geoShape'] ?? 'Hình chữ nhật'
      ..geoFill = json['geoFill'] ?? 'Không có'
      ..geoSize = (json['geoSize'] as num?)?.toDouble() ?? 40.0
      ..geoThickness = (json['geoThickness'] as num?)?.toDouble() ?? 1.0
      ..bitmapHex = json['bitmapHex'] ?? ''
      ..color565 = json['color565'] ?? 0xffff
      ..imageSource = json['imageSource'] ?? ''
      ..imageInvert = json['imageInvert'] ?? false
      ..imageBackground = json['imageBackground'] ?? false
      ..calFont = json['calFont'] ?? 'Font5x7'
      ..superContent = json['superContent'] ?? '@h:@m'
      ..superFont = json['superFont'] ?? 'Outfit'
      ..superFontSize = (json['superFontSize'] as num?)?.toDouble() ?? 32.0
      ..superPadding = (json['superPadding'] as num?)?.toDouble() ?? 0.0
      ..superColorIndex = json['superColorIndex'] ?? 1;
  }
}

// ============================================================================
// MAIN SCREEN
// ============================================================================

class DesignScreen extends StatefulWidget {
  const DesignScreen({super.key});

  @override
  State<DesignScreen> createState() => _DesignScreenState();
}

class _DesignScreenState extends State<DesignScreen> {
  final List<DesignObject> _objects = [];
  int _selectedIndex = 0;
  int _idCounter = 100;
  bool _initializedFromArgs = false;
  int _background = 0;
  String? _backgroundBitmapHex;
  final Map<String, Size> _requestedBitmapSizes = {};
  final Map<String, int> _bitmapResizeVersions = {};
  final Map<String, List<Map<String, dynamic>>> _schedulePreview = {};

  // Canvas View Controls
  bool _showGrid = true;
  bool _isZoomed200 = true;
  String _refreshRate = 'Theo Phút';

  // Real Undo/Redo Stacks
  final List<List<DesignObject>> _undoStack = [];
  final List<List<DesignObject>> _redoStack = [];
  final List<String?> _undoBitmapBackgrounds = [];
  final List<String?> _redoBitmapBackgrounds = [];

  // Resolution
  int _canvasWidth = 320;
  int _canvasHeight = 240;

  @override
  void initState() {
    super.initState();
    _initDefaultCanvasObjects();
    _loadSchedulePreview();
  }

  Future<void> _loadSchedulePreview() async {
    final prefs = await SharedPreferences.getInstance();
    for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      final raw = prefs.getString('tft_schedule_$day');
      if (raw == null) continue;
      try {
        final entries = (jsonDecode(raw) as List)
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
        _schedulePreview[day] = entries;
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _initDefaultCanvasObjects() {
    // 4 Default elements matching Stitch Screen 12 layout
    _objects.clear();
    _objects.addAll([
      DesignObject(
        id: 'el-clock',
        type: ObjectType.clock,
        x: 48,
        y: 65,
        width: 160,
        height: 46,
        clockFont: 'Outfit Mono Bold',
        textInvert: false,
        textFontSize: 40,
        color565: 0x07ff,
      ),
      DesignObject(
        id: 'el-weather',
        type: ObjectType.text,
        x: 8,
        y: 8,
        width: 60,
        height: 24,
        textContent: '28C May',
        textFontSize: 11,
      ),
      DesignObject(
        id: 'el-battery',
        type: ObjectType.text,
        x: 235,
        y: 8,
        width: 72,
        height: 20,
        textContent: '[||||] 85%',
        textFontSize: 10,
      ),
      DesignObject(
        id: 'el-date',
        type: ObjectType.text,
        x: 12,
        y: 190,
        width: 110,
        height: 22,
        textContent: 'THU 4, 24/10',
        textFontSize: 11,
      ),
    ]);
    _selectedIndex = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromArgs) {
      _initializedFromArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args?['template'] is Map) {
        try {
          final template = Map<String, dynamic>.from(args!['template'] as Map);
          final items = tftTemplateItems(template);
          _background = parseTftColor(
            template['background'] ?? template['bg_color'],
            0,
          );
          _backgroundBitmapHex = template['background_bitmap'] as String?;
          _objects.clear();
          for (final item in items) {
            _objects.add(
              DesignObject(
                id: 'obj_${_idCounter++}',
                type: ObjectType.values.byName(
                  item['t'] == 'bitmap' ? 'image' : item['t'],
                ),
                x: (item['x'] as num).toDouble(),
                y: (item['y'] as num).toDouble(),
                width: (item['w'] as num).toDouble(),
                height: (item['h'] as num).toDouble(),
                textContent: item['v'],
                superContent: item['v'],
                bitmapHex: item['t'] == 'bitmap' ? item['v'] : '',
                textFontSize: (item['s'] as int) * 8,
                autoFit: item['a'] == true,
                superFontSize: (item['s'] as int) * 8.0,
                color565: item['c'],
                textInvert: item['i'],
                imageInvert: item['i'],
                geoShape: item['g'] == 'circle'
                    ? 'Hình tròn'
                    : item['g'] == 'roundrect'
                    ? 'roundrect'
                    : item['g'] == 'line'
                    ? 'Đường thẳng'
                    : item['g'] == 'triangle'
                    ? 'Hình tam giác'
                    : item['g'] == 'cube'
                    ? 'Khung lập phương 3D'
                    : 'Hình chữ nhật',
                geoFill: item['f'] ? 'Tô đặc' : 'Không có',
              ),
            );
          }
          _selectedIndex = 0;
        } catch (e) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Mẫu không hợp lệ: $e')));
            }
          });
        }
      }
      if (args != null && args['preview'] != null) {
        _recordHistory();
        _objects.add(
          DesignObject(
            id: 'obj_${_idCounter++}',
            type: ObjectType.superText,
            superContent: args['preview'].toString(),
            superFontSize: 36,
            x: 40,
            y: 35,
          ),
        );
        _selectedIndex = _objects.length - 1;
      }
    }
  }

  // --------------------------------------------------------------------------
  // HISTORY: Real Undo & Redo
  // --------------------------------------------------------------------------
  void _recordHistory() {
    final snapshot = _objects
        .map((e) => DesignObject.fromJson(e.toJson()))
        .toList();
    _undoStack.add(snapshot);
    _undoBitmapBackgrounds.add(_backgroundBitmapHex);
    if (_undoStack.length > 25) {
      _undoStack.removeAt(0);
      _undoBitmapBackgrounds.removeAt(0);
    }
    _redoStack.clear();
    _redoBitmapBackgrounds.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final current = _objects
        .map((e) => DesignObject.fromJson(e.toJson()))
        .toList();
    _redoStack.add(current);
    _redoBitmapBackgrounds.add(_backgroundBitmapHex);

    final previous = _undoStack.removeLast();
    final previousBackground = _undoBitmapBackgrounds.removeLast();
    setState(() {
      _backgroundBitmapHex = previousBackground;
      _objects.clear();
      _objects.addAll(
        previous.map((e) => DesignObject.fromJson(e.toJson())).toList(),
      );
      if (_selectedIndex >= _objects.length) {
        _selectedIndex = _objects.isNotEmpty ? _objects.length - 1 : -1;
      }
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final current = _objects
        .map((e) => DesignObject.fromJson(e.toJson()))
        .toList();
    _undoStack.add(current);
    _undoBitmapBackgrounds.add(_backgroundBitmapHex);

    final next = _redoStack.removeLast();
    final nextBackground = _redoBitmapBackgrounds.removeLast();
    setState(() {
      _backgroundBitmapHex = nextBackground;
      _objects.clear();
      _objects.addAll(
        next.map((e) => DesignObject.fromJson(e.toJson())).toList(),
      );
      if (_selectedIndex >= _objects.length) {
        _selectedIndex = _objects.isNotEmpty ? _objects.length - 1 : -1;
      }
    });
  }

  // --------------------------------------------------------------------------
  // OBJECT MANAGEMENT
  // --------------------------------------------------------------------------
  DesignObject? get _selected =>
      _selectedIndex >= 0 && _selectedIndex < _objects.length
      ? _objects[_selectedIndex]
      : null;

  Future<void> _resizeBitmap(DesignObject obj, int width, int height) async {
    if (obj.imageBackground) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ảnh nền luôn có kích thước 320×240.')),
      );
      return;
    }
    if (obj.imageSource.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ảnh nhập từ JSON không có ảnh gốc; chọn lại ảnh trước khi đổi kích thước.',
          ),
        ),
      );
      return;
    }
    final size = fitBitmapSize(width, height);
    _requestedBitmapSizes[obj.id] = size;
    final version = (_bitmapResizeVersions[obj.id] ?? 0) + 1;
    _bitmapResizeVersions[obj.id] = version;
    try {
      final bytes = await XFile(obj.imageSource).readAsBytes();
      final hex = await processImageTo1BitHex(
        bytes,
        size.width.toInt(),
        size.height.toInt(),
      );
      if (!mounted ||
          !_objects.contains(obj) ||
          _bitmapResizeVersions[obj.id] != version) {
        return;
      }
      _recordHistory();
      setState(() {
        obj.width = size.width;
        obj.height = size.height;
        obj.x = obj.x.clamp(0, 320 - size.width).toDouble();
        obj.y = obj.y.clamp(0, 240 - size.height).toDouble();
        obj.bitmapHex = hex;
      });
      _requestedBitmapSizes.remove(obj.id);
    } catch (e) {
      if (mounted && _bitmapResizeVersions[obj.id] == version) {
        _requestedBitmapSizes.remove(obj.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đổi kích thước ảnh: $e')),
        );
      }
    }
  }

  Future<void> _toggleBackgroundImage(DesignObject obj, bool enabled) async {
    _bitmapResizeVersions[obj.id] = (_bitmapResizeVersions[obj.id] ?? 0) + 1;
    _requestedBitmapSizes.remove(obj.id);
    if (!enabled) {
      _recordHistory();
      setState(() {
        obj.imageBackground = false;
        obj.x = 20;
        obj.y = 20;
        obj.width = 24;
        obj.height = 24;
        _backgroundBitmapHex = null;
      });
      await _resizeBitmap(obj, 24, 24);
      return;
    }
    if (obj.imageSource.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn ảnh gốc từ thiết bị để làm ảnh nền.'),
        ),
      );
      return;
    }
    try {
      final bytes = await XFile(obj.imageSource).readAsBytes();
      final hex = await processImageTo1BitHex(bytes, 320, 240, maxBytes: 9600);
      if (!mounted || !_objects.contains(obj)) return;
      _recordHistory();
      setState(() {
        for (final item in _objects) {
          item.imageBackground = false;
        }
        obj.imageBackground = true;
        obj.x = 0;
        obj.y = 0;
        obj.width = 320;
        obj.height = 240;
        _backgroundBitmapHex = hex;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể tạo ảnh nền: $e')));
      }
    }
  }

  void _addObject(ObjectType type) {
    if (_objects.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ESP32 hỗ trợ tối đa 12 phần tử.')),
      );
      return;
    }
    _recordHistory();
    final newId = 'obj_${_idCounter++}';
    final obj = DesignObject(
      id: newId,
      type: type,
      textFontSize: type == ObjectType.clock ? 40 : 16,
      color565: type == ObjectType.clock ? 0x07ff : 0xffff,
      width: type == ObjectType.clock
          ? 150
          : type == ObjectType.calendar
          ? 220
          : 80,
      height: type == ObjectType.clock
          ? 40
          : type == ObjectType.calendar
          ? 80
          : 32,
      superContent: '@TEMP',
      x: 30.0 + (_objects.length % 5) * 15,
      y: 20.0 + (_objects.length % 4) * 15,
    );
    setState(() {
      _objects.add(obj);
      _selectedIndex = _objects.length - 1;
    });
  }

  Future<void> _addIconStamp(IconData icon) async {
    if (_objects.length >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ESP32 hỗ trợ tối đa 12 phần tử.')),
      );
      return;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((24 - painter.width) / 2, (24 - painter.height) / 2),
    );
    final image = await recorder.endRecording().toImage(24, 24);
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    painter.dispose();
    if (pixels == null || !mounted) return;
    final hex = ditherRgba(
      pixels.buffer.asUint8List(),
      24,
      24,
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _recordHistory();
    setState(() {
      _objects.add(
        DesignObject(
          id: 'obj_${_idCounter++}',
          type: ObjectType.image,
          x: 20,
          y: 20,
          width: 24,
          height: 24,
          bitmapHex: hex,
        ),
      );
      _selectedIndex = _objects.length - 1;
    });
  }

  void _removeSelectedObject() {
    if (_selectedIndex < 0 || _selectedIndex >= _objects.length) return;
    _recordHistory();
    setState(() {
      if (_objects[_selectedIndex].imageBackground) _backgroundBitmapHex = null;
      _objects.removeAt(_selectedIndex);
      if (_selectedIndex >= _objects.length) {
        _selectedIndex = _objects.length - 1;
      }
    });
  }

  void _clearCanvas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.stitchSurfaceContainer,
        title: Text(
          'Xóa toàn bộ khung vẽ?',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Tất cả các phần tử đang thiết kế sẽ bị xóa. Bạn vẫn có thể dùng nút Hoàn tác (Undo) để khôi phục.',
          style: GoogleFonts.nunito(
            color: AppColors.stitchOnSurfaceVariant,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.stitchOnSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stitchErrorContainer,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _recordHistory();
              setState(() {
                _objects.clear();
                _backgroundBitmapHex = null;
                _selectedIndex = -1;
              });
            },
            child: const Text('Xóa hết', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PERSISTENCE & HARDWARE FLASH
  // --------------------------------------------------------------------------
  Future<void> _saveDesignLocally() async {
    try {
      final hasImageSources = _objects.any(
        (e) => e.type == ObjectType.image && e.imageSource.isNotEmpty,
      );
      if (hasImageSources) {
        try {
          final support = await getApplicationSupportDirectory();
          final originals = Directory('${support.path}/studio_originals');
          await originals.create(recursive: true);
          for (final obj in _objects.where(
            (e) => e.type == ObjectType.image && e.imageSource.isNotEmpty,
          )) {
            final source = File(obj.imageSource);
            if (!await source.exists()) continue;
            final target = File('${originals.path}/${obj.id}.img');
            if (source.path != target.path) {
              await source.copy(target.path);
              obj.imageSource = target.path;
            }
          }
        } catch (_) {
          // File caching fallback for test/unsupported environments
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _objects.map((e) => e.toJson()).toList();
      final success = await prefs.setString(
        'saved_design',
        jsonEncode({
          'background': _background,
          'background_bitmap': _backgroundBitmapHex,
          'elements': jsonList,
        }),
      );

      if (!success) {
        throw Exception('Không thể ghi vào bộ nhớ cục bộ');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D3328),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.stitchTertiary),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.stitchTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đã lưu ${_objects.length} phần tử thiết kế vào bộ nhớ máy!',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF381515),
            content: Text(
              'Lỗi lưu thiết kế: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadDesignLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('saved_design');
      if (data == null || data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy thiết kế nào đã lưu trước đó!'),
            ),
          );
        }
        return;
      }

      final dynamic decoded = jsonDecode(data);
      final elements = decoded is Map ? decoded['elements'] : decoded;
      if (elements is! List) {
        throw const FormatException('Định dạng dữ liệu không hợp lệ');
      }

      _recordHistory();
      setState(() {
        _background = decoded is Map
            ? parseTftColor(decoded['background'], 0)
            : 0;
        _backgroundBitmapHex = decoded is Map
            ? decoded['background_bitmap'] as String?
            : null;
        _objects.clear();
        _objects.addAll(
          elements
              .whereType<Map<String, dynamic>>()
              .map((e) => DesignObject.fromJson(e))
              .toList(),
        );
        _selectedIndex = _objects.isNotEmpty ? 0 : -1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D3328),
            content: Text(
              'Đã nạp thành công ${_objects.length} phần tử từ điện thoại!',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF381515),
            content: Text(
              'Tệp lưu bị lỗi hoặc không tương thích: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _uploadToMarket() async {
    try {
      final payload = {
        'author': 'Studio Designer',
        'thumbnail_url': 'assets/images/market_1.png',
        'design_json': {
          'background': _background,
          if (_backgroundBitmapHex != null)
            'background_bitmap': _backgroundBitmapHex,
          'elements': _objects
              .where((e) => !e.imageBackground)
              .map(_toTftItem)
              .toList(),
        },
        'likes': 0,
        'timestamp': DateTime.now().toIso8601String(),
      };

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tải thiết kế lên Chợ Giao Diện...'),
          duration: Duration(seconds: 1),
        ),
      );

      await ApiClient.instance.post(AppConstants.marketEndpoint, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0D3328),
            content: Text(
              'Tải lên Chợ thành công! Bạn có thể xem trong Thư viện Market.',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF381515),
            content: Text(
              'Không thể tải lên máy chủ: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _flashToEsp32(SppService? spp) async {
    final isConnected = spp?.isConnected ?? false;
    if (!isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E2415),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFFB74D)),
          ),
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chưa kết nối ESP32 qua BLE. Kết nối thiết bị trước khi nạp TFT.',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    try {
      final items = _objects
          .where((e) => !e.imageBackground)
          .map(_toTftItem)
          .toList();
      await spp!.uploadTftLayout(
        items,
        backgroundColor: _background,
        backgroundBitmapHex: _backgroundBitmapHex,
        refreshSeconds: _refreshRate == '1 Giây' ? 1 : 60,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0D3328),
          content: Text('Đã nạp ${items.length} phần tử lên LCD 320×240.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF381515),
          content: Text('Không thể nạp giao diện: $e'),
        ),
      );
    }
  }

  Map<String, dynamic> _toTftItem(DesignObject obj) => normalizeTftItem({
    't': obj.type == ObjectType.image ? 'bitmap' : obj.type.name,
    'v': obj.type == ObjectType.image
        ? obj.bitmapHex
        : obj.type == ObjectType.superText
        ? obj.superContent
        : obj.textContent,
    'g': obj.geoShape,
    'x': obj.x,
    'y': obj.y,
    'w': obj.width,
    'h': obj.height,
    's': obj.autoFit
        ? 20
        : ((obj.type == ObjectType.superText
                      ? obj.superFontSize
                      : obj.textFontSize) /
                  8)
              .round()
              .clamp(1, 20),
    'a': obj.autoFit,
    'c': obj.color565,
    'i': obj.type == ObjectType.image ? obj.imageInvert : obj.textInvert,
    'f': obj.geoFill == 'Tô đặc',
  });

  void _showScreenSizeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.stitchSurfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Màn hình TFT LCD Shield',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResolutionTile(
              320,
              240,
              'ILI9341 • xoay ngang',
              'ESP32 DOIT DevKit V1 • RGB565',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionTile(int w, int h, String title, String subtitle) {
    final isSelected = _canvasWidth == w && _canvasHeight == h;
    return InkWell(
      onTap: () {
        setState(() {
          _canvasWidth = w;
          _canvasHeight = h;
        });
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.stitchSecondaryContainer.withValues(alpha: 0.15)
              : AppColors.stitchSurfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.stitchSecondaryContainer
                : AppColors.stitchOutlineVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.stitchSecondaryContainer,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SppService? spp;
    try {
      spp = Provider.of<SppService>(context);
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.stitchSurface,
      appBar: _buildHeader(),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ambient Status Banner
              _buildAmbientTelemetryBanner(spp),

              // Top Compact Toolbar
              _buildTopToolbar(spp),
              const SizedBox(height: 12),

              // TFT Canvas Workspace
              _buildCanvasWorkspace(),
              const SizedBox(height: 16),

              // Add Elements Dock
              _buildAddElementsDock(),
              const SizedBox(height: 16),

              // Property Inspector Panel
              if (_selected != null) ...[
                _buildPropertyInspector(_selected!),
                const SizedBox(height: 16),
              ],

              // Hardware Memory Bento
              _buildHardwareMemoryBento(),
              const SizedBox(height: 16),

              // Bottom Primary Actions
              _buildBottomPrimaryActions(spp),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: AppColors.stitchSurface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Trình Chỉnh Sửa Mặt Đồng Hồ',
        style: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.folder_open_rounded,
            color: AppColors.stitchSecondaryContainer,
          ),
          tooltip: 'Mở thiết kế đã lưu',
          onPressed: _loadDesignLocally,
        ),
        IconButton(
          icon: const Icon(
            Icons.cloud_upload_outlined,
            color: AppColors.stitchSecondaryContainer,
          ),
          tooltip: 'Tải lên Chợ',
          onPressed: _uploadToMarket,
        ),
        IconButton(
          icon: const Icon(
            Icons.tune_rounded,
            color: AppColors.stitchOnSurfaceVariant,
          ),
          tooltip: 'Chọn độ phân giải',
          onPressed: _showScreenSizeDialog,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildAmbientTelemetryBanner(SppService? spp) {
    final isConnected = spp?.isConnected ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.stitchSecondaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bảng vẽ TFT $_canvasWidth x $_canvasHeight px • RGB565',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isConnected
                  ? AppColors.stitchTertiaryContainer.withValues(alpha: 0.2)
                  : AppColors.stitchSurfaceHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected
                    ? AppColors.stitchTertiary.withValues(alpha: 0.4)
                    : AppColors.stitchOutlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.memory_rounded,
                  size: 13,
                  color: isConnected
                      ? AppColors.stitchTertiary
                      : AppColors.stitchOutline,
                ),
                const SizedBox(width: 5),
                Text(
                  isConnected ? 'ESP32 DOIT sẵn sàng' : 'ESP32 Offline',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isConnected
                        ? AppColors.stitchTertiary
                        : AppColors.stitchOutline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar(SppService? spp) {
    final canUndo = _undoStack.isNotEmpty;
    final canRedo = _redoStack.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.stitchSurfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.stitchOutlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo_rounded, size: 20),
                    color: canUndo ? Colors.white : AppColors.stitchOutline,
                    onPressed: canUndo ? _undo : null,
                    tooltip: 'Hoàn tác (Undo)',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo_rounded, size: 20),
                    color: canRedo ? Colors.white : AppColors.stitchOutline,
                    onPressed: canRedo ? _redo : null,
                    tooltip: 'Làm lại (Redo)',
                  ),
                  IconButton(
                    icon: const Icon(Icons.grid_4x4_rounded, size: 20),
                    color: _showGrid
                        ? AppColors.stitchSecondaryContainer
                        : AppColors.stitchOutline,
                    onPressed: () => setState(() => _showGrid = !_showGrid),
                    tooltip: 'Lưới Pixel',
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _isZoomed200 = !_isZoomed200),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: AppColors.stitchSurfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isZoomed200 ? '200%' : '100%',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.delete_sweep_rounded,
                      color: AppColors.stitchError,
                      size: 20,
                    ),
                    onPressed: _clearCanvas,
                    tooltip: 'Xóa khung',
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _flashToEsp32(spp),
                    icon: const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: Colors.black,
                    ),
                    label: Text(
                      'Nạp ESP32',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stitchSecondaryContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasWorkspace() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.stitchSurfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.stitchOutlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.watch_rounded,
                        color: AppColors.stitchPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'XEM TRƯỚC TFT ILI9341',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.stitchOnSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Cập nhật màu',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Landscape ILI9341 preview.
            Wrap(
              spacing: 8,
              children: [
                for (final entry in <String, int>{
                  'Trắng': 0xffff,
                  'Đen': 0x0000,
                  'Cyber Dark': 0x0010,
                  'Slate': 0x2104,
                }.entries)
                  ChoiceChip(
                    label: Text(entry.key),
                    selected: _background == entry.value,
                    avatar: CircleAvatar(
                      backgroundColor: rgb565Color(entry.value),
                    ),
                    onSelected: (_) =>
                        setState(() => _background = entry.value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Padding(
                padding: EdgeInsets.all(_isZoomed200 ? 0 : 20),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Container(
                    width: 320,
                    height: 240,
                    decoration: BoxDecoration(
                      color: rgb565Color(_background),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        if (_backgroundBitmapHex != null)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: TftPreviewPainter(
                                const [],
                                background: _background,
                                backgroundBitmap: _backgroundBitmapHex,
                              ),
                            ),
                          ),
                        // Pixel dot grid background
                        if (_showGrid)
                          Positioned.fill(
                            child: CustomPaint(painter: _DotGridPainter()),
                          ),

                        // Screen stamp
                        Positioned(
                          top: 2,
                          right: 4,
                          child: Text(
                            '${_canvasWidth}x$_canvasHeight RGB565',
                            style: GoogleFonts.robotoMono(
                              fontSize: 7,
                              color: Colors.black26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Render Objects
                        ..._objects
                            .asMap()
                            .entries
                            .where((entry) => !entry.value.imageBackground)
                            .map((entry) {
                              final index = entry.key;
                              final obj = entry.value;
                              final isSelected = index == _selectedIndex;

                              return Positioned(
                                left: obj.x,
                                top: obj.y,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedIndex = index),
                                  onPanStart: (_) => _recordHistory(),
                                  onPanUpdate: (details) {
                                    setState(() {
                                      obj.x = (obj.x + details.delta.dx)
                                          .clamp(0, max(0, 320 - obj.width))
                                          .toDouble();
                                      obj.y = (obj.y + details.delta.dy)
                                          .clamp(0, max(0, 240 - obj.height))
                                          .toDouble();
                                    });
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Element Render
                                      _buildElementRender(obj),

                                      // Cyan Bounding Box & Corner Handles when selected
                                      if (isSelected) ...[
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppColors
                                                    .stitchSecondaryContainer,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 4 corner dots
                                        const Positioned(
                                          top: -3,
                                          left: -3,
                                          child: _HandleDot(),
                                        ),
                                        const Positioned(
                                          top: -3,
                                          right: -3,
                                          child: _HandleDot(),
                                        ),
                                        const Positioned(
                                          bottom: -3,
                                          left: -3,
                                          child: _HandleDot(),
                                        ),
                                        const Positioned(
                                          bottom: -3,
                                          right: -3,
                                          child: _HandleDot(),
                                        ),
                                        // Coordinate tooltip
                                        Positioned(
                                          top: -16,
                                          left: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'X:${obj.x.toInt()} Y:${obj.y.toInt()}',
                                              style: GoogleFonts.robotoMono(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors
                                                    .stitchSecondaryContainer,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Calibration / status bar below canvas
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.stitchTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Bộ màu: RGB565',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: AppColors.stitchOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '•',
                    style: GoogleFonts.nunito(color: AppColors.stitchOutline),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_objects.length} phần tử trên bản vẽ',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.stitchSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElementRender(DesignObject obj) {
    try {
      final item = {..._toTftItem(obj), 'x': 0, 'y': 0};
      if (obj.type == ObjectType.calendar) {
        final now = DateTime.now();
        final day = [
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun',
        ][now.weekday - 1];
        item['schedulePreview'] = tftTodayScheduleText(
          now,
          _schedulePreview[day] ?? const [],
        );
      }
      if (obj.type == ObjectType.superText) {
        item['temperaturePreview'] = context
            .read<SppService>()
            .lastSession
            ?.temperature;
      }
      return SizedBox(
        width: obj.width,
        height: obj.height,
        child: CustomPaint(painter: _StudioItemPainter(item, _background)),
      );
    } catch (_) {
      return SizedBox(
        width: obj.width,
        height: obj.height,
        child: const Center(
          child: Icon(Icons.warning_amber, color: Colors.orange),
        ),
      );
    }
  }

  Widget _buildAddElementsDock() {
    final dockItems = [
      (
        ObjectType.clock,
        Icons.schedule_rounded,
        'Đồng hồ',
        AppColors.stitchPrimary,
      ),
      (
        ObjectType.text,
        Icons.title_rounded,
        'Văn bản',
        AppColors.stitchSecondary,
      ),
      (
        ObjectType.geometry,
        Icons.category_rounded,
        'Hình học',
        AppColors.stitchTertiary,
      ),
      (
        ObjectType.image,
        Icons.image_rounded,
        'Ảnh Bitmap',
        const Color(0xFFFFD54F),
      ),
      (
        ObjectType.calendar,
        Icons.calendar_today_rounded,
        'Lịch biểu',
        const Color(0xFF64B5F6),
      ),
      (
        ObjectType.superText,
        Icons.monitor_heart_rounded,
        'Cảm biến',
        const Color(0xFFFF8A65),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'THÊM PHẦN TỬ NHANH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Chạm để chèn',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.stitchPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 82,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: dockItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final (type, icon, label, color) = dockItems[i];
              return InkWell(
                onTap: () => _addObject(type),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 76,
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.stitchOutlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 45,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              for (final (name, icon) in <(String, IconData)>[
                ('Tim', Icons.favorite),
                ('Sao', Icons.star),
                ('Mặt trời', Icons.wb_sunny),
                ('Mây', Icons.cloud),
                ('Pin', Icons.battery_full),
                ('Chuông', Icons.notifications),
                ('Sét', Icons.bolt),
                ('Lửa', Icons.local_fire_department),
                ('Cà phê', Icons.coffee),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(name),
                    onPressed: () => _addIconStamp(icon),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyInspector(DesignObject obj) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.stitchSurfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.stitchOutlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final entry in tftPalette.entries)
                  ChoiceChip(
                    label: Text(entry.key),
                    selected: obj.color565 == entry.value,
                    avatar: CircleAvatar(
                      backgroundColor: rgb565Color(entry.value),
                    ),
                    onSelected: (_) {
                      _recordHistory();
                      setState(() => obj.color565 = entry.value);
                    },
                  ),
              ],
            ),
            if (obj.type == ObjectType.geometry) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final shape in [
                    'Hình chữ nhật',
                    'Khung bo góc',
                    'Hình tròn',
                    'Hình elip',
                    'Hình thoi',
                    'Ngôi sao',
                    'Dấu cộng',
                    'Đường thẳng',
                    'Hình tam giác',
                    'Khung lập phương 3D',
                  ])
                    ChoiceChip(
                      label: Text(shape),
                      selected: obj.geoShape == shape,
                      onSelected: (_) {
                        _recordHistory();
                        setState(() => obj.geoShape = shape);
                      },
                    ),
                ],
              ),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tô đặc hình'),
                  value: obj.geoFill == 'Tô đặc',
                  onChanged: (value) {
                    _recordHistory();
                    setState(() => obj.geoFill = value ? 'Tô đặc' : 'Không có');
                  },
                ),
              ),
            ],
            if (obj.type == ObjectType.clock ||
                obj.type == ObjectType.text ||
                obj.type == ObjectType.calendar ||
                obj.type == ObjectType.superText) ...[
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tự vừa chữ theo W/H'),
                  subtitle: const Text(
                    'Kéo rộng và cao vùng để chữ tự lớn hơn',
                  ),
                  value: obj.autoFit,
                  onChanged: (value) {
                    _recordHistory();
                    setState(() => obj.autoFit = value);
                  },
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cỡ chữ cố định (1–20): ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildCoordinateBox(
                    'S',
                    ((obj.type == ObjectType.superText
                                ? obj.superFontSize
                                : obj.textFontSize) /
                            8)
                        .round()
                        .clamp(1, 20)
                        .toString(),
                    (value) {
                      final size = int.tryParse(value);
                      if (size == null) return;
                      _recordHistory();
                      setState(() {
                        obj.autoFit = false;
                        obj.textFontSize = size.clamp(1, 20) * 8;
                        obj.superFontSize = obj.textFontSize.toDouble();
                      });
                    },
                  ),
                ],
              ),
            ],
            if (obj.type == ObjectType.calendar)
              const Text('Hiển thị các task đã đồng bộ của đúng thứ hôm nay.'),
            if (obj.type == ObjectType.superText)
              const Text(
                'Hiển thị nhiệt độ chip RTC DS3231; không phải nhiệt độ phòng.',
              ),
            if (obj.type == ObjectType.image)
              const Text(
                'Ảnh dither 1-bit MSB-first trên TFT màu; tối đa 320×240. Ảnh gốc được lưu trong bộ nhớ ứng dụng để đổi kích thước.',
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.stitchSecondaryContainer.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.stitchSecondaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thuộc tính phần tử',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              obj.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: AppColors.stitchSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.stitchError,
                    size: 20,
                  ),
                  onPressed: _removeSelectedObject,
                  tooltip: 'Xóa phần tử',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Invert Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.invert_colors_rounded,
                          color: AppColors.stitchOnSurfaceVariant,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đảo Ngược Màu (Invert)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Chữ đen nền trắng ⮂ Chữ trắng nền đen',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  color: AppColors.stitchOnSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: obj.textInvert,
                    onChanged: (v) {
                      _recordHistory();
                      setState(() => obj.textInvert = v);
                    },
                    activeThumbColor: AppColors.stitchPrimaryContainer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Dynamic fields based on type
            if (obj.type == ObjectType.text) ...[
              Text(
                'Nội dung văn bản:',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.stitchOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: ValueKey('text-${obj.id}'),
                initialValue: obj.textContent,
                onChanged: (v) {
                  if (v == obj.textContent) return;
                  _recordHistory();
                  setState(() => obj.textContent = v);
                },
                style: GoogleFonts.nunito(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.stitchSurfaceLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (obj.type == ObjectType.image) ...[
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đặt làm ảnh nền 320×240'),
                  subtitle: const Text(
                    'Ảnh dither 1-bit nằm sau đồng hồ và các phần tử khác',
                  ),
                  value: obj.imageBackground,
                  onChanged: (enabled) => _toggleBackgroundImage(obj, enabled),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (file != null) {
                    try {
                      final size = fitBitmapSize(
                        obj.width.round(),
                        obj.height.round(),
                      );
                      final hex = await processImageTo1BitHex(
                        await file.readAsBytes(),
                        size.width.toInt(),
                        size.height.toInt(),
                      );
                      final support = await getApplicationSupportDirectory();
                      final originals = Directory(
                        '${support.path}/studio_originals',
                      );
                      await originals.create(recursive: true);
                      final original = File('${originals.path}/${obj.id}.img');
                      await original.writeAsBytes(
                        await file.readAsBytes(),
                        flush: true,
                      );
                      if (!mounted) return;
                      _recordHistory();
                      setState(() {
                        _bitmapResizeVersions[obj.id] =
                            (_bitmapResizeVersions[obj.id] ?? 0) + 1;
                        _requestedBitmapSizes.remove(obj.id);
                        obj.imageSource = original.path;
                        obj.bitmapHex = hex;
                        obj.width = size.width;
                        obj.height = size.height;
                        if (obj.imageBackground) {
                          obj.imageBackground = false;
                          _backgroundBitmapHex = null;
                        }
                      });
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Không thể đọc ảnh: $e')),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: const Text('Chọn ảnh từ thiết bị'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stitchSurfaceHigh,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: obj.imageSource.isEmpty
                    ? null
                    : () => _toggleBackgroundImage(obj, true),
                icon: const Icon(Icons.fullscreen_rounded),
                label: const Text('Phủ toàn màn hình 320×240'),
              ),
              const SizedBox(height: 8),
            ],

            // Coordinates & Dimensions Row
            Text(
              'Tọa độ & Kích thước Pixel:',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: AppColors.stitchOnSurfaceVariant,
              ),
            ),
            const Text(
              'X/Y: vị trí. W/H: chiều rộng, cao của phần tử; bật Tự vừa chữ để nội dung đổi cỡ theo vùng.',
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCoordinateBox('X', obj.x.toInt().toString(), (v) {
                  final next = int.tryParse(v);
                  if (next == null) return;
                  _recordHistory();
                  setState(
                    () => obj.x = next
                        .clamp(0, max(0, 320 - obj.width))
                        .toDouble(),
                  );
                }),
                _buildCoordinateBox('Y', obj.y.toInt().toString(), (v) {
                  final next = int.tryParse(v);
                  if (next == null) return;
                  _recordHistory();
                  setState(
                    () => obj.y = next
                        .clamp(0, max(0, 240 - obj.height))
                        .toDouble(),
                  );
                }),
                _buildCoordinateBox('W', obj.width.toInt().toString(), (v) {
                  final next = int.tryParse(v);
                  if (next == null || next < 1) return;
                  if (obj.type == ObjectType.image) {
                    _resizeBitmap(
                      obj,
                      next,
                      (_requestedBitmapSizes[obj.id]?.height ?? obj.height)
                          .round(),
                    );
                    return;
                  }
                  _recordHistory();
                  setState(() {
                    obj.width = next.clamp(1, 320).toDouble();
                    if (obj.type == ObjectType.geometry &&
                        obj.geoShape == 'Hình tròn') {
                      obj.width = next.clamp(1, 240).toDouble();
                      obj.height = obj.width;
                      obj.y = obj.y.clamp(0, 240 - obj.height).toDouble();
                    }
                    obj.x = obj.x.clamp(0, 320 - obj.width).toDouble();
                  });
                }),
                _buildCoordinateBox('H', obj.height.toInt().toString(), (v) {
                  final next = int.tryParse(v);
                  if (next == null || next < 1) return;
                  if (obj.type == ObjectType.image) {
                    _resizeBitmap(
                      obj,
                      (_requestedBitmapSizes[obj.id]?.width ?? obj.width)
                          .round(),
                      next,
                    );
                    return;
                  }
                  _recordHistory();
                  setState(() {
                    obj.height = next.clamp(1, 240).toDouble();
                    if (obj.type == ObjectType.geometry &&
                        obj.geoShape == 'Hình tròn') {
                      obj.width = obj.height;
                      obj.x = obj.x.clamp(0, 320 - obj.width).toDouble();
                    }
                    obj.y = obj.y.clamp(0, 240 - obj.height).toDouble();
                  });
                }),
              ],
            ),
            const SizedBox(height: 14),

            // Refresh Rate selector
            Text(
              'Chu kỳ làm mới màn hình:',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: AppColors.stitchOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildRefreshRateBtn('1 Giây'),
                const SizedBox(width: 8),
                _buildRefreshRateBtn('60 Giây'),
                const SizedBox(width: 8),
                _buildRefreshRateBtn('Theo Phút'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinateBox(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return SizedBox(
      width: 68,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.stitchSurfaceLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.stitchOutlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          onTap: () async {
            var editedValue = value;
            final result = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Chỉnh $label'),
                content: TextFormField(
                  initialValue: value,
                  onChanged: (text) => editedValue = text,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: '$label (pixel)'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Hủy'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, editedValue),
                    child: const Text('Lưu'),
                  ),
                ],
              ),
            );
            if (mounted && result != null) onChanged(result);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.stitchOutline,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshRateBtn(String label) {
    final isSelected = _refreshRate == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _refreshRate = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.stitchPrimaryContainer
                : AppColors.stitchSurfaceLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : AppColors.stitchOnSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHardwareMemoryBento() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.stitchSurfaceLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.stitchOutlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.memory_rounded,
                color: AppColors.stitchSecondaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Bộ nhớ bố cục TFT:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.stitchTertiaryContainer.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TỐI ƯU',
                          style: GoogleFonts.nunito(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.stitchTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_objects.length / 12).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: AppColors.stitchSurfaceHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.stitchSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đang dùng ${_objects.length}/12 phần tử bố cục',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: AppColors.stitchOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${12 - min(_objects.length, 12)}',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Vị trí còn lại',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPrimaryActions(SppService? spp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _flashToEsp32(spp),
                  icon: const Icon(Icons.devices_rounded, size: 18),
                  label: const Text('Xem trên Đồng hồ thật'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.stitchSecondary,
                    side: const BorderSide(
                      color: AppColors.stitchSecondaryContainer,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveDesignLocally,
                  icon: const Icon(
                    Icons.save_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text('Lưu vào Thư viện'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.stitchPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'TỰ ĐỘNG ĐỒNG BỘ HÓA QUA BLE ESP32 GATT SERVICE',
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: AppColors.stitchOutline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPER PAINTERS & WIDGETS
// ============================================================================

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD3D3CF)
      ..style = PaintingStyle.fill;

    const double step = 6.0;
    for (double x = 4; x < size.width; x += step) {
      for (double y = 4; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HandleDot extends StatelessWidget {
  const _HandleDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.stitchSecondaryContainer,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _StudioItemPainter extends CustomPainter {
  final Map<String, dynamic> item;
  final int background;
  _StudioItemPainter(this.item, this.background);
  @override
  void paint(Canvas canvas, Size size) =>
      paintTftItem(canvas, item, DateTime.now(), background);
  @override
  bool shouldRepaint(covariant _StudioItemPainter oldDelegate) => true;
}
