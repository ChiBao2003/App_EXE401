import "dart:convert";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "../constants/app_constants.dart";

/// API Client trung tam cho tat ca HTTP calls den Backend.
/// Tu dong gan JWT token vao header moi request.
class ApiClient {
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
    final resp = await http.get(uri, headers: await _headers(auth: auth))
        .timeout(const Duration(seconds: 60));
    return _parse(resp);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final uri = Uri.parse("$baseUrl$path");
    final resp = await http.post(uri,
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));
    return _parse(resp);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final uri = Uri.parse("$baseUrl$path");
    final resp = await http.put(uri,
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));
    return _parse(resp);
  }

  static dynamic _parse(http.Response resp) {
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (resp.statusCode >= 400) {
      final detail = decoded["detail"] ?? "Loi khong xac dinh";
      throw ApiException(resp.statusCode, detail.toString());
    }
    return decoded;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => "ApiException($statusCode): $message";
}
