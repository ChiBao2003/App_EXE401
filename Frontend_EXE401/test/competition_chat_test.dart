import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/features/competition/competition_chat_screen.dart';
import 'package:eink_clock/features/competition/competition_screen.dart';

void main() {
  testWidgets('Room chat shows messages and sends as the active member', (
    tester,
  ) async {
    final messages = <Map<String, dynamic>>[
      {
        'id': 'm1',
        'user_id': 'member-b',
        'sender_name': 'Binh',
        'text': 'Chao An',
      },
    ];
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        final text = (jsonDecode(request.body) as Map<String, dynamic>)['text'];
        messages.add({
          'id': 'm2',
          'user_id': 'member-a',
          'sender_name': 'An',
          'text': text,
        });
        return http.Response('{}', 201);
      }
      return http.Response(jsonEncode({'messages': messages}), 200);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: CompetitionChatScreen(
          roomCode: 'ABC123',
          currentUserId: 'member-a',
          httpClient: client,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Chao An'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('competitionChatInput')),
      'Minh bat dau nhe',
    );
    await tester.tap(find.byKey(const Key('competitionChatSend')));
    await tester.pump();
    expect(find.text('Minh bat dau nhe'), findsOneWidget);
  });

  testWidgets('Arena header fits a narrow phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BleService(),
        child: const MaterialApp(
          home: CompetitionScreen(
            initialRoomCode: 'ABC123',
            initialGroupName: 'Phong thu',
            initialLeaderboard: [
              {
                'rank': 1,
                'user_id': 'member-a',
                'display_name': 'An',
                'score': 0,
                'work_min': 0,
                'completed': 0,
              },
            ],
            initialUserId: 'member-a',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('btnRoomChat')), findsOneWidget);
  });

  testWidgets('Arena ranking and watch sync fit a 394dp phone', (tester) async {
    tester.view.physicalSize = const Size(394, 853);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BleService(),
        child: MaterialApp(
          home: CompetitionScreen(
            initialRoomCode: 'ABC123',
            initialGroupName: 'Phòng thi đua năng suất',
            initialDurationDays: 30,
            initialUserId: 'member-a',
            initialLeaderboard: List.generate(
              5,
              (index) => {
                'rank': index + 1,
                'user_id': index == 0 ? 'member-a' : 'member-$index',
                'display_name': 'Thành viên có biệt danh dài $index',
                'score': 100 - index,
                'work_min': 90 - index,
                'completed': 5,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('btnAddSessionBtn')),
      300,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Room chat badge clears after reading messages', (tester) async {
    var unread = 2;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/unread-status') && path.contains('/groups/')) {
        return http.Response(jsonEncode({'unread_count': unread}), 200);
      }
      if (path.endsWith('/messages') && path.contains('/groups/')) {
        unread = 0;
        return http.Response(
          jsonEncode({
            'messages': [
              {
                'id': 'm1',
                'user_id': 'member-b',
                'sender_name': 'Binh',
                'text': 'Chào An',
              },
            ],
          }),
          200,
        );
      }
      if (path.endsWith('/friends/unread-status')) {
        return http.Response(jsonEncode({'total': 0}), 200);
      }
      if (path.contains('/friends/')) {
        return http.Response(
          jsonEncode({
            'friends': [],
            'sent_requests': [],
            'incoming_requests': [],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BleService(),
        child: MaterialApp(
          home: CompetitionScreen(
            initialRoomCode: 'ABC123',
            initialUserId: 'member-a',
            httpClient: client,
            initialLeaderboard: const [
              {
                'rank': 1,
                'user_id': 'member-a',
                'score': 0,
                'work_min': 0,
                'completed': 0,
              },
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btnRoomChat')));
    await tester.pumpAndSettle();
    expect(find.text('Chào An'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('roomChatUnreadBadge')), findsNothing);
  });
}
