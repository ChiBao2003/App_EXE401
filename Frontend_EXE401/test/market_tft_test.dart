import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/features/design/design_screen.dart';
import 'package:eink_clock/features/market/domain/entities/market_item.dart';
import 'package:eink_clock/features/market/presentation/widgets/market_card.dart';
import 'tft_protocol_test.dart' show AckBle;

void main() {
  late AckBle ble;
  late SppService spp;
  late Map<String, dynamic> design;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final seeds = jsonDecode(File('../EXE401_Database/market_templates.json').readAsStringSync()) as List;
    design = Map<String, dynamic>.from(seeds[1]['design_json'] as Map);
  });
  tearDown(() async { spp.dispose(); await ble.source.close(); ble.dispose(); });
  Future<void> showMarket(WidgetTester tester) async {
    ble = AckBle(); spp = SppService(ble, retryAutomatically: false);
    tester.view.physicalSize = const Size(800, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final item = MarketItem(id: 'sample',author: 'TFT',timestamp: '',thumbnailUrl: '',designJson: design,likes: 0);
    await tester.pumpWidget(ChangeNotifierProvider<SppService>.value(value: spp,
      child: MaterialApp(routes: {'/design': (_) => const DesignScreen()},
        home: Scaffold(body: SizedBox(width: 350,height: 400,child: MarketCard(item: item,displayIndex: 0))))));
    await tester.pumpAndSettle();
  }
  testWidgets('market install sends the actual template and acknowledges commit', (tester) async {
    await showMarket(tester);
    await tester.tap(find.text('Cài đặt')); await tester.pumpAndSettle();
    expect(find.text('ESP32 đã xác nhận lưu giao diện TFT.'), findsOneWidget);
    final items=ble.packets.where((p) => p['cmd']=='LAYOUT_ITEM').toList();
    expect(items.length, (design['elements'] as List).length);
    final begin=ble.packets.firstWhere((p) => p['cmd']=='LAYOUT_BEGIN')['params'] as Map;
    expect(begin['background'], 0xffff);
    expect(tester.takeException(), isNull);
  });
  testWidgets('market opens every template element in Studio and preserves its background on save', (tester) async {
    await showMarket(tester);
    await tester.tap(find.text('Mở trong Canvas Studio')); await tester.pumpAndSettle();
    expect(find.byType(DesignScreen), findsOneWidget);
    expect(find.text('${(design['elements'] as List).length} phần tử trên bản vẽ'), findsOneWidget);
    await tester.ensureVisible(find.text('Lưu vào Thư viện'));
    await tester.tap(find.text('Lưu vào Thư viện')); await tester.pumpAndSettle();
    final prefs=await SharedPreferences.getInstance();
    final saved=jsonDecode(prefs.getString('saved_design')!) as Map;
    expect(saved['background'], 0xffff);
    expect((saved['elements'] as List).length, (design['elements'] as List).length);
    final first=(saved['elements'] as List).first as Map;
    expect(first['color565'], 0xffff);
    expect(first['width'], 320);
    expect(first['height'], 240);
    expect(tester.takeException(), isNull);
  });
}
