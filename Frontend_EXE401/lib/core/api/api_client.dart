import "dart:convert";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "../constants/app_constants.dart";

/// API Client trung tam cho tat ca HTTP calls den Backend.
/// Tu dong gan JWT token vao header moi request.
class ApiClient {
  static final navigatorKey = GlobalKey<NavigatorState>();
  // Lay IP dong tu AppConstants
  static String get baseUrl => AppConstants.baseUrl;

  // ============================================================
  // Token management
  // ============================================================
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token");
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("jwt_token", token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("jwt_token");
    await prefs.remove("user_id");
    await prefs.remove("user_name");
    await prefs.remove("user_email");
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ============================================================
  // HTTP methods
  // ============================================================
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {"Content-Type": "application/json"};
    if (auth) {
      final token = await getToken();
      if (token != null) headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

  static Future<dynamic> get(String path, {Map<String, String>? params, bool auth = true}) async {
    var uri = Uri.parse("$baseUrl$path");
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    final headers = await _headers(auth: auth);
    final resp = await http.get(uri, headers: headers)
        .timeout(const Duration(seconds: 60));
    return _parse(resp, token: headers["Authorization"]);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final uri = Uri.parse("$baseUrl$path");
    final headers = await _headers(auth: auth);
    final resp = await http.post(uri,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));
    return _parse(resp, token: headers["Authorization"]);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final uri = Uri.parse("$baseUrl$path");
    final headers = await _headers(auth: auth);
    final resp = await http.put(uri,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));
    return _parse(resp, token: headers["Authorization"]);
  }

  static Future<dynamic> _parse(http.Response resp, {String? token}) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    } on FormatException {
      decoded = null;
    }
    if (resp.statusCode >= 400) {
      if (resp.statusCode == 401 && token != null &&
          token == "Bearer ${await getToken()}") {
        await clearToken();
        final navigator = navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushNamedAndRemoveUntil("/login", (route) => false);
        }
      }
      throw ApiException(resp.statusCode, _errorMessage(decoded, resp.statusCode));
    }
    return decoded;
  }

  static String _errorMessage(dynamic decoded, int statusCode) {
    final detail = decoded is Map ? decoded["detail"] : null;
    if (detail is String && detail.trim().isNotEmpty) return detail;
    if (statusCode == 422) {
      if (detail is List) {
        for (final item in detail) {
          if (item is Map) {
            final location = item["loc"];
            final field = location is List && location.isNotEmpty
                ? location.last.toString() : "";
            if (field == "password" || field == "new_password") {
              return "Mật khẩu phải có ít nhất 6 ký tự.";
            }
            if (field == "email") return "Email không hợp lệ.";
            if (field == "display_name") return "Tên hiển thị không hợp lệ.";
          }
        }
      }
      return "Dữ liệu nhập chưa hợp lệ. Vui lòng kiểm tra lại.";
    }
    if (statusCode == 409) return "Email đã được đăng ký.";
    return "Yêu cầu thất bại (mã $statusCode). Vui lòng thử lại.";
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => "ApiException($statusCode): $message";
}
