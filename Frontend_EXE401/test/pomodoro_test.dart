import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/pomodoro/pomodoro_screen.dart';

void main() {
  testWidgets('TFT settings tile fits a narrow phone', (tester) async {
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
        child: const MaterialApp(home: PomodoroScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Màn hình TFT LCD'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('PomodoroScreen renders UI and explains hardware phase control', (
    WidgetTester tester,
  ) async {
    // Provide BleService and SppService
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BleService()),
          ChangeNotifierProxyProvider<BleService, SppService>(
            create: (ctx) => SppService(ctx.read<BleService>()),
            update: (ctx, ble, prev) => prev ?? SppService(ble),
          ),
        ],
        child: const MaterialApp(home: PomodoroScreen()),
      ),
    );

    // Initial render using pump (with repeating animations, avoid pumpAndSettle)
    await tester.pump(const Duration(milliseconds: 100));

    // Verify main components exist
    expect(find.text('Pomodoro'), findsWidgets);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Phiên gần nhất'), findsOneWidget);
    expect(find.text('AI Synapse Coach'), findsOneWidget);
    expect(find.text('Đồng bộ ngoại vi ESP32'), findsOneWidget);
    expect(find.text('Gửi cấu hình sang đồng hồ TFT LCD ngay'), findsOneWidget);

    // Verify initial phase is work session
    expect(find.textContaining('25 Phút Chuẩn'), findsOneWidget);

    // Tap Skip Break button (Icons.skip_next_rounded)
    final skipButton = find.byIcon(Icons.skip_next_rounded);
    expect(skipButton, findsOneWidget);
    await tester.tap(skipButton);
    await tester.pump(const Duration(milliseconds: 100));

    // The ESP32 owns phase changes; the app explains this when Skip is tapped.
    expect(
      find.text('ESP32 tự chuyển pha khi kết thúc thời gian.'),
      findsOneWidget,
    );
    expect(find.text('25:00'), findsOneWidget);
  });
}
