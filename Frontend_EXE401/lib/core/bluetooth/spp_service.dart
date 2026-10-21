import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_config.dart';
import '../api/api_client.dart';
import '../usage_tracking/usage_tracker_service.dart';
import 'ble_service.dart';
import 'pomodoro_outbox.dart';
import '../display/tft_layout.dart';

int _bitmapCrc16(String hex) {
  var crc = 0xffff;
  for (var i = 0; i < hex.length; i += 2) {
    crc ^= int.parse(hex.substring(i, i + 2), radix: 16) << 8;
    for (var bit = 0; bit < 8; bit++) {
      crc = ((crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1) & 0xffff;
    }
  }
  return crc;
}

/// Trạng thái kết nối SPP (giữ tên để không sửa UI)
enum SppState { disconnected, scanning, connecting, connected }

/// Model dữ liệu nhận từ ESP32
class PomodoroSessionData {
  final String sessionId; // Định danh phiên ổn định (pomo_... từ ESP32)
  final int workMin;
  final int breakMin;
  final int pauses;
  final bool completed;
  final int session;
  final DateTime receivedAt;
  final String? startTime; // Thời gian bắt đầu từ RTC DS3231
  final String? endTime; // Thời gian kết thúc từ RTC DS3231
  final int? temperature; // Nhiệt độ từ DS3231
  final String
  taskType; // Loại công việc từ ESP32 (Coding/Reading/Study/General)

  PomodoroSessionData({
    required this.sessionId,
    required this.workMin,
    required this.breakMin,
    required this.pauses,
    required this.completed,
    required this.session,
    required this.receivedAt,
    this.startTime,
    this.endTime,
    this.temperature,
    this.taskType = 'general',
  });

  factory PomodoroSessionData.fromJson(Map<String, dynamic> json) {
    final startTime = json['start_time'];
    final sessionNum = json['session'] ?? 0;
    final fallbackId =
        'pomo_${startTime ?? json['end_time'] ?? 'hw'}_$sessionNum';
    final sid = json['session_id'] as String? ?? fallbackId;
    if (sid.isEmpty ||
        (json['session_id'] == null &&
            startTime == null &&
            json['end_time'] == null)) {
      throw const FormatException('Pomodoro needs a stable session identifier');
    }

    return PomodoroSessionData(
      sessionId: sid,
      workMin: json['work_min'] ?? 25,
      breakMin: json['break_min'] ?? 5,
      pauses: json['pauses'] ?? 0,
      completed: json['completed'] ?? false,
      session: sessionNum,
      receivedAt:
          DateTime.tryParse(json['received_at'] as String? ?? '') ??
          DateTime.now(),
      startTime: startTime,
      endTime: json['end_time'],
      temperature: json['temperature'],
      taskType: json['task_type'] ?? 'general',
    );
  }
}

/// SppService — Wrapper sử dụng BleService bên trong.
/// Giao diện bên ngoài giữ nguyên để không cần sửa pomodoro_screen.dart.
class SppService extends ChangeNotifier {
  final BleService _ble;
  final Future<dynamic> Function(String, Map<String, dynamic>) _post;
  final Future<SharedPreferences> Function() _getPrefs;
  final PomodoroOutbox _outbox;
  StreamSubscription<String>? _dataSubscription;
  Future<void>? _listenerCancellation;
  Timer? _retryTimer;
  bool _disposed = false;
  bool _flushing = false;
  Future<void> _queueMutation = Future.value();
  final Set<String> _inFlightSessionIds = {};
  final Map<String, Completer<Map<String, dynamic>>> _pendingAcks = {};
  Future<void> _hardwareOperation = Future.value();
  int _requestSequence = 0;
  Map<String, dynamic>? displayState;
  Map<String, dynamic>? hardwarePomodoro;

  SppState _state = SppState.disconnected;
  String _statusMessage = 'Chưa kết nối';
  PomodoroSessionData? _lastSession;
  String _lastFeedback = '';
  bool _isSyncing = false;

  /// Tập hợp lưu các session_id đã nhận để chống xử lý trùng lặp khi ESP32 re-transmit
  final Set<String> _processedSessionIds = {};

  /// The recommendation ID from the AI Coach that initiated the current Pomodoro
  String? currentRecommendationId;
  String currentTaskType = 'general';

  // ─── Getters ──────────────────────────────────────────────────
  SppState get state => _state;
  bool get isConnected => _state == SppState.connected;
  bool get isScanning => _state == SppState.scanning;
  String get statusMessage => _statusMessage;
  PomodoroSessionData? get lastSession => _lastSession;
  String get lastFeedback => _lastFeedback;
  bool get isSyncing => _isSyncing;

  SppService(
    this._ble, {
    Future<dynamic> Function(String, Map<String, dynamic>)? post,
    Future<SharedPreferences> Function()? getPrefs,
    PomodoroOutbox? outbox,
    bool retryAutomatically = true,
    Duration retryInterval = const Duration(seconds: 30),
  }) : _post = post ?? ApiClient.post,
       _getPrefs = getPrefs ?? SharedPreferences.getInstance,
       _outbox = outbox ?? PomodoroOutbox() {
    // Đồng bộ trạng thái BLE → SppState
    _ble.addListener(_onBleStateChanged);
    _onBleStateChanged();
    unawaited(_flushOfflineQueue());
    if (retryAutomatically) {
      _retryTimer = Timer.periodic(retryInterval, (_) {
        unawaited(_flushOfflineQueue());
      });
    }
  }

  void _onBleStateChanged() {
    if (_disposed) return;
    if (_ble.state != BleConnectionState.connected) _cancelDataListener();
    switch (_ble.state) {
      case BleConnectionState.disconnected:
        displayState = null;
        hardwarePomodoro = null;
        for (final pending in _pendingAcks.values) {
          if (!pending.isCompleted) {
            pending.complete({'ok': false, 'error': 'BLE disconnected'});
          }
        }
        _setStatus(SppState.disconnected, 'Chưa kết nối');
        break;
      case BleConnectionState.scanning:
        _setStatus(SppState.scanning, 'Đang tìm ESP32_Pomodoro_Data...');
        break;
      case BleConnectionState.connecting:
        _setStatus(SppState.connecting, 'Đang kết nối...');
        break;
      case BleConnectionState.connected:
        _setStatus(
          SppState.connected,
          'Đã kết nối: ${_ble.device?.platformName ?? "ESP32"}',
        );
        if (_dataSubscription == null && _listenerCancellation == null) {
          _listenToData();
          unawaited(
            _syncTime().catchError((Object e) {
              debugPrint('[SppService] Sync time failed: $e');
            }),
          );
          unawaited(_flushOfflineQueue());
          unawaited(
            syncPendingAlarms().catchError((Object e) {
              debugPrint('[SppService] Alarm sync pending: $e');
            }),
          );
          unawaited(
            refreshDisplayState().catchError((Object e) {
              debugPrint('[SppService] Display state unavailable: $e');
            }),
          );
        }
        break;
    }
  }

  void _cancelDataListener() {
    final subscription = _dataSubscription;
    if (subscription == null) return;
    _dataSubscription = null;
    _listenerCancellation = subscription
        .cancel()
        .catchError((Object e) {
          debugPrint('[SppService] BLE listener cancellation failed: $e');
        })
        .whenComplete(() {
          _listenerCancellation = null;
          debugPrint('[SppService] BLE data listener stopped');
          if (!_disposed && _ble.isConnected) _onBleStateChanged();
        });
  }

  // ─── Connect / Disconnect ─────────────────────────────────────
  Future<void> connectToEsp32() async {
    if (_state != SppState.disconnected) return;
    await _ble.startScan();
  }

  Future<void> disconnect() async {
    await _ble.disconnect();
  }

  // ─── Nhận dữ liệu từ ESP32 ───────────────────────────────────
  void _listenToData() {
    if (_dataSubscription != null) return;
    _dataSubscription = _ble.dataStream.listen(
      (jsonStr) => unawaited(_handleJsonPayload(jsonStr)),
      onError: (Object error, StackTrace stack) {
        debugPrint('[SppService] BLE data error: $error');
      },
      onDone: () {
        _dataSubscription = null;
        debugPrint('[SppService] BLE data stream closed');
      },
    );
    debugPrint('[SppService] BLE data listener started');
  }

  Future<void> _sendPomoAck(String sessionId) async {
    if (_disposed) return;
    try {
      await sendJsonCommand('ACK_POMO', {
        'session_id': sessionId,
        'status': 'received',
      });
      debugPrint('[SppService] ACK_POMO sent: $sessionId');
    } catch (e) {
      // ESP32 retransmits after its ACK timeout.
      debugPrint('[SppService] ACK_POMO failed: $e');
    }
  }

  Future<void> _handleJsonPayload(String jsonStr) async {
    if (_disposed) return;
    PomodoroSessionData session;
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final rid = data['rid'];
      if (rid is String &&
          _pendingAcks[rid] != null &&
          !_pendingAcks[rid]!.isCompleted) {
        _pendingAcks[rid]!.complete(data);
      }
      if (data['type'] == 'pomo_state' && data['ok'] != false) {
        hardwarePomodoro = data;
        if (!_disposed) notifyListeners();
      }
      if (data['mode'] != 'pomodoro') return;
      session = PomodoroSessionData.fromJson(data);
    } catch (e) {
      debugPrint('[SppService] Invalid Pomodoro JSON: $e');
      return;
    }

    final sid = session.sessionId;
    if (_inFlightSessionIds.contains(sid)) return;
    _inFlightSessionIds.add(sid);
    try {
      if (_processedSessionIds.contains(sid) || await _isQueued(sid)) {
        await _sendPomoAck(sid);
        return;
      }
      _lastSession = session;
      if (!_disposed) notifyListeners();
      final persisted = await _syncToBackend(session);
      if (!persisted) return;
      await _sendPomoAck(sid);
    } catch (e) {
      debugPrint('[SppService] Pomodoro processing failed: $e');
    } finally {
      _inFlightSessionIds.remove(sid);
    }
  }

  Future<T> _withQueueLock<T>(Future<T> Function() operation) async {
    final prior = _queueMutation;
    final done = Completer<void>();
    _queueMutation = done.future;
    await prior;
    try {
      return await operation();
    } finally {
      done.complete();
    }
  }

  bool _queueContains(List<String> queue, String sid) {
    for (final item in queue) {
      try {
        final stored = jsonDecode(item) as Map<String, dynamic>;
        if (stored['session_id'] == sid &&
            stored['hardware_data'] is Map &&
            stored['phone_data'] is Map &&
            stored['user_id'] is String) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> _isQueued(String sid) => _withQueueLock(() async {
    try {
      return _queueContains(await _outbox.read(), sid);
    } catch (e) {
      debugPrint('[SppService] Outbox read failed: $e');
      return false; // Backend can still persist this retransmission.
    }
  });

  void _rememberBackendSession(String sid) {
    _processedSessionIds.add(sid);
    if (_processedSessionIds.length > 50) {
      _processedSessionIds.remove(_processedSessionIds.first);
    }
  }

  Map<String, dynamic> _makePayload(
    PomodoroSessionData session,
    String userId,
    int unlockCount,
    String? recommendationId,
  ) {
    final end = session.endTime ?? session.receivedAt.toIso8601String();
    final start =
        session.startTime ??
        session.receivedAt
            .subtract(Duration(minutes: session.workMin))
            .toIso8601String();
    return {
      'user_id': userId,
      'session_id': session.sessionId,
      'hardware_data': {
        'work_min': session.workMin,
        'break_min': session.breakMin,
        'pauses': session.pauses,
        'completed': session.completed,
        'session_count': session.session,
        'start_time': start,
        'end_time': end,
        'temperature': session.temperature,
      },
      'phone_data': {
        'unlock_count': unlockCount,
        'task_type': session.taskType,
        'recommendation_id': recommendationId,
        'timestamp': session.receivedAt.toIso8601String(),
      },
    };
  }

  Future<bool> _syncToBackend(PomodoroSessionData session) async {
    _isSyncing = true;
    if (!_disposed) notifyListeners();
    try {
      final prefs = await _getPrefs();
      final userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) {
        throw StateError('Đăng nhập để nhận phiên Pomodoro');
      }
      var unlockCount = (session.pauses * 1.5).round();
      try {
        final tracker = UsageTrackerService();
        if (await tracker.hasPermission()) {
          final start =
              DateTime.tryParse(session.startTime ?? '') ??
              session.receivedAt.subtract(Duration(minutes: session.workMin));
          final end =
              DateTime.tryParse(session.endTime ?? '') ?? session.receivedAt;
          final distractions = await tracker.detectDistractions(
            pomodoroSessionId: session.sessionId,
            pomoStartTime: start,
            pomoEndTime: end,
          );
          if (distractions.isNotEmpty) {
            unlockCount = distractions.length;
            await tracker.syncDistractionEvents(distractions);
          }
        }
      } catch (e) {
        debugPrint('[SppService] Usage tracking unavailable: $e');
      }

      final payload = _makePayload(
        session,
        userId,
        unlockCount,
        currentRecommendationId,
      );
      try {
        final response = await _post('/api/v1/pomodoro/sync', payload);
        if (response is! Map || response['status'] != 'ok') {
          throw StateError('Backend did not confirm Pomodoro persistence');
        }
        _lastFeedback =
            response['feedback']?.toString() ?? 'Phiên đã được ghi nhận!';
        currentRecommendationId = null;
        currentTaskType = 'general';
        _rememberBackendSession(session.sessionId);
        return true;
      } catch (e) {
        final queued = await _queueOfflinePayload(payload);
        if (queued) {
          currentRecommendationId = null;
          currentTaskType = 'general';
        }
        _lastFeedback = queued
            ? 'Đã lưu tạm phiên Pomodoro để tự đồng bộ lại.'
            : 'Không gửi được Pomodoro và không lưu được offline: $e';
        return queued;
      }
    } catch (e) {
      _lastFeedback = 'Không thể xử lý phiên Pomodoro: $e';
      return false;
    } finally {
      _isSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> _queueOfflinePayload(Map<String, dynamic> payload) =>
      _withQueueLock(() async {
        try {
          final sid = payload['session_id'] as String;
          final queue = await _outbox.read();
          if (_queueContains(queue, sid)) return true;
          queue.add(jsonEncode(payload));
          if (!await _outbox.write(queue)) return false;
          // Never ACK based solely on a successful method return.
          return _queueContains(await _outbox.read(), sid);
        } catch (e) {
          debugPrint('[SppService] Offline queue save failed: $e');
          return false;
        }
      });

  Future<void> _flushOfflineQueue() async {
    if (_flushing || _disposed) return;
    _flushing = true;
    try {
      final prefs = await _getPrefs();
      final userId = prefs.getString('user_id');
      if (userId == null || userId.isEmpty) return;
      final snapshot = await _withQueueLock(() async {
        final queue = await _outbox.read();
        final legacy = prefs.getStringList('offline_pomo_queue') ?? [];
        if (legacy.isNotEmpty) {
          for (final item in legacy) {
            if (!queue.contains(item)) queue.add(item);
          }
          if (!await _outbox.write(queue)) {
            throw StateError('Cannot migrate legacy Pomodoro queue');
          }
          // Only remove the old queue after the durable snapshot is committed.
          await prefs.remove('offline_pomo_queue');
        }
        return queue;
      });
      for (final item in snapshot) {
        if (_disposed) break;
        try {
          final stored = jsonDecode(item) as Map<String, dynamic>;
          Map<String, dynamic> payload;
          if (stored.containsKey('hardware_data')) {
            payload = stored;
            // FastAPI uses the JWT owner, not payload.user_id.
            if (payload['user_id'] != userId) continue;
          } else {
            // Read existing queues written by previous app versions.
            final session = PomodoroSessionData.fromJson(stored);
            payload = _makePayload(
              session,
              userId,
              (session.pauses * 1.5).round(),
              null,
            );
          }
          final response = await _post('/api/v1/pomodoro/sync', payload);
          if (response is! Map || response['status'] != 'ok') continue;
          _rememberBackendSession(payload['session_id'] as String);
          await _withQueueLock(() async {
            final current = await _outbox.read();
            current.remove(item);
            if (!await _outbox.write(current)) {
              debugPrint('[SppService] Could not remove synced queue item');
            }
          });
        } catch (e) {
          debugPrint('[SppService] Offline queue retry failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[SppService] Offline queue read failed: $e');
    } finally {
      _flushing = false;
    }
  }

  @visibleForTesting
  Future<void> retryPendingSessions() => _flushOfflineQueue();

  // ─── Gửi lệnh xuống ESP32 ────────────────────────────────────
  Future<void> sendJsonCommand(String cmd, Map<String, dynamic> params) async {
    if (!await _ble.sendJson({'cmd': cmd, 'params': params})) {
      throw StateError('Không gửi được lệnh $cmd qua BLE');
    }
  }

  Future<T> _serialHardware<T>(Future<T> Function() action) async {
    final previous = _hardwareOperation;
    final done = Completer<void>();
    _hardwareOperation = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }

  Future<Map<String, dynamic>> _confirmed(
    String command,
    Map<String, dynamic> params,
    String type, {
    Map<String, dynamic> root = const {},
  }) async {
    if (_disposed || !isConnected) throw StateError('Chưa kết nối đồng hồ');
    final rid =
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${++_requestSequence}';
    final pending = Completer<Map<String, dynamic>>();
    _pendingAcks[rid] = pending;
    try {
      if (!await _ble.sendJson({
        'cmd': command,
        'rid': rid,
        'params': params,
        ...root,
      })) {
        throw StateError('Không gửi được $command');
      }
      final ack = await pending.future.timeout(const Duration(seconds: 6));
      if (ack['type'] != type) {
        throw StateError('Phản hồi $command sai loại ACK: ${ack['type']}');
      }
      if (ack['ok'] != true) {
        final reason = ack['error'];
        final detail = reason is String && reason.isNotEmpty
            ? reason
            : command == 'LAYOUT_BG_COMMIT' || command == 'LAYOUT_BITMAP_COMMIT'
            ? 'ESP32 từ chối lưu ảnh vào flash. Firmware cũ có thể không đủ chỗ NVS; hãy cập nhật firmware hỗ trợ LittleFS.'
            : 'Thiết bị không gửi lý do lỗi';
        throw StateError('Đồng hồ từ chối $command: $detail');
      }
      return ack;
    } finally {
      _pendingAcks.remove(rid);
    }
  }

  Future<void> refreshDisplayState() => _serialHardware(() async {
    displayState = await _confirmed('GET_DISPLAY_STATE', {}, 'display_state');
    if (!_disposed) notifyListeners();
  });

  /// Progress advances only after each firmware acknowledgement.
  Future<void> uploadTftLayout(
    List<Map<String, dynamic>> items, {
    int refreshSeconds = 60,
    int backgroundColor = 0,
    String? backgroundBitmapHex,
    void Function(int completed, int total)? onProgress,
  }) => _serialHardware(() async {
    if (!isConnected) throw StateError('Chưa kết nối đồng hồ');
    if ((items.isEmpty && backgroundBitmapHex == null) || items.length > 12) {
      throw ArgumentError('Thiết kế cần từ 1 đến 12 phần tử');
    }

    final normalized = items.map(normalizeTftItem).toList();
    if (backgroundBitmapHex != null &&
        (backgroundBitmapHex.length != 19200 ||
            !RegExp(r'^[0-9a-fA-F]+$').hasMatch(backgroundBitmapHex))) {
      throw const FormatException('Ảnh nền phải là bitmap 320×240 MSB-first');
    }
    final backgroundPackets = backgroundBitmapHex == null ? 0 : 77;
    final bitmapPackets = normalized.fold<int>(
      0,
      (sum, item) =>
          sum +
          (item['t'] == 'bitmap' && (item['v'] as String).length > 256
              ? 2 + ((item['v'] as String).length + 255) ~/ 256
              : 0),
    );
    final total = items.length + 2 + backgroundPackets + bitmapPackets;
    var completed = 0;
    onProgress?.call(0, total);
    if (backgroundBitmapHex != null) {
      await _confirmed('LAYOUT_BG_BEGIN', {
        'bytes': 9600,
        'crc': _bitmapCrc16(backgroundBitmapHex),
      }, 'layout_bg_ack');
      onProgress?.call(++completed, total);
      for (var i = 0; i < 75; i++) {
        final ack = await _confirmed('LAYOUT_BG_CHUNK', {
          'n': i,
          'v': backgroundBitmapHex.substring(i * 256, (i + 1) * 256),
          'crc': _bitmapCrc16(
            backgroundBitmapHex.substring(i * 256, (i + 1) * 256),
          ),
        }, 'layout_bg_ack');
        if (ack['index'] != i) throw StateError('Sai thứ tự ACK ảnh nền');
        onProgress?.call(++completed, total);
      }
      await _confirmed('LAYOUT_BG_COMMIT', {'bytes': 9600}, 'layout_bg_ack');
      onProgress?.call(++completed, total);
    }
    await _confirmed('LAYOUT_BEGIN', {
      'refresh': refreshSeconds,
      'background': backgroundColor,
      'bitmap_bg': backgroundBitmapHex != null,
    }, 'layout_ack');
    onProgress?.call(++completed, total);
    for (var i = 0; i < normalized.length; i++) {
      final item = Map<String, dynamic>.of(normalized[i]);
      if (item['t'] == 'bitmap' && (item['v'] as String).length > 256) {
        final hex = item['v'] as String;
        final bytes = hex.length ~/ 2;
        await _confirmed('LAYOUT_BITMAP_BEGIN', {
          'n': i,
          'bytes': bytes,
          'crc': _bitmapCrc16(hex),
        }, 'layout_bitmap_ack');
        onProgress?.call(++completed, total);
        final packets = (hex.length + 255) ~/ 256;
        for (var packet = 0; packet < packets; packet++) {
          final part = hex.substring(
            packet * 256,
            (packet + 1) * 256 > hex.length ? hex.length : (packet + 1) * 256,
          );
          final ack = await _confirmed('LAYOUT_BITMAP_CHUNK', {
            'n': i,
            'chunk': packet,
            'v': part,
            'crc': _bitmapCrc16(part),
          }, 'layout_bitmap_ack');
          if (ack['index'] != packet) throw StateError('ACK bitmap sai thứ tự');
          onProgress?.call(++completed, total);
        }
        await _confirmed('LAYOUT_BITMAP_COMMIT', {
          'n': i,
          'bytes': bytes,
        }, 'layout_bitmap_ack');
        onProgress?.call(++completed, total);
        item['v'] = '';
        item['chunked'] = true;
        item['bytes'] = bytes;
      }
      final ack = await _confirmed('LAYOUT_ITEM', {
        'n': i,
        ...item,
      }, 'layout_ack');
      if (ack['index'] != i) throw StateError('Sai thứ tự ACK phần tử');
      onProgress?.call(++completed, total);
    }
    await _confirmed('LAYOUT_COMMIT', {
      'count': normalized.length,
    }, 'layout_ack');
    onProgress?.call(total, total);
    displayState = await _confirmed('GET_DISPLAY_STATE', {}, 'display_state');
    if (!_disposed) notifyListeners();
  });

  Future<void> syncSchedule(
    String day,
    List<Map<String, dynamic>> items,
  ) => _serialHardware(() async {
    if (!['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].contains(day) ||
        items.length > 16) {
      throw ArgumentError('Ngày không hợp lệ hoặc quá 16 lịch/ngày');
    }
    final normalized = items.map((item) {
      final hour = item['hour'] as int, minute = item['minute'] as int;
      final label = lcdText(item['label'] as String);
      if (hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59 ||
          label.length > 48) {
        throw const FormatException(
          'Giờ/phút hoặc nhãn lịch không hợp lệ (tối đa 48 ký tự)',
        );
      }
      return <String, dynamic>{'hour': hour, 'minute': minute, 'label': label};
    }).toList();
    final params = <String, dynamic>{'day': day, 'items': normalized};
    Map<String, dynamic> ack;
    // Reserve space for cmd/rid/params while retaining compatibility with root fields.
    if (utf8.encode(jsonEncode(params)).length * 2 + 100 <= 512) {
      ack = await _confirmed(
        'SYNC_SCHEDULE',
        params,
        'schedule_ack',
        root: params,
      );
    } else {
      await _confirmed('SCHEDULE_BEGIN', {'day': day}, 'schedule_ack');
      for (var i = 0; i < normalized.length; i++) {
        await _confirmed('SCHEDULE_ITEM', {
          'day': day,
          'n': i,
          ...normalized[i],
        }, 'schedule_ack');
      }
      ack = await _confirmed('SCHEDULE_COMMIT', {
        'day': day,
        'count': normalized.length,
      }, 'schedule_ack');
    }
    if (ack['day'] != day || ack['count'] != normalized.length) {
      throw StateError('ACK lịch không khớp ngày/số mục');
    }
    final prefs = await _getPrefs();
    await prefs.setString('tft_schedule_$day', jsonEncode(normalized));
  });

  Future<void> refreshPomodoroState() => _serialHardware(() async {
    hardwarePomodoro = await _confirmed('GET_POMO_STATE', {}, 'pomo_state');
    if (!_disposed) notifyListeners();
  });

  Future<void> controlPomodoro(String action) => _serialHardware(() async {
    hardwarePomodoro = await _confirmed('POMO_CONTROL', {
      'action': action,
    }, 'pomo_state');
    if (!_disposed) notifyListeners();
  });

  Future<void> _syncTime() async {
    final now = DateTime.now();
    await sendJsonCommand('SET_TIME', {
      'year': now.year,
      'month': now.month,
      'day': now.day,
      'hour': now.hour,
      'minute': now.minute,
      'second': now.second,
    });
  }

  Future<void> syncWatchTime() => _syncTime();

  Future<void> syncPendingAlarms() async {
    final prefs = await _getPrefs();
    if (!isConnected || prefs.getBool(alarmsPendingKey) != true) return;
    await syncAlarms(loadWatchAlarms(prefs));
  }

  Future<void> syncAlarms(List<WatchAlarm> alarms) => _serialHardware(() async {
    if (alarms.length > maxWatchAlarms)
      throw const FormatException('Tối đa 8 báo thức');
    for (final alarm in alarms) {
      WatchAlarm.fromJson(alarm.toJson());
    }
    await _confirmed('ALARMS_BEGIN', {'count': alarms.length}, 'alarms_ack');
    for (var i = 0; i < alarms.length; i++) {
      final ack = await _confirmed('ALARMS_ITEM', {
        'n': i,
        ...alarms[i].toJson(),
      }, 'alarms_ack');
      if (ack['index'] != i) throw StateError('ACK báo thức sai thứ tự');
    }
    final ack = await _confirmed('ALARMS_COMMIT', {
      'count': alarms.length,
    }, 'alarms_ack');
    if (ack['count'] != alarms.length)
      throw StateError('ACK báo thức sai số lượng');
    final prefs = await _getPrefs();
    if (!await prefs.setBool(alarmsPendingKey, false)) {
      throw StateError('Không lưu được trạng thái đồng bộ báo thức');
    }
  });

  /// Gửi chu kỳ Pomodoro kèm phân loại công việc (Coding, Reading, Study, General)
  Future<void> sendPomodoroCycle(
    int workMin,
    int breakMin, {
    String taskType = 'General',
  }) => _serialHardware(() async {
    hardwarePomodoro = await _confirmed('SET_POMO', {
      'work_min': workMin,
      'break_min': breakMin,
      'task_type': taskType,
    }, 'pomo_state');
    if (!_disposed) notifyListeners();
  });

  /// Cài đặt báo thức trên ESP32 kèm phân tích giờ/phút
  Future<void> sendAlarm(
    String time,
    String label, {
    bool enabled = true,
    int days = 0x7f,
  }) async {
    int hour = 0;
    int minute = 0;
    if (time.contains(':')) {
      final parts = time.split(':');
      hour = int.tryParse(parts[0].trim()) ?? 0;
      minute = int.tryParse(parts[1].trim()) ?? 0;
    }
    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        days < 1 ||
        days > 0x7f) {
      throw const FormatException('Giờ hoặc ngày lặp lại không hợp lệ');
    }
    final lcdLabel = lcdText(label);
    await sendJsonCommand('SET_ALARM', {
      'time': time,
      'hour': hour,
      'minute': minute,
      'label': lcdLabel.length > 31 ? lcdLabel.substring(0, 31) : lcdLabel,
      'enabled': enabled,
      'days': days,
    });
  }

  /// Đẩy pop-up thông báo hiển thị lên màn hình đồng hồ
  Future<void> sendNotification(String title, String body) async {
    await sendJsonCommand('SHOW_NOTIF', {'title': title, 'body': body});
  }

  /// Đổi chế độ hiển thị trên đồng hồ (0=Clock, 1=Pomodoro, 2=Timer, 3=Bluetooth)
  Future<void> setMode(int modeIndex) => _serialHardware(() async {
    displayState = await _confirmed('SET_MODE', {
      'mode': modeIndex,
    }, 'display_state');
    if (!_disposed) notifyListeners();
  });

  /// Đổi Theme đồng hồ (0=Flip Clock, 1=Analog, 2=Sunset) kèm màu chủ đạo
  Future<void> setTheme(
    int themeId, {
    String hexColor = '00E5FF',
    bool anim = false,
  }) => _serialHardware(() async {
    displayState = await _confirmed('SET_THEME', {
      'theme_id': themeId,
      'color': hexColor,
      'anim': anim,
    }, 'display_state');
    if (!_disposed) notifyListeners();
  });

  /// Điều khiển nghe nhạc qua Bluetooth A2DP ('PLAY', 'PAUSE', 'NEXT', 'PREV')
  Future<void> sendMediaCommand(String action) async {
    await sendJsonCommand('MEDIA_CMD', {'action': action});
  }

  // ─── Helper ───────────────────────────────────────────────────
  void _setStatus(SppState state, String message) {
    _state = state;
    _statusMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final pending in _pendingAcks.values) {
      if (!pending.isCompleted) {
        pending.complete({'ok': false, 'error': 'Disposed'});
      }
    }
    _retryTimer?.cancel();
    _cancelDataListener();
    _ble.removeListener(_onBleStateChanged);
    super.dispose();
  }
}
