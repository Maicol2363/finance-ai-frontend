import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const accessOne = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const accessTwo = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const renewable = 'ccccccccccccccccccccccccccccccccccccccccccc';

Map<String, Object?> accountJson({bool isActive = true}) => {
  'id': 11,
  'name': 'Daily cash',
  'type': 'cash',
  'currency': {'id': 1, 'code': 'COP', 'name': 'Colombian Peso', 'decimals': 2},
  'opening_balance': '100000.00',
  'balance': '85000.50',
  'currency_is_locked': true,
  'is_active': isActive,
  'created_at': '2026-09-08T01:00:00Z',
  'updated_at': '2026-09-08T02:00:00Z',
};

Map<String, Object?> listJson() => {
  'accounts': [accountJson()],
  'suggested_currency_code': 'COP',
  'supported_currencies': [accountJson()['currency']],
  'account_types': [
    'cash',
    'bank',
    'digital_wallet',
    'savings',
    'credit_card',
    'other',
  ],
};

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

Future<(ProviderContainer, AccountsRepository, SessionRepository)>
repositoryWith(Future<http.Response> Function(http.Request) handler) async {
  final sessions = SessionRepository();
  final container = ProviderContainer(
    overrides: [
      httpClientProvider.overrideWithValue(MockClient(handler)),
      authSessionRepositoryProvider.overrideWithValue(sessions),
      secureCredentialStoreProvider.overrideWithValue(MemoryStore()),
    ],
  );
  final session = container.read(authSessionControllerProvider.notifier);
  await Future<void>.delayed(Duration.zero);
  final outcome = await session.login(
    email: 'person@example.com',
    password: 'safe-password',
  );
  expect(outcome, LoginSubmitOutcome.success);
  return (container, container.read(accountsRepositoryProvider), sessions);
}

void main() {
  test(
    'uses authenticated GET, POST, PATCH, and DELETE account contracts',
    () async {
      final requests = <http.Request>[];
      final setup = await repositoryWith((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/api/v1/accounts') {
          return http.Response(jsonEncode(listJson()), 200);
        }
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode(
            accountJson(
              isActive:
                  !(request.url.path.endsWith('/status') &&
                      jsonDecode(request.body)['is_active'] == false),
            ),
          ),
          request.method == 'POST' ? 201 : 200,
        );
      });
      final (container, repository, _) = setup;
      addTearDown(container.dispose);

      await repository.list(includeInactive: true);
      await repository.get(11);
      await repository.create(
        AccountCreateCommand(
          name: 'Daily cash',
          type: AccountType.cash,
          currencyCode: 'COP',
          openingBalance: MoneyAmount.parseApi('100000.00'),
        ),
      );
      await repository.update(11, AccountUpdateCommand(name: 'Pocket cash'));
      final inactive = await repository.setActive(11, isActive: false);
      await repository.deleteAccount(11);

      expect(requests[0].url.queryParameters['include_inactive'], 'true');
      expect(requests.map((request) => request.method), [
        'GET',
        'GET',
        'POST',
        'PATCH',
        'PATCH',
        'DELETE',
      ]);
      expect(
        requests.every(
          (request) => request.headers['Authorization'] == 'Bearer $accessOne',
        ),
        isTrue,
      );
      expect(jsonDecode(requests[2].body)['opening_balance'], '100000.00');
      expect(requests[4].url.path, '/api/v1/accounts/11/status');
      expect(requests[5].url.path, '/api/v1/accounts/11');
      expect(inactive.isActive, isFalse);
    },
  );

  test('delete refreshes one expired session and retries once', () async {
    final credentials = <String?>[];
    var calls = 0;
    final setup = await repositoryWith((request) async {
      calls += 1;
      credentials.add(request.headers['Authorization']);
      if (calls == 1) {
        return http.Response(
          jsonEncode({
            'status': 401,
            'code': 'session_invalid',
            'detail': 'Please log in again.',
            'correlation_id': 'expired-delete',
          }),
          401,
        );
      }
      return http.Response('', 204);
    });
    final (container, repository, sessions) = setup;
    addTearDown(container.dispose);

    await repository.deleteAccount(11);

    expect(sessions.refreshes, 1);
    expect(credentials, ['Bearer $accessOne', 'Bearer $accessTwo']);
  });

  test('maps blocked deletion to safe actionable failure', () async {
    final setup = await repositoryWith((_) async {
      return http.Response(
        jsonEncode({
          'status': 409,
          'code': 'account_delete_blocked',
          'detail': 'Synthetic server detail.',
          'correlation_id': 'blocked-delete',
        }),
        409,
      );
    });
    final (container, repository, _) = setup;
    addTearDown(container.dispose);

    await expectLater(
      repository.deleteAccount(11),
      throwsA(
        isA<AccountFailure>()
            .having((failure) => failure.code, 'code', 'account_delete_blocked')
            .having(
              (failure) => failure.userMessage,
              'safe direction',
              contains('Deactivate'),
            ),
      ),
    );
  });

  test('one 401 refreshes the session and retries with new access', () async {
    final credentials = <String?>[];
    var calls = 0;
    final setup = await repositoryWith((request) async {
      calls += 1;
      credentials.add(request.headers['Authorization']);
      if (calls == 1) {
        return http.Response(
          jsonEncode({
            'status': 401,
            'code': 'session_invalid',
            'detail': 'Please log in again.',
            'correlation_id': 'expired-access',
          }),
          401,
        );
      }
      return http.Response(jsonEncode(listJson()), 200);
    });
    final (container, repository, sessions) = setup;
    addTearDown(container.dispose);

    final result = await repository.list(includeInactive: false);

    expect(result.accounts.single.id, 11);
    expect(sessions.refreshes, 1);
    expect(credentials, ['Bearer $accessOne', 'Bearer $accessTwo']);
  });

  test('maps field conflicts without copying financial input', () async {
    final setup = await repositoryWith((_) async {
      return http.Response(
        jsonEncode({
          'status': 409,
          'code': 'account_name_conflict',
          'detail': 'Choose a different name.',
          'correlation_id': 'account-conflict',
          'field_errors': {
            'name': ['An active account already uses this name.'],
          },
        }),
        409,
      );
    });
    final (container, repository, _) = setup;
    addTearDown(container.dispose);

    await expectLater(
      repository.create(
        AccountCreateCommand(
          name: 'Private platinum account',
          type: AccountType.bank,
          currencyCode: 'COP',
          openingBalance: MoneyAmount.parseApi('987654.32'),
        ),
      ),
      throwsA(
        isA<AccountFailure>()
            .having((failure) => failure.code, 'code', 'account_name_conflict')
            .having(
              (failure) => failure.userMessage,
              'safe message',
              isNot(contains('Private platinum account')),
            )
            .having(
              (failure) => failure.userMessage,
              'financial value excluded',
              isNot(contains('987654.32')),
            ),
      ),
    );
  });

  test(
    'transport loss marks mutation outcome uncertain and retryable',
    () async {
      final setup = await repositoryWith((request) async {
        throw http.ClientException('private network details', request.url);
      });
      final (container, repository, _) = setup;
      addTearDown(container.dispose);

      await expectLater(
        repository.update(
          11,
          AccountUpdateCommand(openingBalance: MoneyAmount.parseApi('-777.00')),
        ),
        throwsA(
          isA<AccountFailure>()
              .having((failure) => failure.code, 'code', 'network_unavailable')
              .having(
                (failure) => failure.isMutationOutcomeUncertain,
                'uncertain outcome',
                isTrue,
              )
              .having(
                (failure) => failure.userMessage,
                'private details excluded',
                isNot(contains('private network details')),
              )
              .having(
                (failure) => failure.userMessage,
                'amount excluded',
                isNot(contains('-777.00')),
              ),
        ),
      );
    },
  );

  test('malformed 200 account response becomes a safe failure', () async {
    final setup = await repositoryWith(
      (_) async =>
          http.Response(jsonEncode({...accountJson()}..remove('balance')), 200),
    );
    final (container, repository, _) = setup;
    addTearDown(container.dispose);

    await expectLater(
      repository.get(11),
      throwsA(
        isA<AccountFailure>().having(
          (failure) => failure.code,
          'code',
          'unexpected_response',
        ),
      ),
    );
  });
}
