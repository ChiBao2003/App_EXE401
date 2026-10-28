import 'dart:async';

import 'package:eink_clock/features/startup/startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a first frame while session verification is pending', (
    tester,
  ) async {
    final verification = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(verifySession: () => verification.future),
        routes: {'/login': (_) => const Scaffold(body: Text('Login page'))},
      ),
    );

    expect(find.text('POMO SMART'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    verification.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Login page'), findsOneWidget);
  });

  testWidgets('opens home after a valid session is confirmed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/startup',
        routes: {
          '/startup': (_) => StartupScreen(verifySession: () async => true),
          '/': (_) => const Scaffold(body: Text('Home page')),
        },
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
  });
}
