
import 'package:flutter_test/flutter_test.dart';
import 'package:eink_clock/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EinkClockApp());
    expect(find.text('Eink Clock'), findsOneWidget);
  });
}
