import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/budgets/data/budgets_repository.dart';
import 'package:finance_ai/features/budgets/domain/budget_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../budget_test_helpers.dart';

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
    final now = DateTime.utc(2026, 9, 12);
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

Future<(ProviderContainer, BudgetsRepository)> repositoryWith(
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
  return (container, container.read(budgetsRepositoryProvider));
}

void main() {
  test('uses authenticated list and CRUD contracts with exact money', () async {
    final requests = <http.Request>[];
    final setup = await repositoryWith((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode(budgetListJson()), 200);
      }
      if (request.method == 'DELETE') return http.Response('', 204);
      return http.Response(
        jsonEncode(budgetJson()),
        request.method == 'POST' ? 201 : 200,
      );
    });
    final (container, repository) = setup;
    addTearDown(container.dispose);
    final command = BudgetCreateCommand(
      categoryId: 4,
      amount: MoneyAmount.parseApi('1234.50'),
      currencyCode: 'COP',
      period: BudgetPeriod.weekly,
    );

    final result = await repository.list();
    await repository.create(command);
    await repository.update(7, command);
    await repository.deleteBudget(7);

    expect(result.budgets.single.id, 7);
    expect(requests.map((item) => item.method), [
      'GET',
      'POST',
      'PATCH',
      'DELETE',
    ]);
    expect(requests.map((item) => item.url.path), [
      '/api/v1/budgets',
      '/api/v1/budgets',
      '/api/v1/budgets/7',
      '/api/v1/budgets/7',
    ]);
    expect(
      requests.every(
        (item) => item.headers['Authorization'] == 'Bearer $accessCredential',
      ),
      isTrue,
    );
    expect(jsonDecode(requests[1].body), {
      'category_id': 4,
      'amount': '1234.50',
      'currency_code': 'COP',
      'period': 'weekly',
    });
  });

  test('maps controlled server errors without copying private input', () async {
    final setup = await repositoryWith(
      (_) async => http.Response(
        jsonEncode({
          'status': 422,
          'code': 'budget_category_unavailable',
          'detail': 'Synthetic detail',
          'correlation_id': 'budget-category',
          'field_errors': {
            'category_id': ['Not owned.'],
          },
        }),
        422,
      ),
    );
    final (container, repository) = setup;
    addTearDown(container.dispose);

    await expectLater(
      repository.create(
        BudgetCreateCommand(
          categoryId: 999,
          amount: MoneyAmount.parseApi('987654.32'),
          currencyCode: 'COP',
          period: BudgetPeriod.monthly,
        ),
      ),
      throwsA(
        isA<BudgetFailure>()
            .having((item) => item.code, 'code', 'budget_category_unavailable')
            .having(
              (item) => item.userMessage,
              'controlled message',
              'Selecciona una de tus categorías.',
            )
            .having(
              (item) => item.userMessage,
              'private amount omitted',
              isNot(contains('987654')),
            ),
      ),
    );
  });

  test('transport and malformed success responses fail safely', () async {
    final network = await repositoryWith((request) async {
      throw http.ClientException('private network path', request.url);
    });
    addTearDown(network.$1.dispose);
    await expectLater(
      network.$2.deleteBudget(7),
      throwsA(
        isA<BudgetFailure>()
            .having((item) => item.code, 'code', 'network_unavailable')
            .having(
              (item) => item.isMutationOutcomeUncertain,
              'uncertain',
              isTrue,
            )
            .having(
              (item) => item.userMessage,
              'safe',
              isNot(contains('private network path')),
            ),
      ),
    );

    final malformed = await repositoryWith(
      (_) async =>
          http.Response(jsonEncode({...budgetJson()}..remove('amount')), 201),
    );
    addTearDown(malformed.$1.dispose);
    await expectLater(
      malformed.$2.create(
        BudgetCreateCommand(
          categoryId: 4,
          amount: MoneyAmount.parseApi('10.00'),
          currencyCode: 'COP',
          period: BudgetPeriod.monthly,
        ),
      ),
      throwsA(
        isA<BudgetFailure>().having(
          (item) => item.code,
          'code',
          'unexpected_response',
        ),
      ),
    );
  });
}
