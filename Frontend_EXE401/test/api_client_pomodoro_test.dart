import 'dart:async';
import 'dart:convert';
import 'package:eink_clock/core/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({'jwt_token': 'test-token'}),
  );
  test('ApiClient posts JSON with JWT and preserves completed=false', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/pomodoro/sync');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(jsonDecode(request.body)['hardware_data']['completed'], false);
      return http.Response('{"status":"ok","session_id":"stored"}', 200);
    });
    final result = await http.runWithClient(
      () => ApiClient.post('/api/v1/pomodoro/sync', {
        'hardware_data': {'completed': false},
      }),
      () => client,
    );
    expect(result['status'], 'ok');
  });
  for (final code in [401, 422, 500, 503]) {
    test('HTTP $code is propagated, never treated as saved', () async {
      await expectLater(
        http.runWithClient(
          () => ApiClient.post('/api/v1/pomodoro/sync', {}),
          () => MockClient(
            (_) async => http.Response('{"detail":"failed"}', code),
          ),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', code),
        ),
      );
    });
  }
  test('network timeout propagates to persistence/queue caller', () async {
    await expectLater(
      http.runWithClient(
        () => ApiClient.post('/api/v1/pomodoro/sync', {}),
        () =>
            MockClient((_) async => throw TimeoutException('network timeout')),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
