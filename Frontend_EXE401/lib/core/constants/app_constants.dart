/// core/constants/app_constants.dart
/// Chứa tất cả constants dùng chung toàn app.
/// Thay đổi 1 chỗ duy nhất là cập nhật toàn bộ app.
library app_constants;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ============================================================
  // API Base URL - Tự động chọn đúng địa chỉ theo nền tảng
  // ============================================================
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000'; // Android Emulator
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  // ============================================================
  // API Endpoints (versioned)
  // ============================================================
  static const String apiV1 = '/api/v1';
  static String get marketEndpoint => '$apiV1/market';
  static String get schedulesEndpoint => '$apiV1/schedules';
  static String get firmwareEndpoint => '$apiV1/firmware';
  static String get firmwareLatestEndpoint => '$apiV1/firmware/latest';
}
