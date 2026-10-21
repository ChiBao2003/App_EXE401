import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/general_settings/general_settings_screen.dart';
import 'package:eink_clock/features/info/info_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'setting_rtc_offset': '0.00',
      'setting_deep_sleep': true,
      'setting_sleep_start': '23:00',
      'setting_sleep_end': '06:30',
      'setting_night_screen': 'minimal',
      'setting_alarm1_enabled': true,
      'setting_alarm2_enabled': true,
    });
  });

  Widget buildTestWidget({bool useInfoScreen = false}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProxyProvider<BleService, SppService>(
          create: (ctx) => SppService(ctx.read<BleService>()),
          update: (ctx, ble, prev) => prev ?? SppService(ble),
        ),
      ],
      child: MaterialApp(
        home: useInfoScreen
            ? const InfoScreen()
            : const GeneralSettingsScreen(),
      ),
    );
  }

  void setupViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets(
    'GeneralSettingsScreen renders Aether Synapse 5 sections correctly',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Header Bar
      expect(find.text('Cài Đặt Hệ Thống'), findsOneWidget);
      expect(find.text('BLE OFFLINE'), findsOneWidget);

      // Section 1: Time Sync
      expect(find.text('Đồng bộ Thời Gian (Time Sync)'), findsOneWidget);
      expect(find.text('RTC DS3231'), findsOneWidget);
      expect(find.text('THỜI GIAN CHUẨN ĐIỆN THOẠI'), findsOneWidget);
      expect(find.text('GMT+7 (ICT)'), findsOneWidget);
      expect(find.text('Đồng bộ giờ sang đồng hồ E-ink ngay'), findsOneWidget);
      expect(find.text('Hiệu chỉnh sai số phần cứng RTC'), findsOneWidget);
      expect(find.text('0s (Chuẩn)'), findsOneWidget);
      expect(find.text('+1s Nhanh'), findsOneWidget);
      expect(find.text('-1s Chậm'), findsOneWidget);
      expect(find.text('±0.05s Fine'), findsOneWidget);

      // Section 2: Power & Sleep
      expect(find.text('Tiết Kiệm Năng Lượng & Ngủ'), findsOneWidget);
      expect(find.text('Ngủ Sâu Siêu Tiết Kiệm'), findsOneWidget);
      expect(find.text('28 Ngày PIN'), findsOneWidget);
      expect(find.text('Bắt đầu ngủ'), findsOneWidget);
      expect(find.text('Thức dậy'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
      expect(find.text('06:30'), findsWidgets);
      expect(find.text('Màn hình tĩnh ban đêm'), findsOneWidget);

      // Section 3: Alarms & Timers
      expect(find.text('Báo Thức & Bộ Đếm Giờ'), findsOneWidget);
      expect(find.text('Thêm mới'), findsOneWidget);
      expect(find.text('T2 - T6'), findsOneWidget);
      expect(find.text('Hằng ngày'), findsOneWidget);
      expect(find.text('Lối tắt đếm giờ nhanh E-ink'), findsOneWidget);
      expect(find.text('25p'), findsOneWidget);
      expect(find.text('5p'), findsOneWidget);
      expect(find.text('15p'), findsOneWidget);
      expect(find.text('60p'), findsOneWidget);

      // Section 4: OTA Firmware
      expect(find.text('Cập Nhật Phần Cứng (OTA)'), findsOneWidget);
      expect(find.text('BLE 5.3 READY'), findsOneWidget);
      expect(find.text('ESP32-S3 Dual-Core'), findsOneWidget);
      expect(find.text('GDEW029T5D 2.9"'), findsOneWidget);
      expect(find.text('Synapse AI v2.5.0'), findsOneWidget);
      expect(find.textContaining('Bản Cập Nhật:'), findsOneWidget);
      expect(find.text('1.42 MB'), findsOneWidget);
      expect(find.text('Điểm mới trong bản nâng cấp:'), findsOneWidget);
      expect(find.text('100% Sẵn sàng nạp'), findsOneWidget);
      expect(
        find.text('Nạp Firmware qua BLE ngay (Ước tính 45s)'),
        findsOneWidget,
      );

      // Section 5: System Maintenance
      expect(find.text('Dữ Liệu & Bảo Trì (Maintenance)'), findsOneWidget);
      expect(find.text('Xóa bóng mờ E-ink (Ghosting Purge)'), findsOneWidget);
      expect(find.text('Quét Sạch'), findsOneWidget);
      expect(find.text('Xuất nhật ký phần cứng (.log)'), findsOneWidget);
      expect(find.text('Tải về'), findsOneWidget);
      expect(find.text('Khôi phục cài đặt gốc ESP32'), findsOneWidget);
      expect(find.text('Reset NVS'), findsOneWidget);
    },
  );

  testWidgets('InfoScreen delegates cleanly to GeneralSettingsScreen', (
    WidgetTester tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget(useInfoScreen: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cài Đặt Hệ Thống'), findsOneWidget);
    expect(find.text('Đồng bộ Thời Gian (Time Sync)'), findsOneWidget);
    expect(find.text('Cập Nhật Phần Cứng (OTA)'), findsOneWidget);
  });

  testWidgets('Tapping RTC offset pill updates selection and persists', (
    WidgetTester tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('0.00s'), findsOneWidget);

    // Tap '+1s Nhanh'
    await tester.tap(find.text('+1s Nhanh'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('+1.00s'), findsOneWidget);

    // Verify persistence
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('setting_rtc_offset'), '+1.00');
  });

  testWidgets('Toggling deep sleep switch updates preference', (
    WidgetTester tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 100));

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3)); // Deep sleep + Alarm 1 + Alarm 2

    // Tap deep sleep switch
    await tester.tap(switches.first);
    await tester.pump(const Duration(milliseconds: 200));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('setting_deep_sleep'), false);
  });

  testWidgets(
    'When disconnected, tapping Time Sync displays warning and does not claim success',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      final syncBtn = find.text('Đồng bộ giờ sang đồng hồ E-ink ngay');
      expect(syncBtn, findsOneWidget);

      await tester.tap(syncBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Chưa kết nối ESP32! Vào Pomodoro để kết nối BLE trước.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('When disconnected, tapping Ghosting Purge displays warning', (
    WidgetTester tester,
  ) async {
    setupViewport(tester);
    await tester.pumpWidget(buildTestWidget());
    await tester.pump(const Duration(milliseconds: 100));

    final purgeBtn = find.text('Quét Sạch');
    expect(purgeBtn, findsOneWidget);

    await tester.tap(purgeBtn);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Chưa kết nối ESP32 để gửi lệnh làm mới toàn màn hình.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'When disconnected, tapping Flash OTA button displays warning and does not fake completion',
    (WidgetTester tester) async {
      setupViewport(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      final flashBtn = find.text('Nạp Firmware qua BLE ngay (Ước tính 45s)');
      expect(flashBtn, findsOneWidget);

      await tester.tap(flashBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(
          'Chưa kết nối ESP32 qua BLE! Hãy kết nối thiết bị trước khi nạp.',
        ),
        findsOneWidget,
      );
    },
  );
}
