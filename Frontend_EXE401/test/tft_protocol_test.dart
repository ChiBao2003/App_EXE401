import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:eink_clock/core/bluetooth/ble_service.dart';
import 'package:eink_clock/core/bluetooth/spp_service.dart';
import 'package:eink_clock/core/display/tft_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AckBle extends BleService {
  final source = StreamController<String>.broadcast();
  final packets = <Map<String, dynamic>>[];
  bool rejectCommit = false;
  bool rejectBackgroundCommit = false;
  @override
  BleConnectionState get state => BleConnectionState.connected;
  @override
  bool get isConnected => true;
  @override
  Stream<String> get dataStream => source.stream;
  @override
  Future<bool> sendJson(Map<String, dynamic> packet) async {
    packets.add(packet);
    if (packet['rid'] == null) return true;
    final cmd = packet['cmd'] as String;
    final params = packet['params'] as Map;
    var type = 'display_state';
    if (cmd.startsWith('LAYOUT_')) type = 'layout_ack';
    if (cmd.startsWith('LAYOUT_BG_')) type = 'layout_bg_ack';
    if (cmd.startsWith('LAYOUT_BITMAP_')) type = 'layout_bitmap_ack';
    if (cmd.contains('SCHEDULE')) type = 'schedule_ack';
    if (cmd.contains('POMO')) type = 'pomo_state';
    source.add(
      jsonEncode({
        'rid': packet['rid'],
        'type': type,
        'ok':
            !((rejectCommit && cmd == 'LAYOUT_COMMIT') ||
                (rejectBackgroundCommit && cmd == 'LAYOUT_BG_COMMIT')),
        'index': cmd == 'LAYOUT_BITMAP_CHUNK' ? params['chunk'] : params['n'],
        'count': params['count'] ?? (params['items'] as List?)?.length,
        'day': params['day'],
        'mode': 0,
        'theme_id': 0,
        'custom': true,
        'layout_count': 1,
      }),
    );
    return true;
  }

  @override
  void stopScan() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AckBle ble;
  late SppService spp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ble = AckBle();
    spp = SppService(ble, retryAutomatically: false);
    await spp.refreshDisplayState();
  });
  tearDown(() async {
    spp.dispose();
    await ble.source.close();
    ble.dispose();
  });
  test(
    'small schedule retains both wire formats and waits for correlated ACK',
    () async {
      await spp.syncSchedule('Mon', [
        {'hour': 8, 'minute': 30, 'label': 'Đọc sách'},
      ]);
      final wire = ble.packets.last;
      expect(wire['cmd'], 'SYNC_SCHEDULE');
      expect(wire['day'], 'Mon');
      expect(wire['items'], (wire['params'] as Map)['items']);
      expect(((wire['items'] as List).single as Map)['label'], 'Doc sach');
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('tft_schedule_Mon')!) as List,
        hasLength(1),
      );
    },
  );
  test('alarm command carries repeat days and LCD-safe label', () async {
    await spp.sendAlarm('06:30', 'Thức dậy', days: 0x1f);
    final wire = ble.packets.last;
    expect(wire['cmd'], 'SET_ALARM');
    final params = wire['params'] as Map;
    expect(params['hour'], 6);
    expect(params['minute'], 30);
    expect(params['days'], 0x1f);
    expect(params['label'], 'Thuc day');
  });
  test(
    'large schedule is staged with every BLE write within 512 bytes',
    () async {
      await spp.syncSchedule(
        'Tue',
        List.generate(16, (i) => {'hour': i, 'minute': 0, 'label': 'x' * 48}),
      );
      final commands = ble.packets.map((p) => p['cmd']).toList();
      expect(commands, contains('SCHEDULE_BEGIN'));
      expect(commands.where((c) => c == 'SCHEDULE_ITEM').length, 16);
      expect(commands.last, 'SCHEDULE_COMMIT');
      for (final p in ble.packets) {
        expect(utf8.encode(jsonEncode(p)).length, lessThanOrEqualTo(512));
      }
    },
  );
  test(
    'upload reports progress only after ACK and rejects failed commit',
    () async {
      final progress = <int>[];
      final items = [
        {'t': 'bitmap', 'v': 'ff' * 128, 'x': 0, 'y': 0, 'w': 32, 'h': 32},
      ];
      await spp.uploadTftLayout(
        items,
        onProgress: (n, total) => progress.add(n),
      );
      expect(progress, [0, 1, 2, 3]);
      for (final p in ble.packets) {
        expect(utf8.encode(jsonEncode(p)).length, lessThanOrEqualTo(512));
      }
      ble.rejectCommit = true;
      await expectLater(spp.uploadTftLayout(items), throwsStateError);
    },
  );
  test(
    'full-screen background uploads in 75 bounded ACK packets before layout',
    () async {
      final background = 'aa' * 9600;
      await spp.uploadTftLayout([
        {'t': 'clock', 'x': 0, 'y': 0, 'w': 120, 'h': 48},
      ], backgroundBitmapHex: background);
      final commands = ble.packets.map((p) => p['cmd']).toList();
      expect(commands.where((c) => c == 'LAYOUT_BG_CHUNK').length, 75);
      expect(
        commands.indexOf('LAYOUT_BG_COMMIT'),
        lessThan(commands.indexOf('LAYOUT_BEGIN')),
      );
      expect(
        (ble.packets.firstWhere((p) => p['cmd'] == 'LAYOUT_BEGIN')['params']
            as Map)['bitmap_bg'],
        true,
      );
      for (final packet in ble.packets.where(
        (p) => p['cmd'] == 'LAYOUT_BG_CHUNK',
      )) {
        expect((packet['params'] as Map)['crc'], isA<int>());
      }
      for (final packet in ble.packets) {
        expect(utf8.encode(jsonEncode(packet)).length, lessThanOrEqualTo(512));
      }
    },
  );
  test('rejected background commit reports device storage failure', () async {
    ble.rejectBackgroundCommit = true;
    await expectLater(
      spp.uploadTftLayout([
        {'t': 'clock', 'x': 0, 'y': 0, 'w': 120, 'h': 48},
      ], backgroundBitmapHex: 'aa' * 9600),
      throwsA(
        isA<StateError>().having(
          (error) => error.message.toString(),
          'message',
          allOf(contains('LAYOUT_BG_COMMIT'), contains('NVS')),
        ),
      ),
    );
    expect(ble.packets.where((p) => p['cmd'] == 'LAYOUT_BEGIN'), isEmpty);
  });
  test(
    'all five bundled faces upload with bounded packets and bitmap ACKs',
    () async {
      for (final name in ['pokemon', 'naruto', 'gojo', 'han_li', 'wang_lin']) {
        ble.packets.clear();
        final file = File('assets/samples/${name}_clock.json');
        final design = validateTftDesign(jsonDecode(file.readAsStringSync()));
        await spp.uploadTftLayout(
          tftTemplateItems(design),
          backgroundColor: design['background'] as int,
        );
        expect(
          ble.packets.where((p) => p['cmd'] == 'LAYOUT_BITMAP_COMMIT').length,
          1,
        );
        expect(ble.packets.where((p) => p['cmd'] == 'LAYOUT_ITEM').length, 10);
        for (final packet in ble.packets) {
          expect(
            utf8.encode(jsonEncode(packet)).length,
            lessThanOrEqualTo(512),
          );
        }
      }
    },
  );
  test(
    'large Poke Ball JSON validates and uploads its white hemisphere',
    () async {
      final design = validateTftDesign(
        jsonDecode(
          File('assets/samples/pokeball_xl_test.json').readAsStringSync(),
        ),
      );
      final items = tftTemplateItems(design);
      expect(design['background'], 0x10a9);
      expect(items.length, 8);
      expect((items[2]['v'] as String).length, 4140);
      await spp.uploadTftLayout(
        items,
        backgroundColor: design['background'] as int,
      );
      expect(
        ble.packets.where((p) => p['cmd'] == 'LAYOUT_BITMAP_CHUNK').length,
        17,
      );
      for (final packet in ble.packets) {
        expect(utf8.encode(jsonEncode(packet)).length, lessThanOrEqualTo(512));
      }
    },
  );
  test(
    'compact landscape replaces 20 shapes with one full-screen bitmap',
    () async {
      final design = validateTftDesign(
        jsonDecode(
          File(
            'assets/samples/pixel_landscape_compact.json',
          ).readAsStringSync(),
        ),
      );
      final items = tftTemplateItems(design);
      expect(items.length, 2);
      await spp.uploadTftLayout(
        items,
        backgroundColor: design['background'] as int,
      );
      expect(
        ble.packets.where((p) => p['cmd'] == 'LAYOUT_BITMAP_CHUNK').length,
        75,
      );
      for (final packet in ble.packets) {
        expect(utf8.encode(jsonEncode(packet)).length, lessThanOrEqualTo(512));
      }
    },
  );
  test(
    'geometry-only landscape uploads without image flash commands',
    () async {
      final design = validateTftDesign(
        jsonDecode(
          File(
            'assets/samples/pixel_landscape_geometry_only.json',
          ).readAsStringSync(),
        ),
      );
      final items = tftTemplateItems(design);
      expect(items.length, lessThanOrEqualTo(12));
      await spp.uploadTftLayout(
        items,
        backgroundColor: design['background'] as int,
      );
      final commands = ble.packets.map((packet) => packet['cmd']).toList();
      expect(
        commands.where((command) => command == 'LAYOUT_ITEM').length,
        items.length,
      );
      expect(
        commands.where(
          (command) => command.toString().startsWith('LAYOUT_BG_'),
        ),
        isEmpty,
      );
      expect(
        commands.where(
          (command) => command.toString().startsWith('LAYOUT_BITMAP_'),
        ),
        isEmpty,
      );
    },
  );
}
