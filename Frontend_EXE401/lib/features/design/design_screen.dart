import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';

// =====================
// Data Models
// =====================
enum ObjectType { clock, text, geometry, image, calendar, superText }

class DesignObject {
  final String id;
  ObjectType type;
  double x;
  double y;
  // Clock props
  String clockFont;
  // Text props
  String textContent;
  int textFontSize;
  bool textInvert;
  // Geometry props
  String geoShape;
  String geoFill;
  double geoSize;
  double geoThickness;
  // Image props
  String imageSource;
  bool imageInvert;
  // Calendar props
  String calFont;
  // SuperText props
  String superContent;
  String superFont;
  double superFontSize;
  double superPadding;
  int superColorIndex; // 0=white,1=black,2=red

  DesignObject({
    required this.id,
    required this.type,
    this.x = 10,
    this.y = 10,
    this.clockFont = 'YaHei_58',
    this.textContent = '@T @d/@M/@y',
    this.textFontSize = 12,
    this.textInvert = false,
    this.geoShape = 'Hình tròn',
    this.geoFill = 'Không có',
    this.geoSize = 40,
    this.geoThickness = 1,
    this.imageSource = '',
    this.imageInvert = false,
    this.calFont = 'Font5x7',
    this.superContent = '@h:@m',
    this.superFont = 'Roboto',
    this.superFontSize = 41,
    this.superPadding = 0,
    this.superColorIndex = 1,
  });

  String get label {
    switch (type) {
      case ObjectType.clock: return 'Đồng hồ';
      case ObjectType.text: return 'Văn bản';
      case ObjectType.geometry: return 'Hình học';
      case ObjectType.image: return 'Hình ảnh';
      case ObjectType.calendar: return 'Lịch';
      case ObjectType.superText: return 'Siêu văn bản';
    }
  }

  IconData get icon {
    switch (type) {
      case ObjectType.clock: return Icons.access_time_rounded;
      case ObjectType.text: return Icons.text_fields_rounded;
      case ObjectType.geometry: return Icons.category_rounded;
      case ObjectType.image: return Icons.image_rounded;
      case ObjectType.calendar: return Icons.calendar_month_rounded;
      case ObjectType.superText: return Icons.auto_awesome_rounded;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'x': x,
    'y': y,
    'clockFont': clockFont,
    'textContent': textContent,
    'textFontSize': textFontSize,
    'textInvert': textInvert,
    'geoShape': geoShape,
    'geoFill': geoFill,
    'geoSize': geoSize,
    'geoThickness': geoThickness,
    'imageSource': imageSource,
    'imageInvert': imageInvert,
    'calFont': calFont,
    'superContent': superContent,
    'superFont': superFont,
    'superFontSize': superFontSize,
    'superPadding': superPadding,
    'superColorIndex': superColorIndex,
  };

  factory DesignObject.fromJson(Map<String, dynamic> json) {
    return DesignObject(
      id: json['id'],
      type: ObjectType.values.firstWhere((e) => e.name == json['type'], orElse: () => ObjectType.text),
      x: json['x'] ?? 10.0,
      y: json['y'] ?? 10.0,
    )
      ..clockFont = json['clockFont'] ?? 'YaHei_58'
      ..textContent = json['textContent'] ?? '@T @d/@M/@y'
      ..textFontSize = json['textFontSize'] ?? 12
      ..textInvert = json['textInvert'] ?? false
      ..geoShape = json['geoShape'] ?? 'Hình tròn'
      ..geoFill = json['geoFill'] ?? 'Không có'
      ..geoSize = json['geoSize'] ?? 40.0
      ..geoThickness = json['geoThickness'] ?? 1.0
      ..imageSource = json['imageSource'] ?? ''
      ..imageInvert = json['imageInvert'] ?? false
      ..calFont = json['calFont'] ?? 'Font5x7'
      ..superContent = json['superContent'] ?? '@h:@m'
      ..superFont = json['superFont'] ?? 'Roboto'
      ..superFontSize = json['superFontSize'] ?? 41.0
      ..superPadding = json['superPadding'] ?? 0.0
      ..superColorIndex = json['superColorIndex'] ?? 1;
  }
}

// =====================
// Main Screen
// =====================
class DesignScreen extends StatefulWidget {
  const DesignScreen({super.key});

  @override
  State<DesignScreen> createState() => _DesignScreenState();
}

class _DesignScreenState extends State<DesignScreen> {
  final List<DesignObject> _objects = [];
  int _selectedIndex = -1;
  int _idCounter = 0;
  bool _highlightWorkObject = true;
  bool _initializedFromArgs = false;
  bool _isVertical = false;

  Future<void> _saveDesign() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _objects.map((e) => e.toJson()).toList();
    await prefs.setString('saved_design', jsonEncode(jsonList));
    if (mounted) {
      showSuccessSnackbar(context, 'Đã lưu cục bộ thành công!');
    }
  }

  Future<void> _uploadToMarket() async {
    final jsonList = _objects.map((e) => e.toJson()).toList();
    String baseUrl = "http://127.0.0.1:8000";
    if (!kIsWeb && Platform.isAndroid) baseUrl = "http://10.0.2.2:8000";

    try {
      showSuccessSnackbar(context, 'Đang tải lên Chợ hiệu ứng...');
      final response = await http.post(
        Uri.parse('$baseUrl/api/market/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "author": "Tôi (Tự tạo)",
          "thumbnail_url": "assets/images/market_1.png",
          "design_json": {"elements": jsonList},
          "likes": 0,
          "timestamp": DateTime.now().toIso8601String()
        }),
      );
      if (response.statusCode == 200 && mounted) {
        showSuccessSnackbar(context, 'Tải lên Chợ thành công! Hãy vào Chợ để xem.');
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Lỗi tải lên: $e');
    }
  }

  Future<void> _loadDesign() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('saved_design');
    if (data != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(data);
        setState(() {
          _objects.clear();
          _objects.addAll(jsonList.map((e) => DesignObject.fromJson(e)).toList());
          _selectedIndex = _objects.isNotEmpty ? 0 : -1;
        });
        if (mounted) {
          showSuccessSnackbar(context, 'Đã nạp thiết kế từ điện thoại!');
        }
      } catch (e) {
        if (mounted) {
          showSuccessSnackbar(context, 'Lỗi nạp thiết kế: $e');
        }
      }
    } else {
      if (mounted) {
        showSuccessSnackbar(context, 'Không tìm thấy thiết kế nào đã lưu!');
      }
    }
  }

  void _showScreenSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF673AB7), Color(0xFFFF8A65)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gamepad_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('Chọn loại màn E-ink', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SizeOption(title: 'Màn 2.13 inch', subtitle: 'Độ phân giải 212 x 104', sizeLabel: '212x104', color: Color(0xFF2962FF)),
                const SizedBox(height: 12),
                const _SizeOption(title: 'Màn 2.13 inch', subtitle: 'Độ phân giải 250 x 122', sizeLabel: '250x122', color: Color(0xFFFF6D00)),
                const SizedBox(height: 12),
                const _SizeOption(title: 'Màn 4.2 inch', subtitle: 'Độ phân giải 400 x 300', sizeLabel: '400x300', color: Color(0xFF00BFA5)),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Đóng', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF311B92))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromArgs) {
      _initializedFromArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      if (args != null && args['preview'] != null) {
        // Run after the build cycle to avoid setState during build if needed, 
        // but since we are in didChangeDependencies we can just update state directly before build.
        _objects.add(DesignObject(
          id: 'obj_${_idCounter++}',
          type: ObjectType.superText,
          superContent: args['preview'],
          superFontSize: 50,
          x: 40,
          y: 25,
        ));
        _selectedIndex = 0;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã mở thiết kế', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFF29B6F6), // Blue like AppColors.cardBlue
              behavior: SnackBarBehavior.fixed,
              duration: const Duration(seconds: 3),
            ),
          );
        });
      }
    }
  }

  DesignObject? get _selected =>
      _selectedIndex >= 0 && _selectedIndex < _objects.length
          ? _objects[_selectedIndex]
          : null;

  void _addObject(ObjectType type) {
    final obj = DesignObject(
      id: 'obj_${_idCounter++}',
      type: type,
      x: 10.0 + (_objects.length * 5.0),
      y: 10.0 + (_objects.length * 5.0),
    );
    setState(() {
      _objects.add(obj);
      _selectedIndex = _objects.length - 1;
    });
  }

  void _removeObject(int index) {
    setState(() {
      _objects.removeAt(index);
      if (_selectedIndex >= _objects.length) {
        _selectedIndex = _objects.length - 1;
      }
    });
  }

  void _moveSelected(double dx, double dy) {
    if (_selected == null) return;
    setState(() {
      _selected!.x = max(0, _selected!.x + dx);
      _selected!.y = max(0, _selected!.y + dy);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Thiết kế 212x104',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_rounded),
            tooltip: 'Đăng lên Chợ hiệu ứng',
            onPressed: _uploadToMarket,
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Lưu cục bộ',
            onPressed: _saveDesign,
          ),
        ],
      ),
      body: Column(
        children: [
          // === Canvas Area ===
          _CanvasPreview(
            objects: _objects,
            selectedIndex: _selectedIndex,
            highlight: _highlightWorkObject,
            isVertical: _isVertical,
            onSelectObject: (i) => setState(() => _selectedIndex = i),
          ),

          const SizedBox(height: 10),

          // === Object Strip + Gear + Plus ===
          _ObjectStrip(
            objects: _objects,
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
            onRemove: _removeObject,
            onAddTap: () => _showAddObjectSheet(context),
            onSettingsTap: () => setState(() => _selectedIndex = -1),
          ),

          const Divider(height: 1),

          // === Properties Panel ===
          Expanded(
            child: _selectedIndex == -1
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _FileOperationsPanel(
                      highlightWorkObject: _highlightWorkObject,
                      onHighlightChanged: (v) => setState(() => _highlightWorkObject = v),
                      isVertical: _isVertical,
                      onRotate: () => setState(() => _isVertical = !_isVertical),
                      onSave: _saveDesign,
                      onLoad: _loadDesign,
                      onResize: _showScreenSizeDialog,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PropertiesPanel(
                          object: _selected!,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        // D-pad
                        _DPad(
                          objectIcon: _selected!.icon,
                          onUp: () => _moveSelected(0, -5),
                          onDown: () => _moveSelected(0, 5),
                          onLeft: () => _moveSelected(-5, 0),
                          onRight: () => _moveSelected(5, 0),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }



  void _showAddObjectSheet(BuildContext context) {
    final types = [
      (ObjectType.clock, Icons.access_time_rounded, 'Đồng hồ'),
      (ObjectType.text, Icons.text_fields_rounded, 'Văn bản'),
      (ObjectType.geometry, Icons.category_rounded, 'Hình học'),
      (ObjectType.image, Icons.image_rounded, 'Hình ảnh'),
      (ObjectType.calendar, Icons.calendar_month_rounded, 'Lịch'),
      (ObjectType.superText, Icons.auto_awesome_rounded, 'Siêu văn bản'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF9EE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD54F), width: 2),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Thêm đối tượng',
                        style: GoogleFonts.nunito(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  ...types.asMap().entries.map((entry) {
                    final i = entry.key;
                    final (type, icon, label) = entry.value;
                    return Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(context);
                            _addObject(type);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF80D8FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(icon, size: 22,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(label,
                                      style: GoogleFonts.nunito(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                ),
                                const Icon(Icons.add,
                                    size: 22, color: Colors.black45),
                              ],
                            ),
                          ),
                        ),
                        if (i < types.length - 1)
                          const Divider(height: 1, indent: 56, endIndent: 14),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================
// Canvas Preview
// =====================
class _CanvasPreview extends StatelessWidget {
  final List<DesignObject> objects;
  final int selectedIndex;
  final bool highlight;
  final bool isVertical;
  final ValueChanged<int> onSelectObject;

  const _CanvasPreview({
    required this.objects,
    required this.selectedIndex,
    required this.highlight,
    required this.isVertical,
    required this.onSelectObject,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final dayStr = days[now.weekday - 1];
    final dateStr = '$dayStr ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final double W = MediaQuery.of(context).size.width - 32 - 4; // approx inner width
    final double H = 156.0; // approx inner height

    Widget content = Stack(
      children: [
        if (objects.isEmpty)
          Center(
            child: Text(
              isVertical ? 'Canvas trống\n104 x 212 px' : 'Canvas trống\n212 x 104 px',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.black26),
            ),
          ),
        ...objects.asMap().entries.map((entry) {
          final i = entry.key;
          final obj = entry.value;
          final isSelected = highlight && i == selectedIndex;
          
          final left = isVertical ? (obj.x / 104) * H : (obj.x / 212) * W;
          final top = isVertical ? (obj.y / 212) * W : (obj.y / 104) * H;

          return Positioned(
            left: left,
            top: top,
            child: GestureDetector(
              onTap: () => onSelectObject(i),
              child: Container(
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(color: const Color(0xFF00BCD4), width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: _ObjectPreview(obj: obj, dateStr: dateStr, hm: hm),
              ),
            ),
          );
        }),
      ],
    );

    if (isVertical) {
      content = RotatedBox(
        quarterTurns: 3,
        child: SizedBox(
          width: H,
          height: W,
          child: content,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black87, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }
}

class _ObjectPreview extends StatelessWidget {
  final DesignObject obj;
  final String dateStr;
  final String hm;

  const _ObjectPreview(
      {required this.obj, required this.dateStr, required this.hm});

  @override
  Widget build(BuildContext context) {
    switch (obj.type) {
      case ObjectType.clock:
        return Text(
          hm,
          style: GoogleFonts.sourceCodePro(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF00BCD4),
          ),
        );
      case ObjectType.text:
        return Text(
          obj.textContent
              .replaceAll('@T', hm)
              .replaceAll('@d', DateTime.now().day.toString())
              .replaceAll('@M', DateTime.now().month.toString())
              .replaceAll('@y', DateTime.now().year.toString()),
          style: GoogleFonts.sourceCodePro(
            fontSize: obj.textFontSize.toDouble(),
            fontWeight: FontWeight.w700,
            color: obj.textInvert ? Colors.white : Colors.black87,
            backgroundColor:
                obj.textInvert ? Colors.black87 : Colors.transparent,
          ),
        );
      case ObjectType.geometry:
        return CustomPaint(
          size: Size(obj.geoSize, obj.geoSize),
          painter: _GeoPainter(
              shape: obj.geoShape,
              size: obj.geoSize,
              thickness: obj.geoThickness,
              filled: obj.geoFill != 'Không có'),
        );
      case ObjectType.image:
        return Container(
          width: 60,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54),
            color: Colors.black12,
          ),
          child: const Icon(Icons.image_outlined, size: 24, color: Colors.black38),
        );
      case ObjectType.calendar:
        return _MiniCalendar();
      case ObjectType.superText:
        final superColors = [Colors.white, Colors.black, Colors.red];
        return Text(
          obj.superContent
              .replaceAll('@h', DateTime.now().hour.toString().padLeft(2, '0'))
              .replaceAll('@m', DateTime.now().minute.toString().padLeft(2, '0'))
              .replaceAll('@d', DateTime.now().day.toString())
              .replaceAll('@M', DateTime.now().month.toString())
              .replaceAll('@y', DateTime.now().year.toString()),
          style: GoogleFonts.roboto(
            fontSize: obj.superFontSize * 0.5,
            fontWeight: FontWeight.w900,
            color: superColors[obj.superColorIndex],
            backgroundColor: obj.superColorIndex == 0 ? Colors.black : Colors.transparent,
          ),
        );
    }
  }
}

class _GeoPainter extends CustomPainter {
  final String shape;
  final double size;
  final double thickness;
  final bool filled;

  _GeoPainter(
      {required this.shape,
      required this.size,
      required this.thickness,
      required this.filled});

  @override
  void paint(Canvas canvas, Size sz) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = thickness
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke;
    if (shape == 'Hình tròn') {
      canvas.drawCircle(Offset(sz.width / 2, sz.height / 2),
          sz.width / 2 - thickness, paint);
    } else {
      canvas.drawRect(
          Rect.fromLTWH(thickness, thickness, sz.width - thickness * 2,
              sz.height - thickness * 2),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MiniCalendar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstDay = DateTime(now.year, now.month, 1).weekday;

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: ['T2','T3','T4','T5','T6','T7','CN']
                .map((d) => SizedBox(
                      width: 16,
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 6,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00BCD4))),
                    ))
                .toList(),
          ),
          ...List.generate((daysInMonth + firstDay - 1) ~/ 7 + 1, (week) {
            return Row(
              children: List.generate(7, (dow) {
                final day = week * 7 + dow - firstDay + 2;
                final isToday = day == now.day;
                if (day < 1 || day > daysInMonth) return const SizedBox(width: 16);
                return SizedBox(
                  width: 16,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 6,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.normal,
                      color: isToday ? const Color(0xFF00BCD4) : Colors.black87,
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}

// =====================
// Object Strip
// =====================
class _ObjectStrip extends StatelessWidget {
  final List<DesignObject> objects;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;
  final VoidCallback onAddTap;
  final VoidCallback onSettingsTap;

  const _ObjectStrip({
    required this.objects,
    required this.selectedIndex,
    required this.onSelect,
    required this.onRemove,
    required this.onAddTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppColors.cardYellow.withValues(alpha: 0.5),
      child: Row(
        children: [
          // Gear
          GestureDetector(
            onTap: onSettingsTap,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: selectedIndex == -1 ? const Color(0xFFFFCC80) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings_rounded, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          // Scrollable objects
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: objects.asMap().entries.map((entry) {
                  final i = entry.key;
                  final obj = entry.value;
                  final isSelected = i == selectedIndex;
                  return GestureDetector(
                    onTap: () => onSelect(i),
                    child: Container(
                      width: 64, height: 64,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFB3E5FC)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF00BCD4), width: 2)
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(obj.icon, size: 24),
                                const SizedBox(height: 2),
                                Text(
                                  '${obj.label.substring(0, min(obj.label.length, 7))}...',
                                  style: GoogleFonts.nunito(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          // Delete button
                          Positioned(
                            top: 2, right: 2,
                            child: GestureDetector(
                              onTap: () => onRemove(i),
                              child: Container(
                                width: 18, height: 18,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Plus button
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: AppColors.btnGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================
// Properties Panel
// =====================
class _PropertiesPanel extends StatefulWidget {
  final DesignObject object;
  final VoidCallback onChanged;

  const _PropertiesPanel(
      {required this.object, required this.onChanged});

  @override
  State<_PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<_PropertiesPanel> {
  late final TextEditingController _textCtrl;
  late final TextEditingController _superTextCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.object.textContent);
    _superTextCtrl = TextEditingController(text: widget.object.superContent);
  }

  @override
  void didUpdateWidget(covariant _PropertiesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object.id != widget.object.id) {
      _textCtrl.text = widget.object.textContent;
      _superTextCtrl.text = widget.object.superContent;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t,
          style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w800),
        ),
      );

  Widget _dropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.nunito(fontSize: 14))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final obj = widget.object;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F6FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Thuộc tính ${obj.label}'),
          // === CLOCK ===
          if (obj.type == ObjectType.clock) ...[
            _dropdown(
              obj.clockFont,
              ['YaHei_58', 'YaHei_32', 'Font5x7', 'Font3x5'],
              (v) { setState(() => obj.clockFont = v!); widget.onChanged(); },
            ),
          ],

          // === TEXT ===
          if (obj.type == ObjectType.text) ...[
            Text(
              '@T thời gian full, @d ngày, @M tháng, @y năm, @A ngày âm lịch, @L tháng âm lịch, @D nhiệt độ, @c đếm ngược ngày, @C đếm tiến ngày, @V điện áp pin, @Q số tuần, @q số ngày trong năm',
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text('Nội dung', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _textCtrl,
              style: GoogleFonts.nunito(fontSize: 14),
              onChanged: (v) {
                obj.textContent = v;
                widget.onChanged();
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _dropdown(
                    'font ${obj.textFontSize}',
                    ['font 8', 'font 10', 'font 12', 'font 14', 'font 16', 'font 18', 'font 20'],
                    (v) {
                      setState(() => obj.textFontSize = int.parse(v!.split(' ')[1]));
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Text('Đảo màu', style: GoogleFonts.nunito(fontSize: 14)),
                    Checkbox(
                      value: obj.textInvert,
                      onChanged: (v) {
                        setState(() => obj.textInvert = v!);
                        widget.onChanged();
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ],
            ),
          ],

          // === GEOMETRY ===
          if (obj.type == ObjectType.geometry) ...[
            Row(
              children: [
                Expanded(
                  child: _dropdown(
                    obj.geoShape,
                    ['Hình tròn', 'Hình vuông', 'Hình chữ nhật', 'Tam giác'],
                    (v) { setState(() => obj.geoShape = v!); widget.onChanged(); },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dropdown(
                    obj.geoFill,
                    ['Không có', 'Tô đặc'],
                    (v) { setState(() => obj.geoFill = v!); widget.onChanged(); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Kích thước: ${obj.geoSize.toInt()}', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                const Icon(Icons.edit, size: 16, color: Colors.black45),
              ],
            ),
            Slider(
              value: obj.geoSize,
              min: 5, max: 100,
              activeColor: const Color(0xFF9C27B0),
              onChanged: (v) { setState(() => obj.geoSize = v); widget.onChanged(); },
            ),
            Row(
              children: [
                Text('Độ dày: ${obj.geoThickness.toInt()}', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                const Icon(Icons.edit, size: 16, color: Colors.black45),
              ],
            ),
            Slider(
              value: obj.geoThickness,
              min: 1, max: 10,
              activeColor: const Color(0xFF9C27B0),
              onChanged: (v) { setState(() => obj.geoThickness = v); widget.onChanged(); },
            ),
          ],

          // === IMAGE ===
          if (obj.type == ObjectType.image) ...[
            Text('Hãy chọn 1 ảnh', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ImageBtn(
                    icon: Icons.phone_android_rounded,
                    label: 'Từ điện thoại',
                    onTap: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(source: ImageSource.gallery);
                      if (file != null) {
                        setState(() => obj.imageSource = file.path);
                        widget.onChanged();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ImageBtn(
                    icon: Icons.folder_rounded,
                    label: 'Ảnh có sẵn',
                    onTap: () => showSuccessSnackbar(context, 'Chọn ảnh có sẵn...'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ImageBtn(
              icon: Icons.grid_on_rounded,
              label: 'Chấm từng điểm',
              onTap: () => showSuccessSnackbar(context, 'Mở công cụ chấm điểm...'),
            ),
            const SizedBox(height: 10),
            Text('Ảnh mono: 60 x 40', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.contrast_rounded, size: 18, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text('Đảo màu đen trắng', style: GoogleFonts.nunito(fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
          ],

          // === CALENDAR ===
          if (obj.type == ObjectType.calendar) ...[
            _dropdown(
              obj.calFont,
              ['Font5x7', 'Font3x5', 'YaHei_12'],
              (v) { setState(() => obj.calFont = v!); widget.onChanged(); },
            ),
          ],

          // === SUPER TEXT ===
          if (obj.type == ObjectType.superText) ...[
            Text(
              'Để sử dụng biến số, sử dụng kí tự @ với @d=ngày, @M=Tháng, @y=Năm, @h=giờ, @m=phút, @t = thứ số, @A là ngày âm lịch, @L là tháng âm lịch @D là nhiệt độ @c là đếm ngược ngày, @C là đếm tiến ngày, @V là điện áp pin, @Q là số tuần đã qua trong năm, @q là số ngày trong năm',
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text('Nội dung', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _superTextCtrl,
              style: GoogleFonts.nunito(fontSize: 14),
              onChanged: (v) { obj.superContent = v; widget.onChanged(); },
              decoration: InputDecoration(
                filled: true, fillColor: Colors.white,
                suffixIcon: const Icon(Icons.image_outlined, color: Colors.black38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Text('Chọn font', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _dropdown(
              obj.superFont,
              ['Roboto', 'YaHei', 'PixelFont', 'Digital-7', 'Courier'],
              (v) { setState(() => obj.superFont = v!); widget.onChanged(); },
            ),
            const SizedBox(height: 12),
            Text('Kích cỡ: ${obj.superFontSize.toInt()}', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
            Slider(
              value: obj.superFontSize,
              min: 8, max: 120,
              activeColor: const Color(0xFF9C27B0),
              onChanged: (v) { setState(() => obj.superFontSize = v); widget.onChanged(); },
            ),
            Text('Padding: ${obj.superPadding.toInt()}', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
            Slider(
              value: obj.superPadding,
              min: 0, max: 30,
              activeColor: const Color(0xFF9C27B0),
              onChanged: (v) { setState(() => obj.superPadding = v); widget.onChanged(); },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Màu:', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                ...[
                  (0, Colors.white, Colors.black),
                  (1, Colors.black, Colors.transparent),
                  (2, const Color(0xFFE53935), Colors.transparent),
                ].map((item) {
                  final (idx, bg, border) = item;
                  return GestureDetector(
                    onTap: () { setState(() => obj.superColorIndex = idx); widget.onChanged(); },
                    child: Container(
                      width: 36, height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: obj.superColorIndex == idx ? const Color(0xFF9C27B0) : Colors.black26,
                          width: obj.superColorIndex == idx ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 10),
            Text('Dung lượng font: 0.0 KBytes', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _ImageBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF9C27B0)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// =====================
// D-Pad Widget
// =====================
class _DPad extends StatelessWidget {
  final IconData objectIcon;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const _DPad({
    required this.objectIcon,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  Widget _btn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: color ?? const Color(0xFFB3E5FC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          _btn(Icons.keyboard_arrow_up_rounded, onUp),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn(Icons.keyboard_arrow_left_rounded, onLeft),
              const SizedBox(width: 6),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(objectIcon, size: 26),
              ),
              const SizedBox(width: 6),
              _btn(Icons.keyboard_arrow_right_rounded, onRight),
            ],
          ),
          const SizedBox(height: 6),
          _btn(Icons.keyboard_arrow_down_rounded, onDown),
        ],
      ),
    );
  }
}

// =====================
// File Operations Panel
// =====================
class _FileOperationsPanel extends StatelessWidget {
  final bool highlightWorkObject;
  final ValueChanged<bool> onHighlightChanged;
  final bool isVertical;
  final VoidCallback onRotate;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onResize;

  const _FileOperationsPanel({
    required this.highlightWorkObject,
    required this.onHighlightChanged,
    required this.isVertical,
    required this.onRotate,
    required this.onSave,
    required this.onLoad,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F6FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thao tác với file thiết kế',
            style: GoogleFonts.nunito(
                fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          // Highlight toggle
          InkWell(
            onTap: () => onHighlightChanged(!highlightWorkObject),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    highlightWorkObject ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: Colors.black54,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text('Tô xanh đối tượng làm việc',
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // Rotate screen
          InkWell(
            onTap: onRotate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isVertical ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: Colors.black54,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text('Xoay dọc màn',
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // Resize screen
          InkWell(
            onTap: onResize,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.aspect_ratio_rounded, color: Colors.black54, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Đổi kích cỡ màn hình',
                        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.black54),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Grid buttons
          Row(
            children: [
              Expanded(
                child: _GridBtn(
                  icon: Icons.save_rounded,
                  label: 'Lưu thiết kế\nvào điện thoại',
                  color: AppColors.cardOrangeYellow,
                  onTap: onSave,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GridBtn(
                  icon: Icons.folder_open_rounded,
                  label: 'Mở thiết kế\ntừ điện thoại',
                  color: AppColors.cardBlue,
                  onTap: onLoad,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GridBtn(
                  icon: Icons.download_rounded,
                  label: 'Nạp thiết kế\nxuống đồng hồ',
                  color: AppColors.cardGreen,
                  onTap: () => showSuccessSnackbar(context, 'Đang nạp thiết kế xuống đồng hồ...'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GridBtn(
                  icon: Icons.storefront_rounded,
                  label: 'Chợ\nhiệu ứng',
                  color: AppColors.cardPink,
                  onTap: () => Navigator.pushNamed(context, '/market'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GridBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: Colors.black87),
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String sizeLabel;
  final Color color;

  const _SizeOption({required this.title, required this.subtitle, required this.sizeLabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        showSuccessSnackbar(context, 'Đã đổi độ phân giải thành $sizeLabel');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32, height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black26),
              ),
              child: const Center(child: Icon(Icons.aspect_ratio_rounded, size: 16, color: Colors.black45)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(subtitle, style: GoogleFonts.nunito(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(sizeLabel, style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
