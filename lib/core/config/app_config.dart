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
    bool allowInsecureHttp = kDebugMode,
  }) {
    final configured = configuredValue.trim();
    final baseUrl = configured.isNotEmpty
        ? configured
        : platform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException(
        'API base URL must be an absolute HTTP or HTTPS URL.',
      );
    }
    if (uri.scheme == 'http' &&
        (!allowInsecureHttp || !_isLocalDevelopmentHost(uri.host))) {
      throw const FormatException(
        'HTTP is allowed only for local development endpoints in debug builds.',
      );
    }
    return baseUrl;
  }

  static bool _isLocalDevelopmentHost(String host) =>
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '10.0.2.2';

  static const requestTimeout = Duration(seconds: 30);
  static const aiRequestTimeout = Duration(seconds: 60);

  /// A chat turn waits for one short AI call (the server stops at 25 s), so the
  /// client gives up just after it instead of leaving the user waiting a minute.
  static const textCaptureTimeout = Duration(seconds: 30);

  static String get sessionPlatform =>
      defaultTargetPlatform == TargetPlatform.android ? 'android' : 'windows';
}
