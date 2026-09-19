import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const accessOne = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const accessTwo = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const renewable = 'ccccccccccccccccccccccccccccccccccccccccccc';

Map<String, Object?> expenseJson({int id = 7}) => {
  'id': id,
  'transaction_id': 8,
  'receipt_id': 9,
  'name': 'Groceries',
  'amount': '25.00',
  'quantity': '1.000',
  'unit_price': '25.00',
  'note': 'Weekly food',
  'category': {'id': 3, 'name': 'Food'},
  'receipt_name': 'Market',
  'receipt_note': 'Household purchase',
  'store': 'Market',
  'description': 'Purchase at Market',
  'occurred_at': '2026-09-17T12:30:00Z',
  'status': 'confirmed',
  'capture_source': 'manual',
  'account_id': 11,
  'account_name': 'Cash',
  'account_is_active': true,
  'currency': {'id': 1, 'code': 'COP', 'name': 'Colombian Peso', 'decimals': 2},
  'currency_code': 'COP',
  'created_at': '2026-09-17T12:30:00Z',
  'updated_at': '2026-09-17T12:30:00Z',
  'receipt_image': 'receipt.jpg',
  'image_path': 'expense.jpg',
};

Map<String, Object?> historyJson() => {
  'items': [
    {
      'id': 8,
      'type': 'expense',
      'status': 'confirmed',
      'occurred_at': '2026-09-17T12:30:00Z',
      'description': 'Purchase at Market',
      'capture_source': 'manual',
      'income_source': null,
      'movements': [
        {
          'account_id': 11,
          'account_name': 'Cash',
          'amount': '-25.00',
          'currency': {
            'id': 1,
            'code': 'COP',
            'name': 'Colombian Peso',
            'decimals': 2,
          },
          'currency_code': 'COP',
        },
      ],
      'expense': null,
    },
  ],
  'total': 1,
  'page': 1,
  'page_size': 50,
  'has_next': false,
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

Future<(ProviderContainer, ExpensesRepository, SessionRepository)>
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
  return (container, container.read(expensesRepositoryProvider), sessions);
}

void main() {
  test(
    'uses authenticated GET, PATCH, DELETE expense and history contracts',
    () async {
      final requests = <http.Request>[];
      final setup = await repositoryWith((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/api/v1/expenses') {
          return http.Response(
            jsonEncode({
              'items': [expenseJson()],
              'total': 1,
              'page': 2,
              'page_size': 10,
              'has_next': false,
            }),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/history') {
          return http.Response(jsonEncode(historyJson()), 200);
        }
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return http.Response(jsonEncode(expenseJson()), 200);
      });
      final (container, repository, _) = setup;
      addTearDown(container.dispose);

      final listed = await repository.list(page: 2, pageSize: 10);
      final detail = await repository.get(7);
      final updated = await repository.update(
        7,
        ExpenseUpdateCommand(amount: MoneyAmount.parseApi('30.00')),
      );
      await repository.deleteExpense(7);
      final history = await repository.history(
        const HistoryFilters(type: TransactionType.expense),
      );

      expect(listed.items.single.id, 7);
      expect(detail.currencyCode, 'COP');
      expect(updated.amount, MoneyAmount.parseApi('25.00'));
      expect(history.items.single.type, TransactionType.expense);
      expect(requests.map((request) => request.method), [
        'GET',
        'GET',
        'PATCH',
        'DELETE',
        'GET',
      ]);
      expect(
        requests.every(
          (request) => request.headers['Authorization'] == 'Bearer $accessOne',
        ),
        isTrue,
      );
      expect(requests[0].url.queryParameters['page'], '2');
      expect(requests[0].url.queryParameters['page_size'], '10');
      expect(jsonDecode(requests[2].body)['amount'], '30.00');
      expect(requests[3].url.path, '/api/v1/expenses/7');
      expect(requests[4].url.queryParameters['type'], 'expense');
    },
  );

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
      return http.Response(
        jsonEncode({
          'items': [expenseJson()],
          'total': 1,
          'page': 1,
          'page_size': 50,
          'has_next': false,
        }),
        200,
      );
    });
    final (container, repository, sessions) = setup;
    addTearDown(container.dispose);

    final result = await repository.list();

    expect(result.items.single.id, 7);
    expect(sessions.refreshes, 1);
    expect(credentials, ['Bearer $accessOne', 'Bearer $accessTwo']);
  });

  test(
    'maps missing and locked expenses to safe actionable failures',
    () async {
      final missingSetup = await repositoryWith((_) async {
        return http.Response(
          jsonEncode({
            'status': 404,
            'code': 'expense_not_found',
            'detail': 'The requested expense is unavailable.',
            'correlation_id': 'missing-expense',
          }),
          404,
        );
      });
      final (missingContainer, missingRepository, _) = missingSetup;
      addTearDown(missingContainer.dispose);

      await expectLater(
        missingRepository.get(999),
        throwsA(
          isA<ExpenseFailure>()
              .having((failure) => failure.code, 'code', 'expense_not_found')
              .having(
                (failure) => failure.correlationId,
                'correlation',
                'missing-expense',
              ),
        ),
      );

      final lockedSetup = await repositoryWith((_) async {
        return http.Response(
          jsonEncode({
            'status': 409,
            'code': 'expense_not_editable',
            'detail': 'Only confirmed expenses can be edited or deleted.',
            'correlation_id': 'locked-expense',
          }),
          409,
        );
      });
      final (lockedContainer, lockedRepository, _) = lockedSetup;
      addTearDown(lockedContainer.dispose);

      await expectLater(
        lockedRepository.deleteExpense(7),
        throwsA(
          isA<ExpenseFailure>()
              .having((failure) => failure.code, 'code', 'expense_not_editable')
              .having(
                (failure) => failure.userMessage,
                'safe direction',
                contains('confirmados'),
              ),
        ),
      );
    },
  );

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
          7,
          ExpenseUpdateCommand(amount: MoneyAmount.parseApi('-777.00')),
        ),
        throwsA(
          isA<ExpenseFailure>()
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

  test('malformed 200 expense response becomes a safe failure', () async {
    final setup = await repositoryWith(
      (_) async =>
          http.Response(jsonEncode({...expenseJson()}..remove('amount')), 200),
    );
    final (container, repository, _) = setup;
    addTearDown(container.dispose);

    await expectLater(
      repository.get(7),
      throwsA(
        isA<ExpenseFailure>().having(
          (failure) => failure.code,
          'code',
          'unexpected_response',
        ),
      ),
    );
  });
}
