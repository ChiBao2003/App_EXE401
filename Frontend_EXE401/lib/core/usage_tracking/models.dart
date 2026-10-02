/// core/usage_tracking/models.dart
/// Data models cho hệ thống thu thập dữ liệu sử dụng điện thoại

/// Helper: chuyển dynamic (int/long/double/String) sang int an toàn
int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Phân loại ứng dụng
enum AppCategory {
  productivity,
  communication,
  socialMedia,
  entertainment,
  games,
  system,
  education,
  other;

  /// Parse từ string trả về từ Android native
  static AppCategory fromString(String value) {
    switch (value) {
      case 'productivity': return AppCategory.productivity;
      case 'communication': return AppCategory.communication;
      case 'social_media': return AppCategory.socialMedia;
      case 'entertainment': return AppCategory.entertainment;
      case 'games': return AppCategory.games;
      case 'system': return AppCategory.system;
      case 'education': return AppCategory.education;
      default: return AppCategory.other;
    }
  }

  String get label {
    switch (this) {
      case AppCategory.productivity: return 'Năng suất';
      case AppCategory.communication: return 'Liên lạc';
      case AppCategory.socialMedia: return 'Mạng xã hội';
      case AppCategory.entertainment: return 'Giải trí';
      case AppCategory.games: return 'Trò chơi';
      case AppCategory.system: return 'Hệ thống';
      case AppCategory.education: return 'Giáo dục';
      case AppCategory.other: return 'Khác';
    }
  }

  /// App thuộc loại gây mất tập trung?
  bool get isDistraction =>
      this == AppCategory.socialMedia ||
      this == AppCategory.entertainment ||
      this == AppCategory.games;

  /// App thuộc loại hiệu quả?
  bool get isProductive =>
      this == AppCategory.productivity ||
      this == AppCategory.education;
}

/// Thông tin sử dụng 1 ứng dụng
class AppUsageInfo {
  final String packageName;
  final String appName;
  final AppCategory category;
  final int foregroundTimeMs;
  final DateTime firstTimestamp;
  final DateTime lastTimestamp;

  AppUsageInfo({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.foregroundTimeMs,
    required this.firstTimestamp,
    required this.lastTimestamp,
  });

  factory AppUsageInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppUsageInfo(
      packageName: (map['packageName'] ?? '').toString(),
      appName: (map['appName'] ?? '').toString(),
      category: AppCategory.fromString((map['category'] ?? 'other').toString()),
      foregroundTimeMs: _toInt(map['foregroundTimeMs']),
      firstTimestamp: DateTime.fromMillisecondsSinceEpoch(
          _toInt(map['firstTimestamp'])),
      lastTimestamp: DateTime.fromMillisecondsSinceEpoch(
          _toInt(map['lastTimestamp'])),
    );
  }

  Map<String, dynamic> toJson() => {
    'package_name': packageName,
    'app_name': appName,
    'category': category.name,
    'foreground_time_ms': foregroundTimeMs,
    'first_timestamp': firstTimestamp.toIso8601String(),
    'last_timestamp': lastTimestamp.toIso8601String(),
  };

  /// Duration dưới dạng chuỗi đọc được
  String get durationText {
    final mins = foregroundTimeMs ~/ 60000;
    final hours = mins ~/ 60;
    final remainMins = mins % 60;
    if (hours > 0) return '${hours}h ${remainMins}m';
    return '${mins}m';
  }
}

/// Loại sự kiện sử dụng
enum UsageEventType {
  activityResumed, // App được mở (foreground)
  activityPaused,  // App bị ẩn (background)
}

/// Sự kiện sử dụng ứng dụng
class UsageEvent {
  final String packageName;
  final String appName;
  final AppCategory category;
  final UsageEventType eventType;
  final DateTime timestamp;

  UsageEvent({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.eventType,
    required this.timestamp,
  });

  factory UsageEvent.fromMap(Map<dynamic, dynamic> map) {
    return UsageEvent(
      packageName: (map['packageName'] ?? '').toString(),
      appName: (map['appName'] ?? '').toString(),
      category: AppCategory.fromString((map['category'] ?? 'other').toString()),
      eventType: _toInt(map['eventType']) == 1
          ? UsageEventType.activityResumed
          : UsageEventType.activityPaused,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          _toInt(map['timestamp'])),
    );
  }

  Map<String, dynamic> toJson() => {
    'package_name': packageName,
    'app_name': appName,
    'category': category.name,
    'event_type': eventType.name,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Loại sự kiện màn hình
enum ScreenEventType { screenOn, screenOff, userPresent }

/// Sự kiện bật/tắt/unlock màn hình
class ScreenEvent {
  final ScreenEventType type;
  final DateTime timestamp;
  final bool duringPomodoro;
  final String? pomodoroSessionId;

  ScreenEvent({
    required this.type,
    required this.timestamp,
    this.duringPomodoro = false,
    this.pomodoroSessionId,
  });

  factory ScreenEvent.fromMap(Map<dynamic, dynamic> map) {
    final eventStr = (map['event'] ?? 'SCREEN_ON').toString();
    return ScreenEvent(
      type: eventStr == 'SCREEN_OFF'
          ? ScreenEventType.screenOff
          : eventStr == 'USER_PRESENT'
              ? ScreenEventType.userPresent
              : ScreenEventType.screenOn,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          _toInt(map['timestamp'])),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'during_pomodoro': duringPomodoro,
    'pomodoro_session_id': pomodoroSessionId,
  };
}

/// Sự kiện mất tập trung trong Pomodoro
class DistractionEvent {
  final String packageName;
  final String appName;
  final AppCategory category;
  final int durationMs;
  final DateTime timestamp;
  final String pomodoroSessionId;
  final int secondsSincePomodoroStart;

  DistractionEvent({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.durationMs,
    required this.timestamp,
    required this.pomodoroSessionId,
    required this.secondsSincePomodoroStart,
  });

  Map<String, dynamic> toJson() => {
    'package_name': packageName,
    'app_name': appName,
    'category': category.name,
    'duration_ms': durationMs,
    'timestamp': timestamp.toIso8601String(),
    'pomodoro_session_id': pomodoroSessionId,
    'seconds_since_pomo_start': secondsSincePomodoroStart,
  };
}

/// Tổng kết sử dụng hàng ngày
class DailyUsageSummary {
  final DateTime date;
  final int totalScreenTimeMs;
  final int totalUnlocks;
  final int totalDistractions;
  final int productiveTimeMs;
  final int distractedTimeMs;
  final List<AppUsageInfo> topApps;
  final double focusScore;

  DailyUsageSummary({
    required this.date,
    required this.totalScreenTimeMs,
    required this.totalUnlocks,
    required this.totalDistractions,
    required this.productiveTimeMs,
    required this.distractedTimeMs,
    required this.topApps,
    required this.focusScore,
  });

  String get totalScreenTimeText {
    final mins = totalScreenTimeMs ~/ 60000;
    final hours = mins ~/ 60;
    final remainMins = mins % 60;
    return '${hours}h ${remainMins}m';
  }

  String get productiveTimeText {
    final mins = productiveTimeMs ~/ 60000;
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  String get distractedTimeText {
    final mins = distractedTimeMs ~/ 60000;
    return '${mins ~/ 60}h ${mins % 60}m';
  }
}
