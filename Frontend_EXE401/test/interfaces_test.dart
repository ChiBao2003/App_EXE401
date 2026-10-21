import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/interfaces/interfaces_screen.dart';
import 'tft_protocol_test.dart' show AckBle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AckBle ble;
  late SppService spp;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async { spp.dispose(); await ble.source.close(); ble.dispose(); });
  Future<void> showControls(WidgetTester tester) async {
    ble = AckBle(); spp = SppService(ble, retryAutomatically: false);
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ChangeNotifierProvider<SppService>.value(value: spp,
      child: const MaterialApp(home: InterfacesScreen())));
    await tester.pumpAndSettle();
  }
  testWidgets('shows physical modes, themes and confirmed custom NVS state', (tester) async {
    await showControls(tester);
    for (final title in ['Đồng hồ chính','Pomodoro','Đếm ngược','Loa Bluetooth A2DP','Flip Clock','Analog Dial','Sunset Digital']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('1 phần tử trong NVS'), findsOneWidget);
    expect(find.textContaining('Waveform'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mode taps send SET_MODE and color/theme taps send SET_THEME', (tester) async {
    await showControls(tester);
    await tester.tap(find.text('Pomodoro')); await tester.pumpAndSettle();
    expect(ble.packets.last['cmd'], 'SET_MODE');
    expect((ble.packets.last['params'] as Map)['mode'], 1);
    await tester.tap(find.textContaining('Neon Green')); await tester.pumpAndSettle();
    await tester.tap(find.text('Analog Dial')); await tester.pumpAndSettle();
    final theme = ble.packets.lastWhere((p) => p['cmd'] == 'SET_THEME')['params'] as Map;
    expect(theme['theme_id'], 1); expect(theme['color'], '00ff00');
    expect(ble.packets.last['cmd'], 'SET_MODE');
    expect((ble.packets.last['params'] as Map)['mode'], 0);
    expect(ble.packets.any((p) => p['cmd'] == 'SET_ROTATION'), isFalse);
  });
}
