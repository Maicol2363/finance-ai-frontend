import 'package:finance_ai/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('API base URL', () {
    test('runtime getter follows the current client platform', () {
      final expected = defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8000'
          : 'http://127.0.0.1:8000';

      expect(AppConfig.apiBaseUrl, expected);
    });

    test('uses the Android emulator host bridge on Android', () {
      expect(
        AppConfig.resolveApiBaseUrl(platform: TargetPlatform.android),
        'http://10.0.2.2:8000',
      );
    });

    test('uses the PC loopback address on Windows', () {
      expect(
        AppConfig.resolveApiBaseUrl(platform: TargetPlatform.windows),
        'http://127.0.0.1:8000',
      );
    });

    test('uses a configured intermediary server on every platform', () {
      expect(
        AppConfig.resolveApiBaseUrl(
          platform: TargetPlatform.windows,
          configuredValue: '  https://api.example.test  ',
        ),
        'https://api.example.test',
      );
    });

    test('allows HTTP for local development servers', () {
      expect(
        AppConfig.resolveApiBaseUrl(
          platform: TargetPlatform.android,
          configuredValue: 'http://10.0.2.2:8000',
          allowInsecureHttp: true,
        ),
        'http://10.0.2.2:8000',
      );
    });

    test('rejects remote HTTP URLs even in debug builds', () {
      expect(
        () => AppConfig.resolveApiBaseUrl(
          platform: TargetPlatform.windows,
          configuredValue: 'http://192.168.1.20:8000',
          allowInsecureHttp: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects HTTP URLs when release transport is required', () {
      expect(
        () => AppConfig.resolveApiBaseUrl(
          platform: TargetPlatform.windows,
          configuredValue: 'http://localhost:8000',
          allowInsecureHttp: false,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-HTTP API URLs', () {
      expect(
        () => AppConfig.resolveApiBaseUrl(
          platform: TargetPlatform.windows,
          configuredValue: 'file:///tmp/api',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
