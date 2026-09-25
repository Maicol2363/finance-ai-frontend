import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/incomes/domain/income_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryStore implements SecureCredentialStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> replace(String credential) async {}
  @override
  Future<void> delete() async {}
}

class SessionRepository implements AuthSessionRepository {
  @override
  Future<IssuedAuthSession> login(LoginRequest request) async {
    final now = DateTime.now().toUtc();
    return IssuedAuthSession(
      user: const AuthenticatedUser(
        id: 42,
        email: 'test@example.com',
        preferredCurrency: 'COP',
      ),
      accessCredential: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      renewableCredential: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      renewableExpiresAt: now.add(const Duration(days: 30)),
      absoluteExpiresAt: now.add(const Duration(days: 90)),
    );
  }

  @override
  Future<IssuedAuthSession> refresh(String credential) =>
      throw UnimplementedError();
  @override
  Future<AuthenticatedUser> currentUser(String credential) =>
      throw UnimplementedError();
  @override
  Future<void> logout(String credential) async {}
}

Map<String, Object?> incomeJson() => {
  'id': 7,
  'account_id': 3,
  'account_name': 'Efectivo',
  'currency_code': 'COP',
  'amount': '25.50',
  'date': '2026-09-18',
  'description': null,
  'income_source_id': null,
  'income_source_name': null,
  'created_at': '2026-09-17T00:00:00Z',
  'updated_at': '2026-09-17T00:00:00Z',
};

Future<(ProviderContainer, IncomesRepository)> repositoryWith(
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
  final outcome = await session.login(
    email: 'test@example.com',
    password: 'safe-password',
  );
  expect(outcome, LoginSubmitOutcome.success);
  return (container, container.read(incomesRepositoryProvider));
}

void main() {
  test('owned income contract uses authenticated GET POST PUT DELETE and exact money', () async {
    final requests = <http.Request>[];
    final (container, repository) = await repositoryWith((request) async {
      requests.add(request);
      if (request.method == 'DELETE') return http.Response('', 204);
      if (request.method == 'GET' && request.url.path == '/api/v1/incomes') {
        return http.Response(
          jsonEncode({
            'items': [incomeJson()],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode(incomeJson()),
        request.method == 'POST' ? 201 : 200,
      );
    });
    addTearDown(container.dispose);
    final listed = await repository.list(accountId: 3);
    await repository.get(7);
    final command = IncomeWriteCommand(
      accountId: 3,
      amount: MoneyAmount.parseApi('25.50'),
      date: DateTime.utc(2026, 9, 18),
    );
    await repository.create(command);
    await repository.update(7, command);
    await repository.delete(7);
    expect(listed.single.amount.toApiString(), '25.50');
    expect(requests.map((request) => request.method), [
      'GET',
      'GET',
      'POST',
      'PUT',
      'DELETE',
    ]);
    expect(requests.first.url.queryParameters['account_id'], '3');
    expect(
      requests.every(
        (request) =>
            request.headers['Authorization']?.startsWith('Bearer ') == true,
      ),
      isTrue,
    );
    expect(jsonDecode(requests[2].body)['amount'], '25.50');
    expect(jsonDecode(requests[3].body)['income_source_id'], isNull);
  });

  test('server validation maps to safe code and field errors', () async {
    final (container, repository) = await repositoryWith(
      (request) async => http.Response(
        jsonEncode({
          'status': 422,
          'code': 'income_account_unavailable',
          'detail': 'Choose one of your active accounts.',
          'correlation_id': 'income-test-2',
          'field_errors': {
            'account_id': ['Choose one of your active accounts.'],
          },
        }),
        422,
      ),
    );
    addTearDown(container.dispose);
    await expectLater(
      repository.list(),
      throwsA(
        isA<IncomeFailure>().having(
          (failure) => failure.code,
          'code',
          'income_account_unavailable',
        ),
      ),
    );
  });
}
