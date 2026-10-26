import 'package:finance_ai/core/diagnostics/error_diagnostic.dart';
import 'package:finance_ai/core/diagnostics/error_diagnostic_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  test('replaces raw or sensitive technical reasons with a safe fallback', () {
    final diagnostic = ErrorDiagnostic.capture(
      code: 'network_unavailable',
      operation: 'load_accounts',
      userMessage: 'No pudimos cargar las cuentas.',
      technicalReason: 'password=private-value token=private-token',
    );

    expect(diagnostic.technicalReason, 'unclassified_failure');
    expect(diagnostic.clipboardText, isNot(contains('private-value')));
    expect(diagnostic.clipboardText, isNot(contains('private-token')));
  });

  test('preserves only enumerated voice diagnostic context', () {
    final safeContext = ErrorDiagnostic.capture(
      code: 'speech_fallback_model_missing',
      operation: 'voice_capture',
      userMessage: 'Revisa los ajustes del dictado.',
      technicalReason:
          'speech_fallback_model_missing; stage=prepare; engine=integrated; '
          'cause=native_service_timeout; android_api=33',
    );
    final unsafeContext = ErrorDiagnostic.capture(
      code: 'speech_provider_error',
      operation: 'voice_capture',
      userMessage: 'No se pudo continuar.',
      technicalReason:
          'speech_provider_error; stage=prepare; engine=integrated; '
          'cause=private@example.com; android_api=33',
    );

    expect(safeContext.technicalReason, contains('engine=integrated'));
    expect(
      safeContext.technicalReason,
      contains('cause=native_service_timeout'),
    );
    expect(safeContext.technicalReason, contains('android_api=33'));
    expect(unsafeContext.technicalReason, 'unclassified_failure');
    expect(unsafeContext.clipboardText, isNot(contains('private@example.com')));
  });

  testWidgets('diagnostic panel is Spanish and copies the stable safe report', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final diagnostic = ErrorDiagnostic.capture(
      code: 'network_unavailable',
      operation: 'load_accounts',
      userMessage: 'No pudimos conectar con el servicio.',
      technicalReason: 'connection_failure',
      correlationId: 'safe-request-id',
      occurredAtUtc: DateTime.parse('2026-08-29T17:00:00Z'),
      platform: TargetPlatform.android,
      apiBaseUrl: 'https://example.test/api',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ErrorDiagnosticPanel(diagnostic: diagnostic)),
      ),
    );

    expect(find.text('No pudimos conectar con el servicio.'), findsOneWidget);
    expect(find.byKey(const Key('error-diagnostic-code')), findsNothing);
    expect(
      find.text(
        'Copia el reporte seguro al pedir ayuda. No incluye los datos del formulario.',
      ),
      findsOneWidget,
    );
    expect(find.text('Copiar detalles del error'), findsOneWidget);

    await tester.tap(find.byKey(const Key('copy-error-details-button')));
    await tester.pumpAndSettle();

    expect(copiedText, isNot(diagnostic.clipboardText));
    expect(copiedText, contains('Motivo técnico: connection_failure'));
    expect(copiedText, contains('Código de error: network_unavailable'));
    expect(
      copiedText,
      contains(
        'Privacidad: el reporte excluye datos del formulario y secretos.',
      ),
    );
    expect(
      find.text('Se copiaron los detalles seguros del error.'),
      findsOneWidget,
    );
  });
}
