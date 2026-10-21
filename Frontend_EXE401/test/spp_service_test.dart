import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/pomodoro_outbox.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBle extends BleService {
  BleConnectionState connection = BleConnectionState.disconnected;
  final source = StreamController<String>.broadcast();
  final commands = <Map<String, dynamic>>[];
  int active = 0, maximum = 0, starts = 0;
  bool sendSucceeds = true;

  @override
  BleConnectionState get state => connection;
  @override
  bool get isConnected => connection == BleConnectionState.connected;
  @override
  Stream<String> get dataStream => Stream<String>.multi((sink) {
    active++;
    starts++;
    if (active > maximum) maximum = active;
    final subscription = source.stream.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.onCancel = () async {
      await subscription.cancel();
      active--;
    };
  }, isBroadcast: true);

  void setConnection(BleConnectionState value) {
    connection = value;
    notifyListeners();
  }

  @override
  Future<bool> sendJson(Map<String, dynamic> payload) async {
    if (!sendSucceeds || !isConnected) return false;
    commands.add(payload);
    return true;
  }

  int get acks => commands.where((p) => p['cmd'] == 'ACK_POMO').length;
  @override
  void stopScan() {}
  @override
  void dispose() {
    unawaited(source.close());
    super.dispose();
  }
}

class MemoryOutbox extends PomodoroOutbox {
  List<String> committed = [];
  bool failWrites = false;
  bool throwWrites = false;
  bool pretendSuccess = false;
  int writes = 0;
  @override
  Future<List<String>> read() async => List.of(committed);
  @override
  Future<bool> write(List<String> entries) async {
    writes++;
    if (throwWrites) throw const FileSystemException('disk full');
    if (failWrites) return false;
    if (!pretendSuccess) committed = List.of(entries);
    return true;
  }
}

Map<String, dynamic> packet({
  bool completed = true,
  String id = 'pomo_2026-10-19T12:00:00_1',
}) => {
  'mode': 'pomodoro',
  'session_id': id,
  'task_type': 'Coding',
  'work_min': 25,
  'break_min': 5,
  'pauses': 2,
  'completed': completed,
  'session': 1,
  'start_time': '2026-10-19T12:00:00',
  'end_time': completed ? '2026-10-19T12:25:00' : '2026-10-19T12:12:00',
  'temperature': 28,
};

Future<void> until(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Timed out waiting for service operation');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBle ble;
  late MemoryOutbox outbox;
  late List<Map<String, dynamic>> requests;
  late SppService service;
  late bool backendFails;
  late dynamic response;
  final actualPayloads = <Map<String, dynamic>>[];

  tearDownAll(() async {
    final output = File('build/pomodoro_audit_payloads.json');
    await output.parent.create(recursive: true);
    await output.writeAsString(jsonEncode(actualPayloads));
  });

  Future<dynamic> post(String path, Map<String, dynamic> payload) async {
    expect(path, '/api/v1/pomodoro/sync');
    requests.add(payload);
    if (backendFails) throw TimeoutException('offline');
    return response;
  }

  SppService create({bool timer = false}) => SppService(
    ble,
    post: post,
    outbox: outbox,
    retryAutomatically: timer,
    retryInterval: const Duration(milliseconds: 20),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_id': 'user-a',
      'jwt_token': 'test',
    });
    ble = FakeBle();
    outbox = MemoryOutbox();
    requests = [];
    backendFails = false;
    response = {'status': 'ok', 'session_id': 'stored-id', 'feedback': 'saved'};
  });
  tearDown(() async {
    service.dispose();
    await until(() => ble.active == 0);
    ble.dispose();
  });

  test('connected before creation starts a listener immediately', () async {
    ble.setConnection(BleConnectionState.connected);
    service = create();
    expect(ble.active, 1);
    ble.source.add(jsonEncode(packet()));
    await until(() => ble.acks == 1);
    expect(requests, hasLength(1));
  });

  test(
    'connected after creation and repeated connected emit only one listener',
    () async {
      service = create();
      expect(ble.active, 0);
      for (var i = 0; i < 10; i++) {
        ble.setConnection(BleConnectionState.connected);
      }
      expect(ble.active, 1);
      expect(ble.starts, 1);
      ble.source.add(jsonEncode(packet()));
      await until(() => ble.acks == 1);
      expect(ble.maximum, 1);
    },
  );

  for (final completed in [true, false]) {
    test(
      'completed=$completed parses all firmware fields and posts correct payload',
      () async {
        service = create();
        ble.setConnection(BleConnectionState.connected);
        final raw = packet(completed: completed);
        final model = PomodoroSessionData.fromJson(raw);
        expect(model.completed, completed);
        expect(model.workMin, 25);
        expect(model.breakMin, 5);
        expect(model.pauses, 2);
        expect(model.sessionId, raw['session_id']);
        expect(model.startTime, raw['start_time']);
        expect(model.endTime, raw['end_time']);
        expect(model.temperature, 28);
        expect(model.taskType, 'Coding');
        ble.source.add(jsonEncode(raw));
        await until(() => ble.acks == 1);
        expect(requests.single['user_id'], 'user-a');
        expect(requests.single['hardware_data'], {
          'work_min': 25,
          'break_min': 5,
          'pauses': 2,
          'completed': completed,
          'session_count': 1,
          'start_time': raw['start_time'],
          'end_time': raw['end_time'],
          'temperature': 28,
        });
        expect(requests.single['phone_data']['task_type'], 'Coding');
        actualPayloads.add(requests.single);
        expect(outbox.committed, isEmpty);
      },
    );
  }

  test(
    'duplicate while backend pending does not race; persisted duplicate re-ACKs',
    () async {
      final pending = Completer<dynamic>();
      service = SppService(
        ble,
        outbox: outbox,
        retryAutomatically: false,
        post: (path, payload) {
          requests.add(payload);
          return pending.future;
        },
      );
      ble.setConnection(BleConnectionState.connected);
      ble.source.add(jsonEncode(packet()));
      await until(() => requests.length == 1);
      ble.source.add(jsonEncode(packet()));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ble.acks, 0);
      expect(requests, hasLength(1));
      pending.complete(response);
      await until(() => ble.acks == 1);
      ble.source.add(jsonEncode(packet()));
      await until(() => ble.acks == 2);
      expect(requests, hasLength(1));
    },
  );

  test(
    'backend fail, durable queue success ACKs and retry preserves exact payload',
    () async {
      backendFails = true;
      service = create();
      service.currentRecommendationId = 'recommendation-1';
      ble.setConnection(BleConnectionState.connected);
      ble.source.add(jsonEncode(packet(completed: false)));
      await until(() => ble.acks == 1);
      expect(outbox.committed, hasLength(1));
      final saved = jsonDecode(outbox.committed.single);
      expect(saved, requests.single);
      expect(saved['hardware_data']['completed'], false);
      ble.source.add(jsonEncode(packet(completed: false)));
      await until(() => ble.acks == 2);
      expect(requests, hasLength(1));
      await service.retryPendingSessions();
      expect(outbox.committed, hasLength(1));
      backendFails = false;
      await service.retryPendingSessions();
      expect(requests.last, saved);
      expect(outbox.committed, isEmpty);
    },
  );

  for (final failure in ['false', 'throw', 'uncommitted']) {
    test(
      'backend fail and queue $failure does not ACK or mark processed',
      () async {
        backendFails = true;
        outbox.failWrites = failure == 'false';
        outbox.throwWrites = failure == 'throw';
        outbox.pretendSuccess = failure == 'uncommitted';
        service = create();
        ble.setConnection(BleConnectionState.connected);
        ble.source.add(jsonEncode(packet()));
        await until(() => outbox.writes == 1 && !service.isSyncing);
        expect(ble.acks, 0);
        backendFails = false;
        ble.source.add(jsonEncode(packet()));
        await until(() => ble.acks == 1);
        expect(requests, hasLength(2));
      },
    );
  }

  test(
    'disconnect/reconnect cancels old listener before starting new listener',
    () async {
      service = create();
      ble.setConnection(BleConnectionState.connected);
      ble.setConnection(BleConnectionState.disconnected);
      ble.setConnection(BleConnectionState.connected);
      await until(() => ble.starts == 2);
      expect(ble.maximum, 1);
      expect(ble.active, 1);
      ble.source.add(jsonEncode(packet()));
      await until(() => ble.acks == 1);
      expect(requests, hasLength(1));
      // These counters measure subscriptions, not just notification count.
      debugPrint(
        'listener evidence: starts=${ble.starts}, active=${ble.active}, max=${ble.maximum}',
      );
    },
  );

  test('stream error is handled and next valid event is processed', () async {
    service = create();
    ble.setConnection(BleConnectionState.connected);
    ble.source.addError(StateError('radio error'));
    ble.source.add(jsonEncode(packet()));
    await until(() => ble.acks == 1);
    expect(ble.starts, 1);
  });

  test(
    'stream done releases subscription without an infinite resubscribe loop',
    () async {
      service = create();
      ble.setConnection(BleConnectionState.connected);
      await ble.source.close();
      await until(() => ble.active == 0);
      expect(ble.starts, 1);
    },
  );

  test('disposal removes BLE listener and cancels data subscription', () async {
    final disposed = create();
    ble.setConnection(BleConnectionState.connected);
    disposed.dispose();
    await until(() => ble.active == 0);
    ble.setConnection(BleConnectionState.disconnected);
    ble.setConnection(BleConnectionState.connected);
    expect(ble.starts, 1);
    // A fresh instance demonstrates simulated Hot Restart recovery.
    service = create();
    expect(ble.starts, 2);
  });

  test(
    'restart retries saved queue even without BLE or a new session',
    () async {
      backendFails = true;
      final old = create();
      ble.setConnection(BleConnectionState.connected);
      ble.source.add(jsonEncode(packet()));
      await until(() => ble.acks == 1);
      old.dispose();
      await until(() => ble.active == 0);
      ble.setConnection(BleConnectionState.disconnected);
      backendFails = false;
      service = create();
      await until(() => outbox.committed.isEmpty);
      expect(requests, hasLength(2));
      expect(ble.active, 0);
    },
  );

  test('periodic retry recovers Wi-Fi without a BLE reconnect', () async {
    backendFails = true;
    service = create(timer: true);
    ble.setConnection(BleConnectionState.connected);
    ble.source.add(jsonEncode(packet()));
    await until(() => ble.acks == 1);
    backendFails = false;
    await until(() => outbox.committed.isEmpty);
    expect(ble.starts, 1);
  });

  test(
    'queue is retained if backend responds without persistence confirmation',
    () async {
      backendFails = true;
      service = create();
      ble.setConnection(BleConnectionState.connected);
      ble.source.add(jsonEncode(packet()));
      await until(() => ble.acks == 1);
      backendFails = false;
      response = {'status': 'error'};
      await service.retryPendingSessions();
      expect(outbox.committed, hasLength(1));
    },
  );

  test(
    'queued user-a data is not submitted using user-b credentials',
    () async {
      backendFails = true;
      service = create();
      ble.setConnection(BleConnectionState.connected);
      ble.source.add(jsonEncode(packet()));
      await until(() => ble.acks == 1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', 'user-b');
      backendFails = false;
      await service.retryPendingSessions();
      expect(requests, hasLength(1));
      expect(outbox.committed, hasLength(1));
    },
  );

  test(
    'file outbox survives new instance and ignores unfinished staging file',
    () async {
      service = create();
      final directory = await Directory.systemTemp.createTemp('pomodoro-test-');
      try {
        final disk = PomodoroOutbox(directory: () async => directory);
        expect(await disk.write(['one']), true);
        await File(
          '${directory.path}/pomodoro_outbox.json.tmp',
        ).writeAsString('partial');
        final restarted = PomodoroOutbox(directory: () async => directory);
        expect(await restarted.read(), ['one']);
        expect(await restarted.write(['two']), true);
        expect(await disk.read(), ['two']);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'eager provider creates SppService without screen reading it; routes retain it',
    (tester) async {
      var creations = 0;
      service = create();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BleService>.value(value: ble),
            ChangeNotifierProxyProvider<BleService, SppService>(
              create: (_) {
                creations++;
                return service;
              },
              update: (_, _, previous) => previous!,
              lazy: false,
              // Owned by test teardown; route changes must not dispose it.
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('second route')),
                  ),
                ),
                child: const Text('navigate'),
              ),
            ),
          ),
        ),
      );
      expect(creations, 1);
      await tester.tap(find.text('navigate'));
      await tester.pumpAndSettle();
      expect(creations, 1);
      // Provider owns the first instance. Avoid double disposal in tearDown.
      await tester.pumpWidget(const SizedBox());
      service = create();
    },
  );
}
