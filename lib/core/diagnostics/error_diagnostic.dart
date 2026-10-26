import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

class ErrorDiagnostic {
  ErrorDiagnostic._({
    required this.code,
    required this.operation,
    required this.userMessage,
    required this.occurredAtUtc,
    required this.platform,
    required this.apiLocation,
    required this.correlationId,
    required this.technicalReason,
  });

  factory ErrorDiagnostic.capture({
    required String code,
    required String operation,
    required String userMessage,
    required String technicalReason,
    String correlationId = 'unavailable',
    DateTime? occurredAtUtc,
    TargetPlatform? platform,
    String? apiBaseUrl,
  }) {
    return ErrorDiagnostic._(
      code: _singleLine(code, fallback: 'unexpected_client_error'),
      operation: _singleLine(operation, fallback: 'unknown_operation'),
      userMessage: _singleLine(
        userMessage,
        fallback: 'The operation could not be completed.',
      ),
      occurredAtUtc: (occurredAtUtc ?? DateTime.now()).toUtc(),
      platform: (platform ?? defaultTargetPlatform).name,
      apiLocation: _safeApiLocation(apiBaseUrl ?? AppConfig.apiBaseUrl),
      correlationId: _singleLine(correlationId, fallback: 'unavailable'),
      technicalReason: _safeTechnicalReason(technicalReason),
    );
  }

  final String code;
  final String operation;
  final String userMessage;
  final DateTime occurredAtUtc;
  final String platform;
  final String apiLocation;
  final String correlationId;
  final String technicalReason;

  String get clipboardText => [
    'Finance AI error report',
    'Error code: $code',
    'Operation: $operation',
    'Time UTC: ${occurredAtUtc.toIso8601String()}',
    'Platform: $platform',
    'API location: $apiLocation',
    'Request/correlation ID: $correlationId',
    'Technical reason: $technicalReason',
    'Message: $userMessage',
    'Privacy: form values and secrets are intentionally excluded.',
  ].join('\n');

  // Cache compiled RegExp instances to eliminate repeated pattern compilation.
  static final RegExp _trailingSlashPattern = RegExp(r'/$');
  static final RegExp _whitespacePattern = RegExp(r'[\r\n\t]+');
  static final RegExp _safeReasonPattern = RegExp(r'^[a-z][a-z0-9_]{0,79}$');
  static final RegExp _httpReasonPattern = RegExp(r'^http_[1-5][0-9]{2}$');
  static final RegExp _safeVoiceContextPattern = RegExp(
    r'^(speech_(?:busy|fallback_memory|fallback_model_missing|fallback_unavailable|finalize_timeout|language_unavailable|microphone_busy|model_download_failed|model_download_pending|model_invalid|model_missing|no_match|no_speech|offline_unavailable|permission_denied|permission_required|preparation_timeout|provider_error|session_ended|settings_unavailable|text_too_long)); '
    r'stage=(?:prepare|start|download); engine=(?:device|integrated); '
    r'cause=(?:none|native_service_missing|native_service_timeout|native_service_error|native_model_missing)'
    r'(?:; android_api=(?:[1-9]|[1-9][0-9]))?$',
  );
  static final RegExp _sensitiveReasonPattern = RegExp(
    r'(password|token|secret|email|authorization|bearer|https?://|@|[=/\\])',
    caseSensitive: false,
  );

  static String _safeTechnicalReason(String value) {
    final normalized = _singleLine(value, fallback: 'unclassified_failure');
    if (_safeVoiceContextPattern.hasMatch(normalized)) {
      return normalized;
    }
    if ((!_safeReasonPattern.hasMatch(normalized) &&
            !_httpReasonPattern.hasMatch(normalized)) ||
        _sensitiveReasonPattern.hasMatch(normalized)) {
      return 'unclassified_failure';
    }
    return normalized;
  }

  static String _safeApiLocation(String value) {
    try {
      final uri = Uri.parse(value.trim());
      if (!uri.hasScheme || uri.host.isEmpty) {
        return 'configured-but-hidden';
      }
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        return 'configured-but-hidden';
      }
      final defaultPort =
          (scheme == 'http' && uri.port == 80) ||
          (scheme == 'https' && uri.port == 443);
      return Uri(
        scheme: scheme,
        host: uri.host,
        port: defaultPort ? null : uri.port,
        path: uri.path,
      ).toString().replaceFirst(_trailingSlashPattern, '');
    } on FormatException {
      return 'configured-but-hidden';
    }
  }

  static String _singleLine(String value, {required String fallback}) {
    final sanitized = value.replaceAll(_whitespacePattern, ' ').trim();
    if (sanitized.isEmpty) {
      return fallback;
    }
    return sanitized.length <= 160 ? sanitized : sanitized.substring(0, 160);
  }
}
