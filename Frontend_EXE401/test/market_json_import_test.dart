import 'dart:convert';

import 'package:eink_clock/core/display/tft_layout.dart';
import 'package:eink_clock/features/market/presentation/widgets/market_json_import_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('pasted JSON renders a live TFT preview and saves locally', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MarketJsonImportSheet())));
    final source = jsonEncode({
      'title': 'Custom Clock',
      'background': 0,
      'elements': [{'t': 'clock', 'x': 20, 'y': 20, 'w': 160, 'h': 50, 'c': 65535}],
    });
    await tester.enterText(find.byType(TextField), source);
    await tester.pump();
    expect(find.byType(TftPreview), findsOneWidget);
    await tester.tap(find.text('Lưu vào máy'));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('personal_tft_designs'), hasLength(1));
  });
}
