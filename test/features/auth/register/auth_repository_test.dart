import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/auth/register/data/auth_repository.dart';
import 'package:finance_ai/features/auth/register/domain/registration_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const request = RegistrationRequest(
  email: 'person@example.com',
  password: 'valid password',
  passwordConfirmation: 'valid password',
);

HttpAuthRepository repositoryWith(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 1),
}) {
  return HttpAuthRepository(
    FinanceApiClient(
      MockClient(handler),
      Uri.parse('http://api.test'),
      timeout,
    ),
  );
}

void main() {
  test('decodes the captured OpenAPI-compatible 201 response', () async {
    final repository = repositoryWith((incoming) async {
      expect(incoming.url.path, '/api/v1/auth/register');
      expect(incoming.headers['Content-Type'], 'application/json');
      expect(incoming.headers['X-Correlation-ID'], startsWith('flutter-'));
      expect(jsonDecode(incoming.body), {
        'email': 'person@example.com',
        'password': 'valid password',
        'password_confirmation': 'valid password',
      });
      return http.Response(
        jsonEncode({
          'user': {
            'id': 42,
            'email': 'person@example.com',
            'preferred_currency': 'COP',
          },
          'message': 'Account created successfully. You can now log in.',
        }),
        201,
        headers: {'x-correlation-id': 'api-correlation'},
      );
    });

    final result = await repository.register(request);

    expect(result.user.id, 42);
    expect(result.user.preferredCurrency, 'COP');
    expect(result.message, contains('log in'));
  });

  test('maps 422 by stable code and preserves safe field errors', () async {
    final repository = repositoryWith((_) async {
      return http.Response(
        jsonEncode({
          'status': 422,
          'code': 'registration_invalid',
          'detail': 'Correct the highlighted fields.',
          'correlation_id': 'test-correlation',
          'field_errors': {
            'password': ['Choose a safer password.'],
          },
        }),
        422,
      );
    });

    await expectLater(
      repository.register(request),
      throwsA(
        isA<RegistrationValidationFailure>().having(
          (failure) => failure.fieldErrors['password'],
          'password errors',
          ['Choose a safer password.'],
        ),
      ),
    );
  });

  test(
    'maps duplicate, throttle, unavailable, and unexpected responses',
    () async {
      Future<RegistrationFailure> failureFor(int status, String code) async {
        final repository = repositoryWith((_) async {
          return http.Response(
            jsonEncode({
              'status': status,
              'code': code,
              'detail': 'Safe detail.',
              'correlation_id': 'test-correlation',
            }),
            status,
          );
        });
        try {
          await repository.register(request);
        } on RegistrationFailure catch (failure) {
          return failure;
        }
        throw StateError('Expected registration failure');
      }

      expect(
        await failureFor(409, 'email_already_registered'),
        isA<RegistrationConflictFailure>(),
      );
      expect(
        (await failureFor(429, 'registration_rate_limited')).code,
        'registration_rate_limited',
      );
      expect(
        (await failureFor(503, 'service_unavailable')).code,
        'service_unavailable',
      );
      expect(
        (await failureFor(500, 'internal_error')).code,
        'unexpected_response',
      );
    },
  );

  test('timeout becomes a safe retryable failure', () async {
    final repository = repositoryWith((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('{}', 500);
    }, timeout: const Duration(milliseconds: 1));

    await expectLater(
      repository.register(request),
      throwsA(
        isA<RegistrationRetryableFailure>()
            .having((failure) => failure.code, 'code', 'network_unavailable')
            .having(
              (failure) => failure.technicalReason,
              'technical reason',
              'request_timeout',
            )
            .having(
              (failure) => failure.correlationId,
              'request ID',
              startsWith('flutter-'),
            ),
      ),
    );
  });

  test('connection failure keeps a safe request ID and reason', () async {
    final repository = repositoryWith((request) async {
      throw http.ClientException(
        'private operating system detail',
        request.url,
      );
    });

    await expectLater(
      repository.register(request),
      throwsA(
        isA<RegistrationRetryableFailure>()
            .having((failure) => failure.code, 'code', 'network_unavailable')
            .having(
              (failure) => failure.technicalReason,
              'technical reason',
              'connection_failure',
            )
            .having(
              (failure) => failure.userMessage,
              'safe message',
              isNot(contains('private operating system detail')),
            ),
      ),
    );
  });
}
