/// core/network/api_client.dart
/// HTTP Client dùng chung cho toàn bộ ứng dụng.
/// Xử lý base URL, headers, và lỗi tập trung 1 nơi.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Exception tùy chỉnh cho lỗi API
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Singleton HTTP Client dùng chung toàn app
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  /// GET request - Tự động decode UTF-8 để hỗ trợ tiếng Việt
  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint/');
    final response = await http.get(uri, headers: _defaultHeaders);
    return _handleResponse(response);
  }

  /// POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint/');
    final response = await http.post(
      uri,
      headers: _defaultHeaders,
      body: json.encode(body),
    );
    return _handleResponse(response);
  }

  /// DELETE request
  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    final response = await http.delete(uri, headers: _defaultHeaders);
    return _handleResponse(response);
  }

  /// Xử lý response chung - decode UTF-8, kiểm tra lỗi
  dynamic _handleResponse(http.Response response) {
    final body = json.decode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: body['detail']?.toString() ?? 'Lỗi không xác định từ server.',
    );
  }
}
