import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/features/competition/competition_screen.dart';

void main() {
  final sampleLeaderboard = [
    {
      'rank': 1,
      'user_id': 'Hoàng Long',
      'score': 1125,
      'work_min': 1125,
      'completed': 45,
    },
    {
      'rank': 2,
      'user_id': 'Minh Anh',
      'score': 920,
      'work_min': 920,
      'completed': 36,
    },
    {
      'rank': 3,
      'user_id': 'user_bao',
      'score': 850,
      'work_min': 850,
      'completed': 34,
    },
    {
      'rank': 4,
      'user_id': 'Trần Tuấn',
      'score': 750,
      'work_min': 750,
      'completed': 30,
    },
    {
      'rank': 5,
      'user_id': 'Lê Hương',
      'score': 665,
      'work_min': 665,
      'completed': 26,
    },
  ];

  Widget createCompetitionScreen({
    String? initialRoomCode,
    List<dynamic>? initialLeaderboard,
    String? initialGroupName,
    int? initialDurationDays,
    bool? initialExpired,
    String? initialUserId,
    http.Client? httpClient,
  }) {
    return ChangeNotifierProvider(
      create: (_) => BleService(),
      child: MaterialApp(
        routes: {
          '/pomodoro': (ctx) =>
              const Scaffold(body: Text('Pomodoro Screen Mock')),
        },
        home: CompetitionScreen(
          initialRoomCode: initialRoomCode,
          initialLeaderboard: initialLeaderboard,
          initialGroupName: initialGroupName,
          initialDurationDays: initialDurationDays,
          initialExpired: initialExpired,
          initialUserId: initialUserId,
          httpClient: httpClient,
        ),
      ),
    );
  }

  group('CompetitionScreen Widget Tests', () {
    testWidgets('Renders Lobby view when no room is joined', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createCompetitionScreen());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Đấu Trường Năng Suất'), findsOneWidget);
      expect(find.text('THAM GIA PHÒNG THI ĐUA'), findsOneWidget);
      expect(find.text('Vào Phòng Thi Đua'), findsOneWidget);
      expect(find.text('HOẶC TẠO PHÒNG MỚI'), findsOneWidget);
      expect(find.text('Tạo Phòng Mới Ngay'), findsOneWidget);
      expect(find.text('TÊN HIỂN THỊ CỦA BẠN'), findsOneWidget);
    });

    testWidgets('Renders Arena view with Top 3 Podium and Leaderboard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createCompetitionScreen(
          initialRoomCode: 'SYN-882',
          initialGroupName: 'Phòng Luyện Code ESP32 & AI 2025',
          initialLeaderboard: sampleLeaderboard,
          initialUserId: 'user_bao',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Top App Bar & Room Banner
      expect(find.text('Synapse'), findsOneWidget);
      expect(find.text('SYN-882'), findsOneWidget);
      expect(find.text('Phòng Luyện Code ESP32 & AI 2025'), findsOneWidget);
      expect(find.textContaining('ĐANG DIỄN RA'), findsOneWidget);
      expect(find.byKey(const Key('btnSwitchRoom')), findsOneWidget);

      // 2. Verify Top 3 Podium
      expect(find.text('Hoàng Long'), findsWidgets);
      expect(find.text('Minh Anh'), findsWidgets);
      expect(find.text('Master Focus'), findsOneWidget);

      // 3. Verify Your Position Card
      expect(find.text('Bạn (user_bao)'), findsOneWidget);
      expect(find.text('Watch Sync'), findsOneWidget);
      expect(find.text('+850 pts'), findsOneWidget);

      // 4. Verify Chasers List (Top 4+)
      expect(find.text('Trần Tuấn'), findsOneWidget);
      expect(find.text('Lê Hương'), findsOneWidget);

      // 5. Verify Telemetry & Action Buttons
      expect(find.text('Đồng bộ E-ink Watch'), findsOneWidget);
      expect(find.byKey(const Key('btnAddSessionBtn')), findsOneWidget);
      expect(find.byKey(const Key('btnLeaveRoom')), findsOneWidget);
      expect(find.byKey(const Key('btnTestSession')), findsOneWidget);
    });

    testWidgets('Renders empty state when room has no leaderboard entries', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createCompetitionScreen(
          initialRoomCode: 'EMPTY-01',
          initialGroupName: 'Phòng Trống',
          initialLeaderboard: [],
          initialUserId: 'user_new',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('EMPTY-01'), findsOneWidget);
      expect(find.text('Phòng Trống'), findsOneWidget);
      expect(
        find.text('Chưa có dữ liệu thi đua trong phòng này'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Hãy hoàn thành một phiên Pomodoro để trở thành người dẫn đầu!',
        ),
        findsOneWidget,
      );
      expect(find.text('Bạn (user_new)'), findsOneWidget);
    });

    testWidgets('Toggles time period filter chips', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/leaderboard/SYN-882')) {
          return http.Response(
            jsonEncode({
              'room_code': 'SYN-882',
              'group_name': 'Phòng Luyện Code ESP32 & AI 2025',
              'duration_days': 7,
              'expired': false,
              'period': request.url.queryParameters['period'] ?? 'all',
              'leaderboard': sampleLeaderboard,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"detail": "Not found"}', 404);
      });

      await tester.pumpWidget(
        createCompetitionScreen(
          initialRoomCode: 'SYN-882',
          initialGroupName: 'Phòng Luyện Code ESP32 & AI 2025',
          initialLeaderboard: sampleLeaderboard,
          httpClient: mockClient,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Hôm nay" chip
      final todayChip = find.text('Hôm nay');
      expect(todayChip, findsOneWidget);
      await tester.tap(todayChip);
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Tuần này" chip
      final weekChip = find.text('Tuần này');
      expect(weekChip, findsOneWidget);
      await tester.tap(weekChip);
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets(
      'Copies room code and opens switch room modal and leave dialog',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createCompetitionScreen(
            initialRoomCode: 'SYN-882',
            initialGroupName: 'Phòng Luyện Code ESP32 & AI 2025',
            initialLeaderboard: sampleLeaderboard,
            initialUserId: 'user_bao',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Test Copy Code Button
        final copyBtn = find.byKey(const Key('btnCopyCode'));
        expect(copyBtn, findsOneWidget);
        await tester.tap(copyBtn);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        // 2. Test Switch Room Button
        final switchBtn = find.byKey(const Key('btnSwitchRoom'));
        expect(switchBtn, findsOneWidget);
        await tester.tap(switchBtn);
        await tester.pumpAndSettle();
        expect(find.text('Đổi Phòng Hoặc Nhập PIN'), findsOneWidget);
        expect(find.text('Chuyển Đến Phòng Này'), findsOneWidget);

        // Close modal
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // 3. Test Leave Room Button
        final leaveBtn = find.byKey(const Key('btnLeaveRoom'));
        await tester.ensureVisible(leaveBtn);
        await tester.tap(leaveBtn);
        await tester.pumpAndSettle();
        expect(find.text('Rời phòng thi đua?'), findsOneWidget);
        expect(find.text('Rời phòng'), findsOneWidget);
        expect(find.text('Ở lại'), findsOneWidget);

        // Confirm leaving room
        await tester.tap(find.text('Rời phòng'));
        await tester.pumpAndSettle();

        // Should return to Lobby view
        expect(find.text('Đấu Trường Năng Suất'), findsOneWidget);
        expect(find.text('THAM GIA PHÒNG THI ĐUA'), findsOneWidget);
      },
    );

    testWidgets('Submits test session via btnTestSession', (
      WidgetTester tester,
    ) async {
      bool submitCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/submit')) {
          submitCalled = true;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'prs_earned': 40,
              'message': 'Tuyệt vời! Bạn nhận được 40 điểm PRS.',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.contains('/leaderboard/SYN-882')) {
          return http.Response(
            jsonEncode({
              'room_code': 'SYN-882',
              'group_name': 'Phòng Luyện Code ESP32 & AI 2025',
              'duration_days': 7,
              'expired': false,
              'period': 'all',
              'leaderboard': sampleLeaderboard,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"detail": "Not found"}', 404);
      });

      await tester.pumpWidget(
        createCompetitionScreen(
          initialRoomCode: 'SYN-882',
          initialGroupName: 'Phòng Luyện Code ESP32 & AI 2025',
          initialLeaderboard: sampleLeaderboard,
          initialUserId: 'user_bao',
          httpClient: mockClient,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final testBtn = find.byKey(const Key('btnTestSession'));
      await tester.ensureVisible(testBtn);
      await tester.tap(testBtn);
      await tester.pumpAndSettle();

      expect(submitCalled, isTrue);
    });

    testWidgets('Navigates to pomodoro on btnAddSessionBtn tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createCompetitionScreen(
          initialRoomCode: 'SYN-882',
          initialGroupName: 'Phòng Luyện Code ESP32 & AI 2025',
          initialLeaderboard: sampleLeaderboard,
          initialUserId: 'user_bao',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final addBtn = find.byKey(const Key('btnAddSessionBtn'));
      await tester.ensureVisible(addBtn);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Pomodoro Screen Mock'), findsOneWidget);
    });
  });
}
