import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/ai_hub/ai_hub_screen.dart';

void main() {
  testWidgets('AiHubScreen renders header and displays initial loading state', (WidgetTester tester) async {
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
          home: AiHubScreen(),
        ),
      ),
    );

    // Initial render: verify header elements appear immediately
    expect(find.text('SYNAPSE OS'), findsOneWidget);
    expect(find.text('Ai Hub'), findsWidgets);

    // Initial async loading state is shown
    expect(find.text('Đang kết nối Cognitive State & AI Agent...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pump a short duration to ensure frame stability without crashing
    await tester.pump(const Duration(milliseconds: 100));
  });
}
