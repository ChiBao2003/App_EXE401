
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:eink_clock/main.dart';
import 'package:eink_clock/features/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App entry point opens login with valid providers and routes', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const EinkClockApp(initialRoute: '/login'));
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'AI Productivity Watch');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
