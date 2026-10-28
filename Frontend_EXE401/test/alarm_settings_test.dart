import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/general_settings/general_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Thêm mới opens the real alarm time picker', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProxyProvider<BleService, SppService>(
          create: (context) => SppService(context.read<BleService>()),
          update: (context, ble, previous) => previous ?? SppService(ble),
        ),
      ],
      child: const MaterialApp(home: GeneralSettingsScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Thêm mới'));
    await tester.tap(find.text('Thêm mới'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
