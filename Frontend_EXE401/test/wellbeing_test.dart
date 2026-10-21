import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/core/usage_tracking/models.dart';
import 'package:eink_clock/features/digital_wellbeing/wellbeing_screen.dart';

void main() {
  testWidgets('Digital wellbeing header fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BleService()),
          ChangeNotifierProxyProvider<BleService, SppService>(
            create: (ctx) => SppService(ctx.read<BleService>()),
            update: (ctx, ble, prev) => prev ?? SppService(ble),
          ),
        ],
        child: const MaterialApp(
          home: WellbeingScreen(initialHasPermission: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  final sampleTodaySummary = DailyUsageSummary(
    date: DateTime(2026, 10, 15),
    totalScreenTimeMs: 3 * 3600000 + 42 * 60000, // 3h 42m
    totalUnlocks: 42,
    totalDistractions: 3,
    productiveTimeMs: 2 * 3600000 + 13 * 60000, // 2h 13m (60%)
    distractedTimeMs: 55 * 60000, // 55m (25%)
    topApps: [
      AppUsageInfo(
        packageName: 'com.microsoft.vscode',
        appName: 'VS Code & Terminal',
        category: AppCategory.productivity,
        foregroundTimeMs: 1 * 3600000 + 45 * 60000,
        firstTimestamp: DateTime(2026, 10, 15, 8, 0),
        lastTimestamp: DateTime(2026, 10, 15, 10, 0),
      ),
      AppUsageInfo(
        packageName: 'notion.id',
        appName: 'Notion & Tài Liệu Dự Án',
        category: AppCategory.education,
        foregroundTimeMs: 48 * 60000,
        firstTimestamp: DateTime(2026, 10, 15, 10, 0),
        lastTimestamp: DateTime(2026, 10, 15, 11, 0),
      ),
      AppUsageInfo(
        packageName: 'com.zhiliaoapp.musically',
        appName: 'TikTok',
        category: AppCategory.socialMedia,
        foregroundTimeMs: 38 * 60000,
        firstTimestamp: DateTime(2026, 10, 15, 11, 0),
        lastTimestamp: DateTime(2026, 10, 15, 11, 40),
      ),
    ],
    focusScore: 78.0,
  );

  final sampleWeekSummary = DailyUsageSummary(
    date: DateTime(2026, 10, 8),
    totalScreenTimeMs: 24 * 3600000,
    totalUnlocks: 280,
    totalDistractions: 15,
    productiveTimeMs: 16 * 3600000,
    distractedTimeMs: 5 * 3600000,
    topApps: [],
    focusScore: 82.0,
  );

  Widget createWellbeingScreen({
    DailyUsageSummary? summary,
    DailyUsageSummary? weekSummary,
    List<AppUsageInfo>? apps,
    bool? hasPermission,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProxyProvider<BleService, SppService>(
          create: (ctx) => SppService(ctx.read<BleService>()),
          update: (ctx, ble, prev) => prev ?? SppService(ble),
        ),
      ],
      child: MaterialApp(
        home: WellbeingScreen(
          initialSummary: summary,
          initialWeekSummary: weekSummary,
          initialApps: apps,
          initialHasPermission: hasPermission,
        ),
      ),
    );
  }

  testWidgets(
    'WellbeingScreen renders Aether Synapse dashboard with sample data',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        createWellbeingScreen(
          summary: sampleTodaySummary,
          weekSummary: sampleWeekSummary,
          apps: sampleTodaySummary.topApps,
          hasPermission: true,
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Header and Subheader elements
      expect(find.text('Chi Tiết Thiết Bị'), findsOneWidget);
      expect(find.text('Cân Bằng Số'), findsOneWidget);
      expect(
        find.text('Kiểm soát thời gian màn hình & chống xao nhãng'),
        findsOneWidget,
      );
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Tuần'), findsOneWidget);

      // 2. Verify Focus Score & Estimate Labels
      expect(find.text('CHỈ SỐ TẬP TRUNG HÔM NAY'), findsOneWidget);
      expect(find.text('/ 100'), findsOneWidget);
      expect(find.text('Tốt • Tập trung cao'), findsOneWidget);
      expect(find.textContaining('Ước tính thuật toán:'), findsOneWidget);
      expect(
        find.textContaining(
          'Chỉ báo tham khảo từ hành vi sử dụng, không phải chẩn đoán lâm sàng.',
        ),
        findsOneWidget,
      );

      // 3. Verify Screen Time metrics
      expect(find.text('TỔNG THỜI GIAN MÀN HÌNH'), findsOneWidget);
      expect(find.text('3h 42m'), findsOneWidget);
      expect(find.text('Học & Code'), findsOneWidget);
      expect(find.text('Mạng Xã Hội'), findsOneWidget);
      expect(find.text('Tiện Ích'), findsOneWidget);

      // 4. Verify Top Apps
      expect(find.text('VS Code & Terminal'), findsOneWidget);
      expect(find.text('Notion & Tài Liệu Dự Án'), findsOneWidget);
      expect(find.text('TikTok'), findsOneWidget);

      // 5. Verify AI Assistant Bento Card & Action Button
      expect(find.text('TRỢ LÝ AI AETHER'), findsOneWidget);
      expect(find.text('Kích hoạt TFT LCD Focus Lock'), findsOneWidget);
    },
  );

  testWidgets('WellbeingScreen toggles filter between Hôm nay and Tuần', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createWellbeingScreen(
        summary: sampleTodaySummary,
        weekSummary: sampleWeekSummary,
        apps: sampleTodaySummary.topApps,
        hasPermission: true,
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    // Initially "Hôm nay"
    expect(find.text('CHỈ SỐ TẬP TRUNG HÔM NAY'), findsOneWidget);

    // Tap "Tuần"
    await tester.tap(find.text('Tuần'));
    await tester.pump(const Duration(milliseconds: 200));

    // Now updates to "CHỈ SỐ TẬP TRUNG TUẦN"
    expect(find.text('CHỈ SỐ TẬP TRUNG TUẦN'), findsOneWidget);
    expect(find.text('TỔNG THỜI GIAN MÀN HÌNH TUẦN'), findsOneWidget);

    // Switch back to "Hôm nay"
    await tester.tap(find.text('Hôm nay'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('CHỈ SỐ TẬP TRUNG HÔM NAY'), findsOneWidget);
  });

  testWidgets('WellbeingScreen toggles E-ink Focus Lock action button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createWellbeingScreen(
        summary: sampleTodaySummary,
        weekSummary: sampleWeekSummary,
        apps: sampleTodaySummary.topApps,
        hasPermission: true,
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    // Initial state: unlock button exists (may be off-screen)
    expect(find.text('Kích hoạt TFT LCD Focus Lock'), findsOneWidget);

    // Scroll down to make the button visible before tapping
    await tester.scrollUntilVisible(
      find.text('Kích hoạt TFT LCD Focus Lock'),
      200,
    );
    await tester.pumpAndSettle();

    // Tap to lock
    await tester.tap(find.text('Kích hoạt TFT LCD Focus Lock'));
    await tester.pump(const Duration(milliseconds: 300));

    // Now state changed to locked
    expect(find.text('Đã Khóa: Đang Siêu Tập Trung (Tắt)'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    // Tap again to unlock
    await tester.tap(find.text('Đã Khóa: Đang Siêu Tập Trung (Tắt)'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Kích hoạt TFT LCD Focus Lock'), findsOneWidget);
  });

  testWidgets(
    'WellbeingScreen handles empty/no-permission state without crashing',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        createWellbeingScreen(
          summary: null,
          weekSummary: null,
          apps: null,
          hasPermission: false,
        ),
      );

      // Pump a frame
      await tester.pump(const Duration(milliseconds: 100));

      // Verify header is present
      expect(find.text('Chi Tiết Thiết Bị'), findsOneWidget);

      // Permission request content (may need scroll in small viewports)
      await tester.scrollUntilVisible(
        find.text('Cấp Quyền & Bật Theo Dõi'),
        200,
      );
      await tester.pumpAndSettle();

      expect(find.text('Cấp Quyền & Bật Theo Dõi'), findsOneWidget);
    },
  );
}
