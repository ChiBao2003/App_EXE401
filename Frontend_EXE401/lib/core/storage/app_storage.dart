import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // === Time Adjustment ===
  static String get adjustMode => _prefs.getString('adjust_mode') ?? 'Không hiệu chỉnh';
  static int get adjustHour => _prefs.getInt('adjust_hour') ?? 0;
  static Future<void> saveAdjust(String mode, int hour) async {
    await _prefs.setString('adjust_mode', mode);
    await _prefs.setInt('adjust_hour', hour);
  }

  // === Sleep Mode ===
  static int get sleepStartHour => _prefs.getInt('sleep_start_h') ?? 0;
  static int get sleepStartMin => _prefs.getInt('sleep_start_m') ?? 0;
  static int get sleepEndHour => _prefs.getInt('sleep_end_h') ?? 0;
  static int get sleepEndMin => _prefs.getInt('sleep_end_m') ?? 0;
  static Future<void> saveSleep(int sh, int sm, int eh, int em) async {
    await _prefs.setInt('sleep_start_h', sh);
    await _prefs.setInt('sleep_start_m', sm);
    await _prefs.setInt('sleep_end_h', eh);
    await _prefs.setInt('sleep_end_m', em);
  }

  // === Alarm ===
  static int get alarmHour => _prefs.getInt('alarm_h') ?? 0;
  static int get alarmMin => _prefs.getInt('alarm_m') ?? 0;
  static Future<void> saveAlarm(int h, int m) async {
    await _prefs.setInt('alarm_h', h);
    await _prefs.setInt('alarm_m', m);
  }

  // === Countdown ===
  static int get countDown => _prefs.getInt('count_down') ?? 0;
  static int get countUp => _prefs.getInt('count_up') ?? 0;
  static Future<void> saveCountdown(int down, int up) async {
    await _prefs.setInt('count_down', down);
    await _prefs.setInt('count_up', up);
  }

  // === Interfaces ===
  static List<bool> get interfaceEnabled {
    return List.generate(9, (i) => _prefs.getBool('iface_enabled_$i') ?? (i < 5));
  }

  static List<double> get interfaceMinutes {
    return List.generate(9, (i) => _prefs.getDouble('iface_min_$i') ?? (i < 5 ? 5.0 : 0.0));
  }

  static Future<void> saveInterfaces(List<bool> enabled, List<double> minutes) async {
    for (int i = 0; i < enabled.length; i++) {
      await _prefs.setBool('iface_enabled_$i', enabled[i]);
      await _prefs.setDouble('iface_min_$i', minutes[i]);
    }
  }

  // === Design settings ===
  static bool get highlightObject => _prefs.getBool('highlight_obj') ?? true;
  static bool get rotateScreen => _prefs.getBool('rotate_screen') ?? false;
  static Future<void> saveDesignSettings(bool highlight, bool rotate) async {
    await _prefs.setBool('highlight_obj', highlight);
    await _prefs.setBool('rotate_screen', rotate);
  }

  static Future<void> clearAll() async {
    await _prefs.clear();
  }
}
