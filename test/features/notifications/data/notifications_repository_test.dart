import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/notifications/data/notifications_repository.dart';
import 'package:finance_ai/features/notifications/domain/notification_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../notifications_test_helpers.dart';

const accessCredential = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const renewableCredential = 'ccccccccccccccccccccccccccccccccccccccccccc';

class MemoryStore implements SecureCredentialStore {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> replace(String renewableCredential) async {
    value = renewableCredential;
  }
}

class SessionRepository implements AuthSessionRepository {
  IssuedAuthSession get issued {
    final now = DateTime.utc(2026, 11, 16);
    return IssuedAuthSession(
      user: const AuthenticatedUser(
        id: 42,
        email: 'person@example.com',
        preferredCurrency: 'COP',
      ),
      accessCredential: accessCredential,
      renewableCredential: renewableCredential,
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      renewableExpiresAt: now.add(const Duration(days: 30)),
      absoluteExpiresAt: now.add(const Duration(days: 90)),
    );
  }

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async =>
      issued.user;

  @override
  Future<IssuedAuthSession> login(LoginRequest request) async => issued;

  @override
  Future<void> logout(String renewableCredential) async {}

  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async => issued;
}

Future<(ProviderContainer, NotificationsRepository)> repositoryWith(
  Future<http.Response> Function(http.Request) handler,
) async {
  final container = ProviderContainer(
    overrides: [
      httpClientProvider.overrideWithValue(MockClient(handler)),
      authSessionRepositoryProvider.overrideWithValue(SessionRepository()),
      secureCredentialStoreProvider.overrideWithValue(MemoryStore()),
    ],
  );
  await Future<void>.delayed(Duration.zero);
  expect(
    await container
        .read(authSessionControllerProvider.notifier)
        .login(email: 'person@example.com', password: 'safe-password'),
    LoginSubmitOutcome.success,
  );
  return (container, container.read(notificationsRepositoryProvider));
}

http.Response problem(
  int status,
  String code, {
  Map<String, String>? headers,
}) => http.Response(
  jsonEncode({
    'status': status,
    'code': code,
    'detail': 'Synthetic detail',
    'correlation_id': 'corr-$code',
  }),
  status,
  headers: {'content-type': 'application/json', ...?headers},
);

void main() {
  test('uses the authenticated contract and sends only what changed', () async {
    final requests = <http.Request>[];
    final (container, repository) = await repositoryWith((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/verification')) {
        return http.Response(
          jsonEncode({
            'email_hint': 'a***@example.com',
            'expires_in_seconds': 900,
            'resend_in_seconds': 60,
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/test')) {
        return http.Response(jsonEncode({'status': 'queued'}), 200);
      }
      return http.Response(jsonEncode(preferencesJson()), 200);
    });
    addTearDown(container.dispose);

    final loaded = await repository.load();
    await repository.update(showAmounts: false);
    final issued = await repository.requestVerification();
    await repository.verify('123456');
    final test = await repository.sendTestEmail();

    expect(loaded.emailHint, 'a***@example.com');
    expect(issued.resendInSeconds, 60);
    expect(test, TestEmailStatus.queued);
    expect(requests.map((item) => '${item.method} ${item.url.path}'), [
      'GET /api/v1/me/notification-preferences',
      'PATCH /api/v1/me/notification-preferences',
      'POST /api/v1/me/email/verification',
      'POST /api/v1/me/email/verify',
      'POST /api/v1/me/notifications/test',
    ]);
    expect(
      requests.every(
        (item) => item.headers['Authorization'] == 'Bearer $accessCredential',
      ),
      isTrue,
    );
    expect(jsonDecode(requests[1].body), {'show_amounts': false});
    expect(jsonDecode(requests[3].body), {'code': '123456'});
  });

  test('turns server problems into safe, specific failures', () async {
    final cases = <String, (int, String)>{
      'email_not_verified': (409, 'Primero verifica tu correo'),
      'verification_code_invalid': (400, 'Ese código no es correcto'),
      'verification_code_expired': (400, 'El código venció'),
      'verification_attempts_exceeded': (429, 'Fallaste demasiadas veces'),
      'notifications_unavailable': (503, 'no están disponibles'),
    };
    for (final entry in cases.entries) {
      final (container, repository) = await repositoryWith(
        (_) async => problem(entry.value.$1, entry.key),
      );
      addTearDown(container.dispose);

      await expectLater(
        repository.verify('654321'),
        throwsA(
          isA<NotificationFailure>()
              .having((f) => f.code, 'code', entry.key)
              .having((f) => f.userMessage, 'message', contains(entry.value.$2))
              .having(
                (f) => f.correlationId,
                'correlation',
                'corr-${entry.key}',
              )
              .having(
                (f) => '${f.userMessage}${f.technicalReason}',
                'no private input',
                allOf(isNot(contains('654321')), isNot(contains('person@'))),
              ),
        ),
      );
    }
  });

  test('keeps the wait the server asked for', () async {
    final (container, repository) = await repositoryWith(
      (_) async =>
          problem(429, 'verification_cooldown', headers: {'retry-after': '40'}),
    );
    addTearDown(container.dispose);

    await expectLater(
      repository.requestVerification(),
      throwsA(
        isA<NotificationFailure>()
            .having((f) => f.code, 'code', 'verification_cooldown')
            .having((f) => f.retryAfterSeconds, 'retry after', 40),
      ),
    );
  });

  test('an expired session is reported as such', () async {
    final (container, repository) = await repositoryWith(
      (_) async => problem(401, 'session_invalid'),
    );
    addTearDown(container.dispose);

    await expectLater(repository.load(), throwsA(isA<InvalidSessionFailure>()));
  });

  test('a lost connection on a change says the outcome is uncertain', () async {
    final (container, repository) = await repositoryWith(
      (_) async => throw http.ClientException('socket closed'),
    );
    addTearDown(container.dispose);

    await expectLater(
      repository.update(emailEnabled: true),
      throwsA(
        isA<NotificationFailure>()
            .having((f) => f.code, 'code', 'network_unavailable')
            .having((f) => f.isMutationOutcomeUncertain, 'uncertain', isTrue),
      ),
    );
  });

  test('a success with a broken body is an unexpected response', () async {
    final (container, repository) = await repositoryWith(
      (_) async => http.Response(jsonEncode({'email_hint': 'a***@x.co'}), 200),
    );
    addTearDown(container.dispose);

    await expectLater(
      repository.load(),
      throwsA(
        isA<NotificationFailure>().having(
          (f) => f.code,
          'code',
          'unexpected_response',
        ),
      ),
    );
  });
}
