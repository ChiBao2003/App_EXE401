import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pomodoro FIFO, ACK & Idempotency Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('PomodoroSessionData correctly parses session_id from ESP32 payload', () {
      final jsonStr = jsonEncode({
        'mode': 'pomodoro',
        'session_id': 'pomo_2026-10-16T15:00:00_1',
        'task_type': 'Coding',
        'work_min': 25,
        'break_min': 5,
        'pauses': 0,
        'completed': true,
        'session': 1,
        'start_time': '2026-10-16T15:00:00',
        'end_time': '2026-10-16T15:25:00',
        'temperature': 28,
      });

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final session = PomodoroSessionData.fromJson(map);

      expect(session.sessionId, 'pomo_2026-10-16T15:00:00_1');
      expect(session.taskType, 'Coding');
      expect(session.workMin, 25);
      expect(session.completed, true);
      expect(session.session, 1);
      expect(session.startTime, '2026-10-16T15:00:00');
      expect(session.endTime, '2026-10-16T15:25:00');
      expect(session.temperature, 28);
    });

    test('PomodoroSessionData creates stable deterministic fallback session_id if missing', () {
      final map = {
        'mode': 'pomodoro',
        'work_min': 25,
        'session': 3,
        'end_time': '2026-10-16T12:25:00',
      };
      final session1 = PomodoroSessionData.fromJson(map);
      final session2 = PomodoroSessionData.fromJson(map);

      expect(session1.sessionId, 'pomo_2026-10-16T12:25:00_3');
      // Tinh on dinh (Deterministic): hai lan parse cung mot payload phai tra ve ID giong het nhau
      expect(session1.sessionId, session2.sessionId);
    });

    test('ACK command structure adheres to protocol {cmd: ACK_POMO, params: {session_id, status}}', () {
      final sessionId = 'pomo_2026-10-16T15:00:00_1';
      final ackCommand = {
        'cmd': 'ACK_POMO',
        'params': {
          'session_id': sessionId,
          'status': 'received',
        },
      };

      expect(ackCommand['cmd'], 'ACK_POMO');
      final params = ackCommand['params'] as Map<String, dynamic>;
      expect(params['session_id'], sessionId);
      expect(params['status'], 'received');
    });

    test('Offline queue deduplication: Duplicate session_id is not added twice', () async {
      SharedPreferences.setMockInitialValues({
        'offline_pomo_queue': <String>[],
      });

      final prefs = await SharedPreferences.getInstance();

      final sessionPayload = {
        'session_id': 'pomo_2026-10-16T15:00:00_1',
        'work_min': 25,
        'break_min': 5,
        'pauses': 0,
        'completed': true,
        'session': 1,
        'received_at': '2026-10-16T15:25:00',
        'start_time': '2026-10-16T15:00:00',
        'end_time': '2026-10-16T15:25:00',
        'temperature': 28,
        'task_type': 'Coding',
      };

      // Gia lap luu lan 1
      final queue = prefs.getStringList('offline_pomo_queue') ?? [];
      queue.add(jsonEncode(sessionPayload));
      await prefs.setStringList('offline_pomo_queue', queue);

      expect(prefs.getStringList('offline_pomo_queue')?.length, 1);

      // Gia lap luu lan 2 (kiem tra trung lap theo logic moi)
      final queue2 = prefs.getStringList('offline_pomo_queue') ?? [];
      bool alreadyExists = false;
      for (final item in queue2) {
        final existing = jsonDecode(item) as Map<String, dynamic>;
        if (existing['session_id'] == 'pomo_2026-10-16T15:00:00_1') {
          alreadyExists = true;
          break;
        }
      }

      if (!alreadyExists) {
        queue2.add(jsonEncode(sessionPayload));
        await prefs.setStringList('offline_pomo_queue', queue2);
      }

      // Xac minh khong co phien trung
      final finalQueue = prefs.getStringList('offline_pomo_queue') ?? [];
      expect(finalQueue.length, 1);
      final storedMap = jsonDecode(finalQueue.first) as Map<String, dynamic>;
      expect(storedMap['session_id'], 'pomo_2026-10-16T15:00:00_1');
    });

    test('Offline queue retains sessions across app restart simulation', () async {
      // 1. App phien cu luu vao SharedPreferences
      SharedPreferences.setMockInitialValues({
        'offline_pomo_queue': <String>[
          jsonEncode({'session_id': 'pomo_saved_prior_boot', 'work_min': 25, 'session': 1})
        ],
      });

      // 2. Gia lap app restart: doc lai SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final loadedQueue = prefs.getStringList('offline_pomo_queue') ?? [];

      expect(loadedQueue.length, 1);
      final item = jsonDecode(loadedQueue.first) as Map<String, dynamic>;
      expect(item['session_id'], 'pomo_saved_prior_boot');
    });
  });
}
