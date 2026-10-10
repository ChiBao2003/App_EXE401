/// core/constants/app_constants.dart
/// Chứa tất cả constants dùng chung toàn app.
/// Thay đổi 1 chỗ duy nhất là cập nhật toàn bộ app.
library app_constants;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ============================================================
  // ⚠️ CẤU HÌNH IP ĐỘNG (Dùng --dart-define=BACKEND_IP=...)
  // ============================================================
  static const String backendLanIp = String.fromEnvironment(
    'BACKEND_IP', 
    defaultValue: '10.66.196.167'
  ); 
  static const int backendPort = 8000;

  // ============================================================
  // API Base URL - Tự động chọn đúng địa chỉ theo nền tảng
  // ============================================================
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$backendPort'; // Web: chạy cùng máy
    }
    try {
      if (Platform.isAndroid) {
        // Điện thoại thật kết nối WiFi cùng mạng LAN với máy tính
        return 'http://$backendLanIp:$backendPort';
      }
    } catch (_) {}
    return 'http://127.0.0.1:$backendPort';
  }

  // ============================================================
  // Bluetooth SPP — Tên thiết bị ESP32 cần khớp với firmware
  // ============================================================
  static const String esp32DeviceName = 'ESP32_Pomodoro_Data';

  // ============================================================
  // API Endpoints (versioned)
  // ============================================================
  static const String apiV1 = '/api/v1';
  static String get marketEndpoint => '$apiV1/market';
  static String get schedulesEndpoint => '$apiV1/schedules';
  static String get firmwareEndpoint => '$apiV1/firmware';
  static String get firmwareLatestEndpoint => '$apiV1/firmware/latest';
}
