import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/design/design_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'saved_design': jsonEncode([
        {
          'id': 'test-1',
          'type': 'clock',
          'x': 50.0,
          'y': 25.0,
          'clockFont': 'Outfit Mono Bold',
          'textInvert': false,
        },
        {
          'id': 'test-2',
          'type': 'text',
          'x': 10.0,
          'y': 10.0,
          'textContent': 'Hello TFT',
          'textFontSize': 12,
          'textInvert': false,
        },
      ]),
    });
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProxyProvider<BleService, SppService>(
          create: (ctx) => SppService(ctx.read<BleService>()),
          update: (ctx, ble, prev) => prev ?? SppService(ble),
        ),
      ],
      child: const MaterialApp(home: DesignScreen()),
    );
  }

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets(
    'DesignScreen renders Aether Synapse studio layout with all modules',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));

      // Header Bar
      expect(find.text('Trình Chỉnh Sửa Mặt Đồng Hồ'), findsOneWidget);

      // Ambient Telemetry Banner
      expect(find.textContaining('Bảng vẽ TFT 320 x 240 px'), findsOneWidget);
      expect(find.text('ESP32 Offline'), findsOneWidget);

      // Toolbar Controls
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.redo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grid_4x4_rounded), findsOneWidget);
      expect(find.text('200%'), findsOneWidget);
      expect(find.text('Nạp ESP32'), findsOneWidget);

      // Simulated E-paper Frame
      expect(find.text('XEM TRƯỚC TFT ILI9341'), findsOneWidget);
      expect(find.text('Cập nhật màu'), findsOneWidget);
      expect(find.textContaining('320x240 RGB565'), findsOneWidget);
      expect(find.text('Bộ màu: RGB565'), findsOneWidget);
      expect(find.text('4 phần tử trên bản vẽ'), findsOneWidget);

      // Add Elements Dock
      expect(find.text('THÊM PHẦN TỬ NHANH'), findsOneWidget);
      expect(find.text('Đồng hồ'), findsWidgets);
      expect(find.text('Văn bản'), findsWidgets);
      expect(find.text('Hình học'), findsWidgets);
      expect(find.text('Ảnh Bitmap'), findsWidgets);
      expect(find.text('Lịch biểu'), findsWidgets);
      expect(find.text('Cảm biến'), findsWidgets);

      // Property Inspector
      expect(find.text('Thuộc tính phần tử'), findsOneWidget);
      expect(find.text('Đảo Ngược Màu (Invert)'), findsOneWidget);
      expect(find.text('Tọa độ & Kích thước Pixel:'), findsOneWidget);
      expect(find.text('Chu kỳ làm mới màn hình:'), findsOneWidget);

      // Hardware Memory Card
      expect(find.text('Bộ nhớ bố cục TFT:'), findsOneWidget);
      expect(find.text('TỐI ƯU'), findsOneWidget);
      expect(find.text('Đang dùng 4/12 phần tử bố cục'), findsOneWidget);
      expect(find.text('Vị trí còn lại'), findsOneWidget);

      // Bottom Primary Action Buttons
      expect(find.text('Xem trên Đồng hồ thật'), findsOneWidget);
      expect(find.text('Lưu vào Thư viện'), findsOneWidget);
    },
  );

  testWidgets('Studio toolbar and quick elements fit a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 150));
    await tester.ensureVisible(find.text('THÊM PHẦN TỬ NHANH'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Text content updates and saves without pressing Enter', (
    tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.widgetWithText(InkWell, 'Văn bản'));
    await tester.pump();
    final contentField = find.byType(TextFormField).first;
    await tester.enterText(contentField, 'TEST');
    await tester.pump();
    await tester.enterText(contentField, 'TEST TFT 123');
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Lưu vào Thư viện'));
    await tester.tap(find.text('Lưu vào Thư viện'));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('saved_design')!) as Map;
    final elements = saved['elements'] as List;
    expect(elements.last['textContent'], 'TEST TFT 123');
  });

  testWidgets(
    'Adding an element from dock adds to canvas and updates counter',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('4 phần tử trên bản vẽ'), findsOneWidget);

      // Tap on 'Hình học' in dock
      final geoBtn = find.widgetWithText(InkWell, 'Hình học');
      expect(geoBtn, findsOneWidget);
      await tester.tap(geoBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Elements count should increase to 5
      expect(find.text('5 phần tử trên bản vẽ'), findsOneWidget);
    },
  );

  testWidgets('editing image X near the right edge keeps Studio stable', (
    tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.widgetWithText(InkWell, 'Ảnh Bitmap'));
    await tester.pumpAndSettle();
    final xValue = find.text('X').last;
    await tester.tap(xValue);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '300');
    await tester.tap(find.text('Lưu').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Real Undo and Redo operations function accurately on canvas', (
    WidgetTester tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('4 phần tử trên bản vẽ'), findsOneWidget);

    // 1. Add 'Lịch biểu'
    final calBtn = find.widgetWithText(InkWell, 'Lịch biểu');
    await tester.tap(calBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('5 phần tử trên bản vẽ'), findsOneWidget);

    // 2. Undo
    final undoBtn = find.byIcon(Icons.undo_rounded);
    await tester.tap(undoBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('4 phần tử trên bản vẽ'), findsOneWidget);

    // 3. Redo
    final redoBtn = find.byIcon(Icons.redo_rounded);
    await tester.tap(redoBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('5 phần tử trên bản vẽ'), findsOneWidget);
  });

  testWidgets('Toggling grid and zoom updates toolbar state', (
    WidgetTester tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 150));

    // Grid toggle
    final gridBtn = find.byIcon(Icons.grid_4x4_rounded);
    await tester.tap(gridBtn);
    await tester.pump(const Duration(milliseconds: 100));

    // Zoom toggle 200% -> 100%
    final zoomBtn = find.text('200%');
    expect(zoomBtn, findsOneWidget);
    await tester.tap(zoomBtn);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets(
    'Local persistence: saving and loading designs with SharedPreferences',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));

      // Tap save
      final saveBtn = find.text('Lưu vào Thư viện');
      await tester.tap(saveBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // Verify SnackBar
      expect(
        find.textContaining('Đã lưu 4 phần tử thiết kế vào bộ nhớ máy!'),
        findsOneWidget,
      );

      // Verify SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('saved_design');
      expect(savedData, isNotNull);
      expect(savedData!.contains('el-clock'), isTrue);

      // Tap load design from folder icon
      final loadBtn = find.byIcon(Icons.folder_open_rounded);
      expect(loadBtn, findsOneWidget);
      await tester.tap(loadBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // When newly loaded from SharedPreferences (which was saved with 4 items above)
      expect(find.textContaining('phần tử từ điện thoại!'), findsOneWidget);
    },
  );

  testWidgets(
    'Corrupted save file handling: loading invalid JSON displays error safely without crashing',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));

      // Set corrupt data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_design', '{corrupted_not_a_json_list}');

      // Tap load design
      final loadBtn = find.byIcon(Icons.folder_open_rounded);
      await tester.tap(loadBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // Verify safe error SnackBar shown without crashing
      expect(
        find.textContaining('Tệp lưu bị lỗi hoặc không tương thích:'),
        findsOneWidget,
      );
      // Canvas still has valid elements
      expect(find.byType(DesignScreen), findsOneWidget);
    },
  );

  testWidgets(
    'When ESP32 is offline, tapping Flash or Live Preview warns user without false sync success',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));

      // Tap 'Nạp ESP32'
      final flashBtn = find.text('Nạp ESP32');
      await tester.tap(flashBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // Verify warning message
      expect(
        find.text(
          'Chưa kết nối ESP32 qua BLE. Kết nối thiết bị trước khi nạp TFT.',
        ),
        findsOneWidget,
      );

      // Tap 'Xem trên Đồng hồ thật'
      final liveBtn = find.text('Xem trên Đồng hồ thật');
      await tester.tap(liveBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // Still shows disconnected warning, does NOT fake success
      expect(
        find.text(
          'Chưa kết nối ESP32 qua BLE. Kết nối thiết bị trước khi nạp TFT.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Selecting screen resolution updates canvas dimensions and status badge',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));

      // Tap resolution settings icon
      final resBtn = find.byTooltip('Chọn độ phân giải');
      expect(resBtn, findsOneWidget);
      await tester.tap(resBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // Verify dialog opened
      expect(find.text('Màn hình TFT LCD Shield'), findsOneWidget);
      expect(find.text('ILI9341 • xoay ngang'), findsOneWidget);

      // Select 212x104
      await tester.tap(find.text('ILI9341 • xoay ngang'));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify ambient banner updated
      expect(find.textContaining('320 x 240'), findsOneWidget);
    },
  );
}
