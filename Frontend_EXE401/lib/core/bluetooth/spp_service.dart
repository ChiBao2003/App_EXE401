import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../api/api_client.dart';
import 'ble_service.dart';

/// Trạng thái kết nối SPP (giữ tên để không sửa UI)
enum SppState { disconnected, scanning, connecting, connected }

/// Model dữ liệu nhận từ ESP32
class PomodoroSessionData {
  final int workMin;
  final int breakMin;
  final int pauses;
  final bool completed;
  final int session;
  final DateTime receivedAt;
  final String? startTime;    // Thời gian bắt đầu từ RTC DS3231
  final String? endTime;      // Thời gian kết thúc từ RTC DS3231
  final int? temperature;     // Nhiệt độ từ DS3231
  final String taskType;      // Loại công việc từ ESP32 (Coding/Reading/Study/General)

  PomodoroSessionData({
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
    return PomodoroSessionData(
      workMin:     json['work_min']     ?? 25,
      breakMin:    json['break_min']    ?? 5,
      pauses:      json['pauses']       ?? 0,
      completed:   json['completed']    ?? false,
      session:     json['session']      ?? 0,
      receivedAt:  DateTime.now(),
      startTime:   json['start_time'],
      endTime:     json['end_time'],
      temperature: json['temperature'],
      taskType:    json['task_type']    ?? 'general',
    );
  }
}

/// SppService — Wrapper sử dụng BleService bên trong.
/// Giao diện bên ngoài giữ nguyên để không cần sửa pomodoro_screen.dart.
class SppService extends ChangeNotifier {
  final BleService _ble;
  StreamSubscription? _dataSubscription;

  SppState _state = SppState.disconnected;
  String _statusMessage = 'Chưa kết nối';
  PomodoroSessionData? _lastSession;
  String _lastFeedback = '';
  bool _isSyncing = false;
  
  /// The recommendation ID from the AI Coach that initiated the current Pomodoro
  String? currentRecommendationId;
  String currentTaskType = 'general';

  // ─── Getters ──────────────────────────────────────────────────
  SppState get state          => _state;
  bool get isConnected        => _state == SppState.connected;
  bool get isScanning         => _state == SppState.scanning;
  String get statusMessage    => _statusMessage;
  PomodoroSessionData? get lastSession => _lastSession;
  String get lastFeedback     => _lastFeedback;
  bool get isSyncing          => _isSyncing;
  String get _backendUrl      => AppConstants.baseUrl;

  SppService(this._ble) {
    // Đồng bộ trạng thái BLE → SppState
    _ble.addListener(_onBleStateChanged);
  }

  void _onBleStateChanged() {
    switch (_ble.state) {
      case BleConnectionState.disconnected:
        _setStatus(SppState.disconnected, 'Chưa kết nối');
        _dataSubscription?.cancel();
        break;
      case BleConnectionState.scanning:
        _setStatus(SppState.scanning, 'Đang tìm ESP32_Pomodoro_Data...');
        break;
      case BleConnectionState.connecting:
        _setStatus(SppState.connecting, 'Đang kết nối...');
        break;
      case BleConnectionState.connected:
        _setStatus(SppState.connected, 'Đã kết nối: ${_ble.device?.platformName ?? "ESP32"}');
        _listenToData();
        _syncTime();
        break;
    }
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
    _dataSubscription?.cancel();
    _dataSubscription = _ble.dataStream.listen((jsonStr) {
      _handleJsonPayload(jsonStr);
    });
  }

  Future<void> _handleJsonPayload(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final session = PomodoroSessionData.fromJson(data);
      _lastSession = session;
      notifyListeners();
      debugPrint('[SppService] Nhận từ ESP32: $jsonStr');
      await _syncToBackend(session);
    } catch (e) {
      debugPrint('[SppService] Lỗi parse JSON: $e | raw: $jsonStr');
    }
  }

  // ─── Gửi dữ liệu lên Backend ─────────────────────────────────
  Future<void> _syncToBackend(PomodoroSessionData session) async {
    _isSyncing = true;
    notifyListeners();
    try {
      // Lấy user_id thật từ phiên đăng nhập (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'anonymous';

      // Fallback: Nếu ESP32 chưa có start_time/end_time, tính từ điện thoại
      final fallbackEnd = session.receivedAt.toIso8601String();
      final fallbackStart = session.receivedAt
          .subtract(Duration(minutes: session.workMin)).toIso8601String();

      final payload = {
        'user_id': userId,
        'hardware_data': {
          'work_min': session.workMin,
          'break_min': session.breakMin,
          'pauses': session.pauses,
          'completed': session.completed,
          'session_count': session.session,
          'start_time': session.startTime ?? fallbackStart,
          'end_time': session.endTime ?? fallbackEnd,
          'temperature': session.temperature,
        },
        'phone_data': {
          'unlock_count': (session.pauses * 1.5).round(),
          'task_type': session.taskType,  // Dữ liệu task_type từ ESP32 (không hardcode)
          'recommendation_id': currentRecommendationId,
          'timestamp': session.receivedAt.toIso8601String(),
        },
      };

      final resp = await ApiClient.post(
        '/api/v1/pomodoro/sync',
        payload,
      );

      _lastFeedback = resp['feedback'] ?? 'Phiên đã được ghi nhận!';
      
      // Clear the recommendation ID so subsequent manual hardware sessions
      // do not falsely associate with the old AI recommendation.
      currentRecommendationId = null;
      currentTaskType = 'general';

    } on TimeoutException {
      _lastFeedback = 'Server không phản hồi.';
    } catch (e) {
      _lastFeedback = 'Không thể gửi dữ liệu: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── Gửi lệnh xuống ESP32 ────────────────────────────────────
  Future<void> sendJsonCommand(String cmd, Map<String, dynamic> params) async {
    await _ble.sendJson({'cmd': cmd, 'params': params});
  }

  Future<void> _syncTime() async {
    final now = DateTime.now();
    await sendJsonCommand('SET_TIME', {
      'year': now.year, 'month': now.month, 'day': now.day,
      'hour': now.hour, 'minute': now.minute, 'second': now.second,
    });
  }

  Future<void> syncWatchTime() => _syncTime();

  Future<void> sendPomodoroCycle(int workMin, int breakMin) async {
    await sendJsonCommand('SET_POMO', {'work_min': workMin, 'break_min': breakMin});
  }

  Future<void> sendAlarm(String time, String label) async {
    await sendJsonCommand('SET_ALARM', {'time': time, 'label': label});
  }

  Future<void> sendNotification(String title, String body) async {
    await sendJsonCommand('SHOW_NOTIF', {'title': title, 'body': body});
  }

  // ─── Helper ───────────────────────────────────────────────────
  void _setStatus(SppState state, String message) {
    _state = state;
    _statusMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _ble.removeListener(_onBleStateChanged);
    super.dispose();
  }
}
