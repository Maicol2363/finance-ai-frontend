import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const access = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const renewable = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Map<String, Object?> sessionJson() => {
  'user': {
    'id': 42,
    'email': 'person@example.com',
    'preferred_currency': 'COP',
  },
  'token_type': 'Bearer',
  'access_credential': access,
  'renewable_credential': renewable,
  'access_expires_at': '2026-08-30T12:15:00Z',
  'renewable_expires_at': '2026-09-29T12:00:00Z',
  'absolute_expires_at': '2026-11-28T12:00:00Z',
};

HttpAuthSessionRepository repositoryWith(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 1),
}) {
  return HttpAuthSessionRepository(
    FinanceApiClient(
      MockClient(handler),
      Uri.parse('http://api.test'),
      timeout,
    ),
  );
}

void main() {
  test(
    'Login sends the platform and decodes the opaque session contract',
    () async {
      final repository = repositoryWith((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/login');
        expect(request.headers['X-Correlation-ID'], startsWith('flutter-'));
        expect(jsonDecode(request.body), {
          'email': 'person@example.com',
          'password': 'exact-password',
          'platform': 'windows',
        });
        return http.Response(
          jsonEncode(sessionJson()),
          200,
          headers: {'x-correlation-id': 'login-correlation'},
        );
      });

      final result = await repository.login(
        const LoginRequest(
          email: 'person@example.com',
          password: 'exact-password',
          platform: 'windows',
        ),
      );

      expect(result.accessCredential, access);
      expect(result.renewableCredential, renewable);
      expect(result.user.preferredCurrency, 'COP');
    },
  );

  test(
    'refresh, current user, and empty 204 Logout use exact contracts',
    () async {
      final requests = <http.Request>[];
      final repository = repositoryWith((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/refresh')) {
          return http.Response(jsonEncode(sessionJson()), 200);
        }
        if (request.url.path.endsWith('/me')) {
          return http.Response(
            jsonEncode({
              'id': 42,
              'email': 'person@example.com',
              'preferred_currency': 'COP',
            }),
            200,
          );
        }
        return http.Response('', 204);
      });

      await repository.refresh(renewable);
      final user = await repository.currentUser(access);
      await repository.logout(renewable);

      expect(jsonDecode(requests[0].body), {'renewable_credential': renewable});
      expect(requests[1].method, 'GET');
      expect(requests[1].headers['Authorization'], 'Bearer $access');
      expect(jsonDecode(requests[2].body), {'renewable_credential': renewable});
      expect(user.email, 'person@example.com');
    },
  );

  test('generic invalid credentials never expose server details', () async {
    final repository = repositoryWith((_) async {
      return http.Response(
        jsonEncode({
          'status': 401,
          'code': 'invalid_credentials',
          'detail': 'Invalid email or password.',
          'correlation_id': 'login-correlation',
        }),
        401,
      );
    });

    await expectLater(
      repository.login(
        const LoginRequest(
          email: 'private@example.com',
          password: 'private-password',
          platform: 'android',
        ),
      ),
      throwsA(
        isA<InvalidCredentialsFailure>()
            .having(
              (failure) => failure.userMessage,
              'generic message',
              'Invalid email or password.',
            )
            .having(
              (failure) => failure.correlationId,
              'correlation',
              'login-correlation',
            ),
      ),
    );
  });

  test(
    'authoritative renewal denial differs from retryable transport failure',
    () async {
      final invalidRepository = repositoryWith((_) async {
        return http.Response(
          jsonEncode({
            'status': 401,
            'code': 'session_invalid',
            'detail': 'Please log in again.',
            'correlation_id': 'refresh-correlation',
          }),
          401,
        );
      });
      await expectLater(
        invalidRepository.refresh(renewable),
        throwsA(isA<InvalidSessionFailure>()),
      );

      final offlineRepository = repositoryWith((request) async {
        throw http.ClientException('private network detail', request.url);
      });
      await expectLater(
        offlineRepository.refresh(renewable),
        throwsA(
          isA<AuthRetryableFailure>()
              .having((failure) => failure.code, 'code', 'network_unavailable')
              .having(
                (failure) => failure.userMessage,
                'safe message',
                isNot(contains('private network detail')),
              ),
        ),
      );
    },
  );

  test(
    'invalid JSON and missing success bodies are safe unexpected responses',
    () async {
      final invalidJson = repositoryWith(
        (_) async => http.Response('not-json', 200),
      );
      await expectLater(
        invalidJson.refresh(renewable),
        throwsA(
          isA<AuthRetryableFailure>().having(
            (failure) => failure.code,
            'code',
            'unexpected_response',
          ),
        ),
      );

      final missingBody = repositoryWith((_) async => http.Response('', 200));
      await expectLater(
        missingBody.currentUser(access),
        throwsA(isA<AuthRetryableFailure>()),
      );
    },
  );
}
