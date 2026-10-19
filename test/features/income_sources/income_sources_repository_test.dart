import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/income_sources/data/income_sources_repository.dart';
import 'package:finance_ai/features/income_sources/domain/income_source_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

FinanceApiClient apiClient(MockClient mock) => FinanceApiClient(
  mock,
  Uri.parse('http://localhost:8000'),
  const Duration(seconds: 5),
);

http.Response jsonResponse(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('list sends the bearer credential and parses items', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return jsonResponse({
        'items': [
          {'id': 1, 'name': 'Salary'},
        ],
      }, 200);
    });

    final items = await HttpIncomeSourcesRepository(apiClient(mock))
        .list(accessCredential: 'token');

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/income-sources');
    expect(captured.headers['Authorization'], 'Bearer token');
    expect(items.single, isA<IncomeSource>());
    expect(items.single.name, 'Salary');
  });

  test('create maps a duplicate name to a conflict failure', () async {
    final mock = MockClient(
      (request) async => jsonResponse({
        'status': 409,
        'code': 'income_source_name_taken',
        'detail': 'You already have an income source with this name.',
        'correlation_id': 'abc',
      }, 409),
    );

    await expectLater(
      HttpIncomeSourcesRepository(apiClient(mock))
          .create(accessCredential: 't', name: 'Salary'),
      throwsA(isA<IncomeSourcesConflictFailure>()),
    );
  });

  test(
    'does not expose server detail or field values in validation failures',
    () async {
      final mock = MockClient(
        (_) async => jsonResponse({
          'status': 422,
          'code': 'income_source_invalid',
          'detail': 'password=private-value',
          'field_errors': {
            'name': ['private-account-name'],
          },
        }, 422),
      );

      await expectLater(
        HttpIncomeSourcesRepository(apiClient(mock))
            .create(accessCredential: 't', name: 'private-account-name'),
        throwsA(
          isA<IncomeSourcesValidationFailure>()
              .having(
                (failure) => failure.userMessage,
                'message',
                isNot(contains('private-value')),
              )
              .having(
                (failure) => failure.fieldErrors['name']?.single,
                'field error',
                isNot(contains('private-account-name')),
              ),
        ),
      );
    },
  );

  test(
    'does not pass an unknown server error code or detail to the UI',
    () async {
      final mock = MockClient(
        (_) async => jsonResponse({
          'status': 500,
          'code': 'private-internal-code',
          'detail': 'token=private-value',
        }, 500),
      );

      await expectLater(
        HttpIncomeSourcesRepository(apiClient(mock))
            .list(accessCredential: 't'),
        throwsA(
          isA<IncomeSourcesRetryableFailure>()
              .having((failure) => failure.code, 'code', 'unexpected_response')
              .having(
                (failure) => failure.userMessage,
                'message',
                isNot(contains('private-value')),
              ),
        ),
      );
    },
  );

  test('rename maps a missing id to a not-found failure', () async {
    final mock = MockClient(
      (request) async => jsonResponse({
        'status': 404,
        'code': 'income_source_not_found',
        'detail': 'This income source does not exist.',
        'correlation_id': 'abc',
      }, 404),
    );

    await expectLater(
      HttpIncomeSourcesRepository(apiClient(mock))
          .rename(accessCredential: 't', id: 9, name: 'X'),
      throwsA(isA<IncomeSourcesNotFoundFailure>()),
    );
  });

  test('delete resolves on 204 without a body', () async {
    late http.Request captured;
    final mock = MockClient((request) async {
      captured = request;
      return http.Response('', 204);
    });

    await HttpIncomeSourcesRepository(apiClient(mock))
        .delete(accessCredential: 'token', id: 3);

    expect(captured.method, 'DELETE');
    expect(captured.url.path, '/api/v1/income-sources/3');
  });
}
