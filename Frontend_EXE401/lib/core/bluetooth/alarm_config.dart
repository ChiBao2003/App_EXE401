import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const maxWatchAlarms = 8;
const alarmsStorageKey = 'setting_alarms_v2';
const alarmsPendingKey = 'setting_alarms_pending';

class WatchAlarm {
  final int hour;
  final int minute;
  final String label;
  final int days;
  final bool enabled;

  const WatchAlarm({required this.hour, required this.minute, required this.label,
    required this.days, required this.enabled});

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute,
    'label': label, 'days': days, 'enabled': enabled};

  factory WatchAlarm.fromJson(Map<String, dynamic> json) {
    final alarm = WatchAlarm(hour: json['hour'] as int, minute: json['minute'] as int,
      label: json['label'] as String, days: json['days'] as int,
      enabled: json['enabled'] as bool);
    if (alarm.hour < 0 || alarm.hour > 23 || alarm.minute < 0 || alarm.minute > 59 ||
        alarm.days < 1 || alarm.days > 127 || alarm.label.trim().isEmpty ||
        alarm.label.length > 31) {
      throw const FormatException('Báo thức không hợp lệ');
    }
    return alarm;
  }
}

List<WatchAlarm> loadWatchAlarms(SharedPreferences prefs) {
  final saved = prefs.getString(alarmsStorageKey);
  if (saved != null) {
    final values = jsonDecode(saved) as List;
    if (values.length > maxWatchAlarms) throw const FormatException('Quá nhiều báo thức');
    return values.map((e) => WatchAlarm.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
  // Migrate the previous single-alarm phone configuration without losing it.
  final time = (prefs.getString('setting_alarm1_time') ?? '06:30').split(':');
  return [WatchAlarm(hour: int.tryParse(time.first) ?? 6,
    minute: time.length > 1 ? int.tryParse(time[1]) ?? 30 : 30,
    label: prefs.getString('setting_alarm1_label') ?? 'Báo thức',
    days: prefs.getInt('setting_alarm1_days') ?? 127,
    enabled: prefs.getBool('setting_alarm1_enabled') ?? false)];
}

Future<void> saveWatchAlarms(SharedPreferences prefs, List<WatchAlarm> alarms) async {
  if (alarms.length > maxWatchAlarms) throw const FormatException('Tối đa 8 báo thức');
  for (final alarm in alarms) { WatchAlarm.fromJson(alarm.toJson()); }
  if (!await prefs.setString(alarmsStorageKey, jsonEncode(alarms.map((e) => e.toJson()).toList())) ||
      !await prefs.setBool(alarmsPendingKey, true)) {
    throw StateError('Không lưu được báo thức trên điện thoại');
  }
}
