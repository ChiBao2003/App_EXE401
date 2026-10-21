import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/clock_mode/clock_mode_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'clock_theme_id': 0});
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
      child: const MaterialApp(home: ClockModeScreen()),
    );
  }

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('ClockModeScreen renders Aether Synapse UI elements correctly', (
    WidgetTester tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Header Bar
    expect(find.text('Synapse'), findsOneWidget);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('ESP32 OFFLINE'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);

    // 2. Status pill & Title
    expect(find.text('E-PAPER ENGINE 4.2 ACTIVE'), findsOneWidget);
    expect(find.text('0.8% pin/24h'), findsOneWidget);
    expect(find.text('Màn Hình Chờ E-ink'), findsOneWidget);
    expect(
      find.textContaining('Bộ sưu tập 9 giao diện tiết kiệm năng lượng'),
      findsOneWidget,
    );
    expect(find.textContaining('16 Mức xám Floyd-Steinberg'), findsOneWidget);

    // 3. Hero Preview Mockup Card
    expect(find.text('Mô Phỏng Trực Tiếp (296x128 px)'), findsOneWidget);
    expect(find.text('LIVE 1:1'), findsOneWidget);
    expect(find.text('SYNAPSE STANDBY'), findsOneWidget);
    expect(find.text('FOCUS SESSION'), findsOneWidget);
    expect(find.text('POMO 3/6 • 18M LẠI'), findsOneWidget);

    // 4. Color Mode Selector Controls
    expect(find.text('1-Bit Mono'), findsOneWidget);
    expect(find.text('16 Mức xám'), findsOneWidget);
    expect(find.text('Đèn Amber'), findsOneWidget);

    // 5. Theme Gallery & Category Tabs
    expect(find.text('Thư Viện Giao Diện'), findsOneWidget);
    expect(find.text('Tất cả (9)'), findsOneWidget);
    expect(find.text('Đồng hồ (3)'), findsOneWidget);
    expect(find.text('Pomodoro (3)'), findsOneWidget);
    expect(find.text('Đếm ngược (3)'), findsOneWidget);

    // Initial selected category is 0 (Đồng hồ)
    expect(find.text('Midnight Digital v3'), findsOneWidget);
    expect(find.text('Matrix Minimalist'), findsOneWidget);
    expect(find.text('Astral Solar'), findsOneWidget);

    // 6. Dithering comparison section
    expect(find.text('Tải Ảnh & Dithering 1-Bit'), findsOneWidget);
    expect(find.text('AI CORE'), findsOneWidget);
    expect(find.text('Gốc Màu (RGB)'), findsOneWidget);
    expect(find.text('E-Ink Output (14KB)'), findsOneWidget);
    expect(find.text('Đã khử bóng ma 100%'), findsOneWidget);
    expect(find.text('Tải ảnh từ máy (JPG, PNG, WebP)'), findsOneWidget);

    // 7. Bottom Sync Action
    expect(find.text('Cài Đặt Màn Hình Chờ (Chưa kết nối)'), findsOneWidget);
    expect(
      find.textContaining('Bộ nhớ đệm ROM đồng hồ còn 14/16 slots'),
      findsOneWidget,
    );
  });

  testWidgets(
    'ClockModeScreen switches screen color modes (Mono / Gray / Amber)',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap '16 Mức xám'
      await tester.tap(find.text('16 Mức xám'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('DITHER: GRAY'), findsOneWidget);

      // Tap 'Đèn Amber'
      await tester.tap(find.text('Đèn Amber'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('DITHER: AMBER'), findsOneWidget);

      // Tap '1-Bit Mono'
      await tester.tap(find.text('1-Bit Mono'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('DITHER: MONO'), findsOneWidget);
    },
  );

  testWidgets('ClockModeScreen category switching filters themes correctly', (
    WidgetTester tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 100));

    // Initially in 'Đồng hồ (3)'
    expect(find.text('Midnight Digital v3'), findsOneWidget);

    // Tap 'Pomodoro (3)'
    await tester.tap(find.text('Pomodoro (3)'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Focus Ring'), findsOneWidget);
    expect(find.text('Hourglass Focus'), findsOneWidget);
    expect(find.text('Deep Ocean'), findsOneWidget);

    // Tap 'Đếm ngược (3)'
    await tester.tap(find.text('Đếm ngược (3)'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Pulse Blast'), findsOneWidget);
    expect(find.text('Sand Timer'), findsOneWidget);
    expect(find.text('Matrix Drop'), findsOneWidget);
  });

  testWidgets(
    'ClockModeScreen selecting a theme updates preview and bottom button',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Pomodoro category
      await tester.tap(find.text('Pomodoro (3)'));
      await tester.pump(const Duration(milliseconds: 200));

      // Tap 'Hourglass Focus'
      await tester.tap(find.text('Hourglass Focus'));
      await tester.pump(const Duration(milliseconds: 200));

      // Preview ribbon reflects theme name
      expect(find.text('THEME: HOURGLASS FOCUS'), findsOneWidget);
    },
  );

  testWidgets(
    'ClockModeScreen when disconnected tapping sync shows error snackbar and does not fake success',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      final syncButton = find.text('Cài Đặt Màn Hình Chờ (Chưa kết nối)');
      expect(syncButton, findsOneWidget);

      await tester.tap(syncButton);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Chưa kết nối ESP32! Vào Pomodoro để kết nối BLE trước.'),
        findsOneWidget,
      );
    },
  );
}
