import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  // Public OAuth client IDs. They must match the Google Cloud OAuth setup.
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '3874930244-45sqv2n9btc1dr6avq428353d4vnlb2f.apps.googleusercontent.com',
  );
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static Future<void>? _initialization;

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    if (webClientId.isEmpty) {
      throw StateError('Thiếu GOOGLE_WEB_CLIENT_ID trong cấu hình ứng dụng.');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS &&
        iosClientId.isEmpty) {
      throw StateError('Thiếu GOOGLE_IOS_CLIENT_ID trong cấu hình ứng dụng.');
    }
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb
          ? webClientId
          : defaultTargetPlatform == TargetPlatform.iOS
              ? iosClientId
              : null,
      serverClientId: kIsWeb ? null : webClientId,
    );
  }

  static Future<void> signOutIfInitialized() async {
    if (_initialization == null) return;
    try {
      await _initialization;
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Local app logout must still succeed if Google SDK is unavailable.
    }
  }
}
