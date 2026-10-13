import 'package:finance_ai/core/diagnostics/error_diagnostic.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats a stable copyable report with useful safe context', () {
    final diagnostic = ErrorDiagnostic.capture(
      code: 'network_unavailable',
      operation: 'register_account',
      userMessage: 'We could not reach the service.',
      technicalReason: 'connection_failure',
      correlationId: 'flutter-safe-request-1',
      occurredAtUtc: DateTime.parse('2026-08-29T17:00:00Z'),
      platform: TargetPlatform.windows,
      apiBaseUrl: 'https://user:private-value@example.test:8443/api?token=secret#private',
    );

    expect(diagnostic.clipboardText, contains('Finance AI error report'));
    expect(
      diagnostic.clipboardText,
      contains('Error code: network_unavailable'),
    );
    expect(diagnostic.clipboardText, contains('Platform: windows'));
    expect(
      diagnostic.clipboardText,
      contains('API location: https://example.test:8443/api'),
    );
    expect(
      diagnostic.clipboardText,
      contains('Request/correlation ID: flutter-safe-request-1'),
    );
    expect(diagnostic.clipboardText, isNot(contains('private-value')));
    expect(diagnostic.clipboardText, isNot(contains('token=secret')));
    expect(diagnostic.clipboardText, isNot(contains('#private')));
  });

  test('removes line breaks and hides malformed API configuration', () {
    final diagnostic = ErrorDiagnostic.capture(
      code: 'unexpected\nforged',
      operation: 'register\raccount',
      userMessage: 'Safe\tmessage',
      technicalReason: 'invalid\nresponse',
      correlationId: 'request\r\nforged',
      occurredAtUtc: DateTime.parse('2026-08-29T17:00:00Z'),
      platform: TargetPlatform.android,
      apiBaseUrl: 'not an API URL with a private value',
    );

    expect(diagnostic.apiLocation, 'configured-but-hidden');
    expect(diagnostic.clipboardText, isNot(contains('\r')));
    expect(diagnostic.clipboardText, contains('Error code: unexpected forged'));
    expect(
      diagnostic.clipboardText,
      contains('Request/correlation ID: request forged'),
    );
  });
}
