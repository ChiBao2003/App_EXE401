import 'dart:convert';
import 'package:eink_clock/core/bluetooth/ble_json_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<int>> fragment(String json, int mtu, {int sequence = 1}) {
  final bytes = utf8.encode(json);
  final capacity = (mtu - 7).clamp(1, 180);
  final count = (bytes.length + capacity - 1) ~/ capacity;
  return List.generate(
    count,
    (i) => [
      0x1e,
      sequence,
      i,
      count,
      ...bytes.sublist(
        i * capacity,
        ((i + 1) * capacity).clamp(0, bytes.length),
      ),
    ],
  );
}

void main() {
  final payload = jsonEncode({
    'mode': 'pomodoro',
    'session_id': 'pomo_abcdef012345_123',
    'task_type': 'Học "Dart" – đọc sách',
    'completed': false,
    'work_min': 25,
    'break_min': 5,
    'pauses': 2,
    'session': 1,
    'start_time': '2026-10-19T12:00:00',
    'end_time': '2026-10-19T12:12:00',
    'temperature': 28,
  });

  test('existing firmware single JSON notification remains compatible', () {
    expect(BleJsonAssembler().add(utf8.encode(payload)), payload);
  });
  for (final mtu in [23, 185, 247, 517]) {
    test(
      'MTU $mtu joins UTF-8 fragments and emits exactly one complete JSON',
      () {
        final assembler = BleJsonAssembler();
        final output = <String>[];
        for (final part in fragment(payload, mtu)) {
          expect(part.length, lessThanOrEqualTo(mtu - 3));
          final result = assembler.add(part);
          if (result != null) output.add(result);
        }
        expect(output, [payload]);
        expect(jsonDecode(output.single)['completed'], false);
      },
    );
  }
  test('lost fragment emits no partial JSON; complete retry succeeds', () {
    final assembler = BleJsonAssembler();
    final parts = fragment(payload, 23);
    for (var i = 0; i < parts.length; i++) {
      if (i != 1) expect(assembler.add(parts[i]), isNull);
    }
    final retry = fragment(payload, 23, sequence: 2);
    String? result;
    for (final part in retry) {
      result = assembler.add(part);
    }
    expect(result, payload);
  });
  test('disconnect reset discards unfinished transfer', () {
    final assembler = BleJsonAssembler();
    final parts = fragment(payload, 185);
    assembler.add(parts.first);
    assembler.reset();
    for (final part in parts.skip(1)) {
      expect(assembler.add(part), isNull);
    }
  });
}
