import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/ai_hub/ai_assistant_screen.dart';

void main() {
  testWidgets('AI chat header and input fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
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
        child: const MaterialApp(home: AIAssistantScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byType(TextField),
      'Một câu hỏi khá dài để kiểm tra thanh nhập chat',
    );
    await tester.pump();
    final mic = tester.getRect(find.byIcon(Icons.mic_none_rounded));
    final input = tester.getRect(find.byType(TextField));
    final send = tester.getRect(find.byIcon(Icons.arrow_upward_rounded));
    expect(mic.right, lessThanOrEqualTo(input.left));
    expect(input.right, lessThanOrEqualTo(send.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AIAssistantScreen renders chat header, subheader, and message list',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BleService()),
            ChangeNotifierProxyProvider<BleService, SppService>(
              create: (ctx) => SppService(ctx.read<BleService>()),
              update: (ctx, ble, prev) => prev ?? SppService(ble),
            ),
          ],
          child: const MaterialApp(home: AIAssistantScreen()),
        ),
      );

      // Initial render
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Header & Subheader
      expect(find.text('SYNAPSE OS'), findsOneWidget);
      expect(find.text('Live AI Coach'), findsOneWidget);
      expect(find.text('Synapse Coach'), findsOneWidget);
      expect(find.text('Gemini Pro v2.5'), findsOneWidget);
      expect(find.text('Digital Twin'), findsOneWidget);

      // 2. Verify Initial AI Message
      expect(
        find.textContaining(
          'Chào bạn! Mình nhận thấy chỉ số biến thiên nhịp tim',
        ),
        findsOneWidget,
      );

      // 3. Verify Quick Prompts Carousel
      expect(find.text('Lên lịch ngày mai'), findsOneWidget);
      expect(find.text('Kiểm tra mức độ kiệt sức'), findsOneWidget);

      // 4. Verify Input field and send button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      // 5. Test entering user prompt
      await tester.enterText(find.byType(TextField), 'Xin chào AI Coach!');
      await tester.pump(const Duration(milliseconds: 100));

      // Tap send button
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify user message appears in list
      expect(find.text('Xin chào AI Coach!'), findsOneWidget);
    },
  );
}
