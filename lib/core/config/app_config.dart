import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'FINANCE_AI_API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl => resolveApiBaseUrl(
    platform: defaultTargetPlatform,
    configuredValue: _configuredApiBaseUrl,
  );

  static String resolveApiBaseUrl({
    required TargetPlatform platform,
    String configuredValue = '',
  }) {
    final configured = configuredValue.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    return platform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  static const requestTimeout = Duration(seconds: 15);

  static String get sessionPlatform =>
      defaultTargetPlatform == TargetPlatform.android ? 'android' : 'windows';
}
