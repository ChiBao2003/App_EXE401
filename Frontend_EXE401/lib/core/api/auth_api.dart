import "package:shared_preferences/shared_preferences.dart";
import "api_client.dart";

/// Auth API - Dang ky / Dang nhap / Lay thong tin user.
class AuthApi {
  static const _base = "/api/v1/auth";

  /// Dang ky tai khoan moi. Tra ve token neu thanh cong.
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final data = await ApiClient.post("$_base/register", {
      "email": email,
      "password": password,
      "display_name": displayName,
    }, auth: false);

    await _saveSession(data);
    return data;
  }

  /// Dang nhap. Tra ve token neu thanh cong.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await ApiClient.post("$_base/login", {
      "email": email,
      "password": password,
    }, auth: false);

    await _saveSession(data);
    return data;
  }

  /// Lay thong tin user dang dang nhap.
  static Future<Map<String, dynamic>> me() async {
    return await ApiClient.get("$_base/me");
  }

  /// Dang xuat: xoa token local.
  static Future<void> logout() async {
    await ApiClient.clearToken();
  }

  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final token = data["access_token"] as String;
    await ApiClient.saveToken(token);
    final prefs = await SharedPreferences.getInstance();
    final user = data["user"] as Map<String, dynamic>;
    await prefs.setString("user_id", user["id"] as String);
    await prefs.setString("user_name", user["display_name"] as String);
    await prefs.setString("user_email", user["email"] as String);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user_id");
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user_name") ?? "Ban";
  }
}
