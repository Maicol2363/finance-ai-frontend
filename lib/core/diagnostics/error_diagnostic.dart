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
      technicalReason: _singleLine(
        technicalReason,
        fallback: 'unclassified_failure',
      ),
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
      ).toString().replaceFirst(RegExp(r'/$'), '');
    } on FormatException {
      return 'configured-but-hidden';
    }
  }

  static String _singleLine(String value, {required String fallback}) {
    final sanitized = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (sanitized.isEmpty) {
      return fallback;
    }
    return sanitized.length <= 160 ? sanitized : sanitized.substring(0, 160);
  }
}
