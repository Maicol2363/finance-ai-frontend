import 'dart:async';
import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/text_capture/data/text_capture_repository.dart';
import 'package:finance_ai/features/text_capture/domain/text_capture_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../text_capture_test_support.dart';

class _Session extends AuthSessionController {
  @override
  Future<T> runProtected<T>(
    Future<T> Function(String accessCredential) request,
  ) => request('access-token');
}

HttpTextCaptureRepository repositoryFor(MockClient client) =>
    HttpTextCaptureRepository(
      FinanceApiClient(
        client,
        Uri.parse('http://localhost:8000'),
        const Duration(seconds: 5),
      ),
      _Session(),
    );

http.Response json(Object body, int status, {String correlation = 'srv-1'}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {
        'content-type': 'application/json',
        'x-correlation-id': correlation,
      },
    );

Map<String, Object?> problem(String code, int status) => {
  'type': 'about:blank',
  'title': 'x',
  'status': status,
  'code': code,
  'detail': 'Internal detail that must not be shown',
  'correlation_id': 'corr-xyz',
};

Future<TextCaptureFailure> failureOf(Future<Object?> call) async {
  try {
    await call;
  } on TextCaptureFailure catch (failure) {
    return failure;
  }
  throw StateError('expected a TextCaptureFailure');
}

void main() {
  final now = DateTime(2026, 10, 2, 15, 30, 5);

  test('isoWithOffset keeps the user local day and carries the UTC offset', () {
    final text = isoWithOffset(now);

    expect(text, startsWith('2026-10-02T15:30:05'));
    expect(text, matches(RegExp(r'[+-]\d{2}:\d{2}$')));
    expect(DateTime.parse(text).toUtc(), now.toUtc());
  });

  group('propose', () {
    test('sends the text with auth, the offset time and no proposal', () async {
      late http.Request seen;
      final repository = repositoryFor(
        MockClient((request) async {
          seen = request;
          return json(proposalJson(), 201);
        }),
      );

      final result = await repository.propose(clientNow: now, text: 'gasté 5');

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/capture/text/proposals');
      expect(seen.headers['Authorization'], 'Bearer access-token');
      expect(seen.headers['X-Correlation-ID'], isNotEmpty);
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body.keys, unorderedEquals(['text', 'client_now']));
      expect(body['text'], 'gasté 5');
      expect(body['client_now'], isoWithOffset(now));
      expect(result.proposalId, '11111111-1111-4111-8111-111111111111');
    });

    test(
      'a correction carries the proposal id and a choice carries its answer',
      () async {
        final bodies = <Map<String, Object?>>[];
        final repository = repositoryFor(
          MockClient((request) async {
            bodies.add(jsonDecode(request.body) as Map<String, Object?>);
            return json(proposalJson(), 201);
          }),
        );

        await repository.propose(
          clientNow: now,
          text: 'fue con Nequi',
          proposalId: 'abc',
        );
        await repository.propose(
          clientNow: now,
          proposalId: 'abc',
          choice: (field: 'account', value: '2'),
        );

        expect(bodies[0]['proposal_id'], 'abc');
        expect(bodies[0].containsKey('choice'), isFalse);
        expect(bodies[1].containsKey('text'), isFalse);
        expect(bodies[1]['choice'], {'field': 'account', 'value': '2'});
      },
    );

    test('a provider outage becomes a safe retryable message with the server correlation', () async {
      final repository = repositoryFor(
        MockClient(
          (_) async => json(problem('text_capture_unavailable', 503), 503),
        ),
      );

      final failure = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );

      expect(failure.code, 'text_capture_unavailable');
      expect(failure.isRetryable, isTrue);
      expect(failure.correlationId, 'corr-xyz');
      expect(failure.userMessage, contains('formulario manual'));
      expect(failure.userMessage, isNot(contains('Internal detail')));
      expect(failure.technicalReason, 'http_503');
    });

    test('a server without an AI key says so and is not retryable', () async {
      final repository = repositoryFor(
        MockClient(
          (_) async => json(problem('text_capture_not_configured', 503), 503),
        ),
      );

      final failure = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );

      expect(failure.code, 'text_capture_not_configured');
      expect(failure.isRetryable, isFalse);
      expect(failure.userMessage, contains('no está configurado'));
      expect(failure.userMessage, contains('formulario manual'));
    });

    test('rate limiting and stale drafts get their own guidance', () async {
      final answers = [
        json(problem('text_capture_rate_limited', 429), 429),
        json(problem('text_proposal_not_found', 404), 404),
        json(problem('text_proposal_closed', 409), 409),
        json(problem('request_invalid', 422), 422),
      ];
      final repository = repositoryFor(
        MockClient((_) async => answers.removeAt(0)),
      );

      final limited = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );
      final missing = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );
      final closed = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );
      final invalid = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );

      expect(limited.isRetryable, isTrue);
      expect(limited.userMessage, contains('Espera'));
      expect(missing.isRetryable, isFalse);
      expect(missing.userMessage, contains('Escribe tu mensaje de nuevo'));
      expect(closed.isRetryable, isFalse);
      expect(invalid.isRetryable, isFalse);
    });

    test('network, timeout and garbage responses have stable codes', () async {
      final outcomes = <Object>[
        http.ClientException('boom'),
        TimeoutException('slow'),
        http.Response('not json', 201),
        json({'unexpected': true}, 201),
      ];
      final repository = repositoryFor(
        MockClient((_) async {
          final next = outcomes.removeAt(0);
          if (next is Exception) throw next;
          return next as http.Response;
        }),
      );

      final network = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );
      final timeout = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );
      final garbage = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );
      final shape = await failureOf(
        repository.propose(clientNow: now, text: 'x'),
      );

      expect(network.code, 'network_unavailable');
      expect(timeout.code, 'request_timeout');
      expect(timeout.technicalReason, 'request_timeout');
      expect(garbage.code, 'unexpected_response');
      expect(shape.code, 'unexpected_response');
      expect(shape.technicalReason, 'invalid_text_capture_payload');
    });

    test('a rejected session is reported as an invalid session', () async {
      final repository = repositoryFor(
        MockClient(
          (_) async => json(problem('authentication_required', 401), 401),
        ),
      );

      expect(
        repository.propose(clientNow: now, text: 'x'),
        throwsA(isA<InvalidSessionFailure>()),
      );
    });
  });

  group('confirm', () {
    final command = TextProposalConfirmCommand(
      intent: CaptureIntent.expense,
      amount: '15900.00',
      date: DateTime(2026, 10, 2),
      accountId: 1,
    );

    Map<String, Object?> confirmed({bool replayed = false}) => {
      'proposal_id': '11111111-1111-4111-8111-111111111111',
      'intent': 'expense',
      'record_id': 701,
      'amount': '15900.00',
      'currency_code': 'COP',
      'date': '2026-10-02',
      'description': 'Gasto',
      'account_name': 'Efectivo',
      'replayed': replayed,
    };

    test(
      'posts the edited values and accepts both 201 and the 200 replay',
      () async {
        final seen = <http.Request>[];
        final answers = [
          json(confirmed(), 201),
          json(confirmed(replayed: true), 200),
        ];
        final repository = repositoryFor(
          MockClient((request) async {
            seen.add(request);
            return answers.removeAt(0);
          }),
        );

        final first = await repository.confirm('abc', command);
        final replay = await repository.confirm('abc', command);

        expect(
          seen.first.url.path,
          '/api/v1/capture/text/proposals/abc/confirm',
        );
        expect(jsonDecode(seen.first.body), command.toJson());
        expect(first.replayed, isFalse);
        expect(replay.replayed, isTrue);
        expect(replay.recordId, first.recordId);
      },
    );

    test('a lost connection says the retry will not duplicate', () async {
      final repository = repositoryFor(
        MockClient((_) async => throw http.ClientException('down')),
      );

      final failure = await failureOf(repository.confirm('abc', command));

      expect(failure.isMutationOutcomeUncertain, isTrue);
      expect(failure.userMessage, contains('no se duplicará'));
    });

    test(
      'the manual validation messages are reused for rejected values',
      () async {
        final answers = [
          json(problem('expense_account_invalid', 422), 422),
          json(problem('transfer_same_account', 422), 422),
          json(problem('transfer_destination_amount_required', 422), 422),
        ];
        final repository = repositoryFor(
          MockClient((_) async => answers.removeAt(0)),
        );

        final account = await failureOf(repository.confirm('abc', command));
        final same = await failureOf(repository.confirm('abc', command));
        final amount = await failureOf(repository.confirm('abc', command));

        expect(account.userMessage, contains('cuenta'));
        expect(same.userMessage, contains('dos cuentas distintas'));
        expect(amount.userMessage, contains('monto que llega'));
        expect([account, same, amount].every((f) => !f.isRetryable), isTrue);
      },
    );
  });

  test('discard accepts 204 and surfaces a missing draft', () async {
    final answers = [
      http.Response('', 204),
      json(problem('text_proposal_not_found', 404), 404),
    ];
    final paths = <String>[];
    final repository = repositoryFor(
      MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        return answers.removeAt(0);
      }),
    );

    await repository.discard('abc');
    final failure = await failureOf(repository.discard('abc'));

    expect(paths, everyElement('DELETE /api/v1/capture/text/proposals/abc'));
    expect(failure.code, 'text_proposal_not_found');
  });
}
