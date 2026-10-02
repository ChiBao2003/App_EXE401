/// core/usage_tracking/usage_tracker_service.dart
/// Service chính giao tiếp với Android native qua Platform Channel
/// Thu thập dữ liệu sử dụng điện thoại & sự kiện màn hình

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../api/api_client.dart';
import 'models.dart';

class UsageTrackerService {
  static const _methodChannel = MethodChannel('com.daonguyen.iot47/usage_stats');
  static const _eventChannel = EventChannel('com.daonguyen.iot47/screen_events');

  StreamSubscription? _screenEventSub;
  final StreamController<ScreenEvent> _screenEventController =
      StreamController<ScreenEvent>.broadcast();

  /// Singleton
  static final UsageTrackerService _instance = UsageTrackerService._();
  factory UsageTrackerService() => _instance;
  UsageTrackerService._();

  // ── Quản lý quyền ──

  /// Kiểm tra quyền Usage Stats đã được cấp chưa
  Future<bool> hasPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[UsageTracker] checkPermission error: $e');
      return false;
    }
  }

  /// Mở Settings để người dùng cấp quyền Usage Access
  Future<void> requestPermission() async {
    try {
      await _methodChannel.invokeMethod('requestPermission');
    } on PlatformException catch (e) {
      print('[UsageTracker] requestPermission error: $e');
    }
  }

  // ── Query Usage Stats ──

  /// Lấy thống kê sử dụng app trong khoảng thời gian
  Future<List<AppUsageInfo>> getUsageStats({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'queryUsageStats',
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];
      return result
          .map((e) => AppUsageInfo.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      print('[UsageTracker] queryUsageStats error: $e');
      return [];
    }
  }

  /// Lấy events chi tiết (app opened/closed) trong khoảng thời gian
  Future<List<UsageEvent>> getUsageEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'queryEvents',
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];
      return result
          .map((e) => UsageEvent.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } on PlatformException catch (e) {
      print('[UsageTracker] queryEvents error: $e');
      return [];
    }
  }

  // ── Screen Events (Realtime) ──

  /// Bắt đầu theo dõi sự kiện màn hình (on/off/unlock)
  void startScreenEventTracking() {
    _screenEventSub?.cancel();
    _screenEventSub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final screenEvent = ScreenEvent.fromMap(event);
          _screenEventController.add(screenEvent);
        }
      },
      onError: (error) {
        print('[UsageTracker] Screen event error: $error');
      },
    );
  }

  /// Dừng theo dõi sự kiện màn hình
  void stopScreenEventTracking() {
    _screenEventSub?.cancel();
    _screenEventSub = null;
  }

  /// Stream sự kiện màn hình realtime
  Stream<ScreenEvent> get screenEvents => _screenEventController.stream;

  // ── Distraction Detection ──

  /// Phát hiện các lần mất tập trung trong phiên Pomodoro
  Future<List<DistractionEvent>> detectDistractions({
    required String pomodoroSessionId,
    required DateTime pomoStartTime,
    DateTime? pomoEndTime,
  }) async {
    final end = pomoEndTime ?? DateTime.now();
    final events = await getUsageEvents(start: pomoStartTime, end: end);

    final distractions = <DistractionEvent>[];
    UsageEvent? lastResumed;

    for (final event in events) {
      // Bỏ qua app hệ thống và app hiện tại
      if (event.category == AppCategory.system) continue;
      if (event.packageName == 'com.daonguyen.iot47.eink_clock') continue;

      if (event.eventType == UsageEventType.activityResumed) {
        lastResumed = event;
      } else if (event.eventType == UsageEventType.activityPaused &&
          lastResumed != null &&
          lastResumed.packageName == event.packageName) {
        // Tính thời lượng sử dụng app
        final durationMs = event.timestamp
            .difference(lastResumed.timestamp)
            .inMilliseconds;

        // Chỉ ghi nhận nếu app gây mất tập trung và dùng > 3 giây
        if (event.category.isDistraction && durationMs > 3000) {
          distractions.add(DistractionEvent(
            packageName: event.packageName,
            appName: event.appName,
            category: event.category,
            durationMs: durationMs,
            timestamp: lastResumed.timestamp,
            pomodoroSessionId: pomodoroSessionId,
            secondsSincePomodoroStart: lastResumed.timestamp
                .difference(pomoStartTime)
                .inSeconds,
          ));
        }
        lastResumed = null;
      }
    }

    return distractions;
  }

  // ── Daily Summary ──

  /// Tạo tổng kết sử dụng hàng ngày
  Future<DailyUsageSummary> getDailySummary({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final stats = await getUsageStats(start: startOfDay, end: endOfDay);
    final events = await getUsageEvents(start: startOfDay, end: endOfDay);

    // Tính tổng thời gian
    int totalScreenTime = 0;
    int productiveTime = 0;
    int distractedTime = 0;

    for (final stat in stats) {
      totalScreenTime += stat.foregroundTimeMs;
      if (stat.category.isProductive) {
        productiveTime += stat.foregroundTimeMs;
      } else if (stat.category.isDistraction) {
        distractedTime += stat.foregroundTimeMs;
      }
    }

    // Đếm số lần unlock (USER_PRESENT events)
    // Lưu ý: screen events chỉ có khi app đang chạy, nên dùng usage events thay thế
    int unlocks = 0;
    for (final event in events) {
      if (event.eventType == UsageEventType.activityResumed) {
        unlocks++;
      }
    }

    // Tính Focus Score (0-100)
    double focusScore = 100.0;
    if (totalScreenTime > 0) {
      final distractionRatio = distractedTime / totalScreenTime;
      focusScore = ((1.0 - distractionRatio) * 100).clamp(0.0, 100.0).toDouble();
    }
    // Penalty cho quá nhiều app switches
    if (unlocks > 50) focusScore *= 0.9;
    if (unlocks > 100) focusScore *= 0.8;

    // Top apps (sorted by foreground time)
    final topApps = stats.take(10).toList();

    return DailyUsageSummary(
      date: startOfDay,
      totalScreenTimeMs: totalScreenTime,
      totalUnlocks: unlocks,
      totalDistractions: 0, // Được cập nhật từ Pomodoro sessions
      productiveTimeMs: productiveTime,
      distractedTimeMs: distractedTime,
      topApps: topApps,
      focusScore: focusScore,
    );
  }

  // ── Sync to Backend ──

  /// Gửi daily summary lên Backend API để AI Coach phân tích
  Future<bool> syncToBackend(DailyUsageSummary summary) async {
    try {
      // Tách top distraction apps và top productive apps
      final distractionApps = summary.topApps
          .where((a) => a.category.isDistraction)
          .take(5)
          .map((a) => {
                'app_name': a.appName,
                'time_ms': a.foregroundTimeMs,
                'open_count': 1,
              })
          .toList();

      final productiveApps = summary.topApps
          .where((a) => a.category.isProductive)
          .take(5)
          .map((a) => {
                'app_name': a.appName,
                'time_ms': a.foregroundTimeMs,
                'open_count': 1,
              })
          .toList();

      final body = {
        'date': DateFormat('yyyy-MM-dd').format(summary.date),
        'total_screen_time_ms': summary.totalScreenTimeMs,
        'total_unlocks': summary.totalUnlocks,
        'total_distractions_during_pomo': summary.totalDistractions,
        'productive_apps_time_ms': summary.productiveTimeMs,
        'distraction_apps_time_ms': summary.distractedTimeMs,
        'top_distraction_apps': distractionApps,
        'top_productive_apps': productiveApps,
        'focus_score': summary.focusScore,
        'pomo_sessions_count': 0,
        'pomo_distraction_rate': 0.0,
      };

      await ApiClient.post('/api/v1/usage/daily-summary', body);
      print('[UsageTracker] Synced to backend OK');
      return true;
    } catch (e) {
      print('[UsageTracker] Sync error: $e');
      return false;
    }
  }

  /// Giải phóng resources
  void dispose() {
    stopScreenEventTracking();
    _screenEventController.close();
  }
}
