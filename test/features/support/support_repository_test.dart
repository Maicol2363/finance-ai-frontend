import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/support/data/support_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const accessOne = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const accessTwo = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const renewable = 'ccccccccccccccccccccccccccccccccccccccccccc';

IssuedAuthSession issued(String access) {
  final now = DateTime.utc(2026, 9, 8);
  return IssuedAuthSession(
    user: const AuthenticatedUser(
      id: 42,
      email: 'person@example.com',
      preferredCurrency: 'COP',
    ),
    accessCredential: access,
    renewableCredential: renewable,
    accessExpiresAt: now.add(const Duration(minutes: 15)),
    renewableExpiresAt: now.add(const Duration(days: 30)),
    absoluteExpiresAt: now.add(const Duration(days: 90)),
  );
}

class MemoryStore implements SecureCredentialStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> replace(String renewableCredential) async {
    value = renewableCredential;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class SessionRepository implements AuthSessionRepository {
  int refreshes = 0;

  @override
  Future<IssuedAuthSession> login(LoginRequest request) async =>
      issued(accessOne);

  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async {
    refreshes += 1;
    return issued(accessTwo);
  }

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async =>
      issued(accessOne).user;

  @override
  Future<void> logout(String renewableCredential) async {}
}

Future<(ProviderContainer, SupportRepository)> setup(
  Future<http.Response> Function(http.Request) handler,
) async {
  final container = ProviderContainer(
    overrides: [
      httpClientProvider.overrideWithValue(MockClient(handler)),
      authSessionRepositoryProvider.overrideWithValue(SessionRepository()),
      secureCredentialStoreProvider.overrideWithValue(MemoryStore()),
    ],
  );
  final session = container.read(authSessionControllerProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  await session.login(email: 'person@example.com', password: 'safe-password');
  return (container, container.read(supportRepositoryProvider));
}

const ticket = {
  'id': 7,
  'subject': 'Ayuda',
  'description': 'Texto',
  'category': 'general',
  'status': 'open',
  'created_at': '2026-11-14T10:00:00Z',
  'resolution_summary': null,
};

void main() {
  test(
    'uses the shared authenticated contract without supplied owner or author',
    () async {
      final requests = <http.Request>[];
      final (container, repository) = await setup((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/messages')) {
          return http.Response('', 204);
        }
        if (request.url.path.endsWith('/7')) {
          return http.Response(
            jsonEncode({
              'ticket': {
                ...ticket,
                'status': 'resolved',
                'resolution_summary': 'Atendido',
              },
              'messages': [
                {
                  'id': 1,
                  'author_user_id': 42,
                  'body': '<script>literal</script>',
                  'created_at': '2026-11-14T10:01:00Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(
            request.method == 'POST'
                ? ticket
                : {
                    'tickets': [ticket],
                  },
          ),
          request.method == 'POST' ? 201 : 200,
        );
      });
      addTearDown(container.dispose);
      expect((await repository.list()).single.id, 7);
      await repository.create(
        subject: 'Ayuda',
        category: 'general',
        description: 'Texto',
      );
      final conversation = await repository.read(7);
      expect(conversation.ticket.resolution, 'Atendido');
      expect(conversation.messages.single.body, '<script>literal</script>');
      await repository.send(7, 'Respuesta');
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer $accessOne',
        ),
        isTrue,
      );
      expect(jsonDecode(requests[1].body), {
        'subject': 'Ayuda',
        'category': 'general',
        'description': 'Texto',
      });
      expect(jsonDecode(requests[3].body), {'body': 'Respuesta'});
    },
  );
  for (final status in [403, 404, 409, 422, 500]) {
    test(
      'safe diagnostic for HTTP $status excludes server detail and form values',
      () async {
        final (container, repository) = await setup(
          (request) async => http.Response(
            jsonEncode({
              'code': status == 409
                  ? 'support_ticket_state_conflict'
                  : 'untrusted-secret@example.test',
              'detail': 'private@example.test password-secret',
            }),
            status,
            headers: {'x-correlation-id': 'corr-123'},
          ),
        );
        addTearDown(container.dispose);
        try {
          await repository.send(7, 'private-input');
          fail('Expected failure');
        } on SupportFailure catch (failure) {
          expect(failure.diagnostic.correlationId, 'corr-123');
          expect(
            failure.diagnostic.clipboardText,
            isNot(contains('private-input')),
          );
          expect(
            failure.diagnostic.clipboardText,
            isNot(contains('private@example.test')),
          );
          expect(
            failure.diagnostic.clipboardText,
            isNot(contains('password-secret')),
          );
          expect(
            failure.diagnostic.clipboardText,
            isNot(contains('untrusted-secret')),
          );
        }
      },
    );
  }
  test(
    'invalid success and transport errors expose safe diagnostics',
    () async {
      final (container, repository) = await setup(
        (request) async => http.Response('{}', 200),
      );
      addTearDown(container.dispose);
      await expectLater(repository.list(), throwsA(isA<SupportFailure>()));
      await expectLater(repository.read(7), throwsA(isA<SupportFailure>()));
      await expectLater(
        repository.create(
          subject: 'Ayuda',
          category: 'general',
          description: 'Texto',
        ),
        throwsA(isA<SupportFailure>()),
      );
      final (offline, offlineRepository) = await setup(
        (request) async => throw http.ClientException('secret raw exception'),
      );
      addTearDown(offline.dispose);
      try {
        await offlineRepository.list();
        fail('Expected failure');
      } on SupportFailure catch (failure) {
        expect(failure.diagnostic.code, 'network_error');
        expect(
          failure.diagnostic.clipboardText,
          isNot(contains('secret raw exception')),
        );
      }
    },
  );
}
