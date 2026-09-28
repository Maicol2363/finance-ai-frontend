import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/transfers/data/transfers_repository.dart';
import 'package:finance_ai/features/transfers/domain/transfer_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const accessOne = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const renewable = 'ccccccccccccccccccccccccccccccccccccccccccc';

Map<String, Object?> transferJson() => {
  'id': 9,
  'source_account': {'id': 3, 'name': 'Cash', 'currency_code': 'COP'},
  'source_amount': '100.00',
  'destination_account': {'id': 4, 'name': 'Savings', 'currency_code': 'COP'},
  'destination_amount': '100.00',
  'date': '2026-09-18',
  'description': null,
  'created_at': '2026-09-18T12:00:00Z',
  'updated_at': '2026-09-18T12:00:00Z',
};

IssuedAuthSession issued() {
  final now = DateTime.utc(2026, 9, 18);
  return IssuedAuthSession(
    user: const AuthenticatedUser(
      id: 42,
      email: 'person@example.com',
      preferredCurrency: 'COP',
    ),
    accessCredential: accessOne,
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
  @override
  Future<IssuedAuthSession> login(LoginRequest request) async => issued();

  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async =>
      issued();

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async =>
      issued().user;

  @override
  Future<void> logout(String renewableCredential) async {}
}

Future<(ProviderContainer, TransfersRepository)> repositoryWith(
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
    email: 'person@example.com',
    password: 'safe-password',
  );
  expect(outcome, LoginSubmitOutcome.success);
  return (container, container.read(transfersRepositoryProvider));
}

TransferCreateCommand command() => TransferCreateCommand(
  sourceAccountId: 3,
  destinationAccountId: 4,
  sourceAmount: MoneyAmount.parseApi('100.00'),
  destinationAmount: null,
  date: DateTime.utc(2026, 9, 18),
  description: null,
);

void main() {
  test('posts the transfer contract and decodes both amounts', () async {
    http.Request? sent;
    final setup = await repositoryWith((request) async {
      sent = request;
      return http.Response(jsonEncode(transferJson()), 201);
    });
    final (container, repository) = setup;
    addTearDown(container.dispose);

    final transfer = await repository.create(command());

    expect(sent?.method, 'POST');
    expect(sent?.url.path, '/api/v1/transfers');
    expect(sent?.headers['Authorization'], 'Bearer $accessOne');
    final body = jsonDecode(sent!.body) as Map<String, Object?>;
    expect(body['source_account_id'], 3);
    expect(body['source_amount'], '100.00');
    expect(body.containsKey('destination_amount'), isFalse);
    expect(transfer.sourceAmount, MoneyAmount.parseApi('100.00'));
    expect(transfer.destinationAmount, MoneyAmount.parseApi('100.00'));
  });

  test('maps transfer failures to safe actionable failures', () async {
    for (final entry in {
      'transfer_same_account': 'distintas',
      'transfer_account_unavailable': 'activas',
      'transfer_destination_amount_required': 'llega',
      'transfer_source_destination_mismatch': 'igual',
    }.entries) {
      final setup = await repositoryWith((_) async {
        return http.Response(
          jsonEncode({
            'status': 422,
            'code': entry.key,
            'detail': 'Synthetic server detail.',
            'correlation_id': 'transfer-case',
          }),
          422,
        );
      });
      final (container, repository) = setup;
      addTearDown(container.dispose);

      await expectLater(
        repository.create(command()),
        throwsA(
          isA<TransferFailure>()
              .having((failure) => failure.code, 'code', entry.key)
              .having(
                (failure) => failure.userMessage,
                'safe direction',
                contains(entry.value),
              ),
        ),
      );
    }
  });

  test('transport loss marks creation outcome uncertain', () async {
    final setup = await repositoryWith((request) async {
      throw http.ClientException('private network details', request.url);
    });
    final (container, repository) = setup;
    addTearDown(container.dispose);

    await expectLater(
      repository.create(command()),
      throwsA(
        isA<TransferFailure>()
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
            ),
      ),
    );
  });

  test('malformed 201 response becomes a safe failure', () async {
    final setup = await repositoryWith(
      (_) async =>
          http.Response(jsonEncode({...transferJson()}..remove('id')), 201),
    );
    final (container, repository) = setup;
    addTearDown(container.dispose);

    await expectLater(
      repository.create(command()),
      throwsA(
        isA<TransferFailure>().having(
          (failure) => failure.code,
          'code',
          'unexpected_response',
        ),
      ),
    );
  });
}
