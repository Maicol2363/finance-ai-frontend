import 'dart:async';

import 'package:finance_ai/core/state/financial_data_revision.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/text_capture/application/text_capture_controller.dart';
import 'package:finance_ai/features/text_capture/application/text_capture_state.dart';
import 'package:finance_ai/features/text_capture/domain/text_capture_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../text_capture_test_support.dart';

ProviderContainer containerFor(
  FakeTextCaptureRepository repository, {
  FakeExpensesRepository? expenses,
  FakeAccountsRepository? accountsRepository,
  FakeBudgetsController? budgetsController,
  int userId = 1,
}) {
  final container = ProviderContainer(
    overrides: baseOverrides(
      repository: repository,
      expensesRepository: expenses,
      accountsRepository: accountsRepository,
      budgetsController: budgetsController,
      userId: userId,
    ),
  );
  addTearDown(container.dispose);
  return container;
}

TextCaptureController controllerOf(ProviderContainer container) =>
    container.read(textCaptureControllerProvider.notifier);

TextCaptureChatState stateOf(ProviderContainer container) =>
    container.read(textCaptureControllerProvider);

const taskText = 'Almorcé en Subway 15900 con efectivo';

TextProposalConfirmCommand command({
  CaptureIntent intent = CaptureIntent.expense,
}) => TextProposalConfirmCommand(
  intent: intent,
  amount: '15900.00',
  date: DateTime(2026, 10, 2),
  accountId: 1,
  description: 'Almuerzo en Subway',
  categoryId: 10,
);

void main() {
  test('starts with the assistant welcome and nothing proposed', () {
    final container = containerFor(FakeTextCaptureRepository());

    final state = stateOf(container);

    expect(state.entries, hasLength(1));
    expect(state.entries.single, isA<AssistantMessage>());
    expect((state.entries.single as AssistantMessage).text, welcomeMessage);
    expect(state.isBusy, isFalse);
    expect(state.activeProposalId, isNull);
  });

  test('a message becomes a proposal and nothing is saved', () async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    final container = containerFor(repository);

    await controllerOf(container).send('  $taskText  ');

    final entries = stateOf(container).entries;
    expect(entries.whereType<UserMessage>().single.text, taskText);
    final card = entries.whereType<ProposalEntry>().single;
    expect(card.proposal.isReady, isTrue);
    expect(card.proposal.oneTap, isTrue);
    expect(entries.whereType<ThinkingEntry>(), isEmpty);
    expect(stateOf(container).isBusy, isFalse);
    expect(stateOf(container).activeProposalId, card.proposal.proposalId);
    expect(repository.confirmCalls, isEmpty);
    expect(repository.proposeCalls.single.text, taskText);
    expect(repository.proposeCalls.single.proposalId, isNull);
  });

  test('blank messages and sends while busy are ignored', () async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    repository.gate = Completer<void>();
    final container = containerFor(repository);

    await controllerOf(container).send('   ');
    expect(repository.proposeCalls, isEmpty);

    final first = controllerOf(container).send(taskText);
    await Future<void>.delayed(Duration.zero);
    expect(stateOf(container).isBusy, isTrue);
    expect(stateOf(container).entries.last, isA<ThinkingEntry>());
    await controllerOf(container).send('otro mensaje');
    expect(repository.proposeCalls, hasLength(1));

    repository.gate!.complete();
    await first;
    expect(stateOf(container).isBusy, isFalse);
  });

  test(
    'a typed correction reuses the open proposal and replaces its card',
    () async {
      final repository = FakeTextCaptureRepository(
        proposals: [
          proposal(),
          proposal(revision: 2, amount: '20000.00'),
        ],
      );
      final container = containerFor(repository);
      await controllerOf(container).send(taskText);

      await controllerOf(container).send('mejor fueron 20 mil');

      final call = repository.proposeCalls.last;
      expect(call.text, 'mejor fueron 20 mil');
      expect(call.proposalId, '11111111-1111-4111-8111-111111111111');
      final cards = stateOf(container).entries
          .whereType<ProposalEntry>()
          .toList();
      expect(cards, hasLength(1));
      expect(cards.single.proposal.amount, '20000.00');
      expect(cards.single.proposal.revision, 2);
      expect(
        stateOf(container).entries.whereType<UserMessage>().map((m) => m.text),
        [taskText, 'mejor fueron 20 mil'],
      );
    },
  );

  test(
    'only ambiguity asks a question and a tapped option answers it',
    () async {
      final repository = FakeTextCaptureRepository(
        proposals: [accountQuestion(), proposal(revision: 2)],
      );
      final container = containerFor(repository);
      await controllerOf(container).send('gasté 15 mil');
      final question = stateOf(container).entries
          .whereType<ProposalEntry>()
          .single;
      expect(question.proposal.needsClarification, isTrue);
      expect(question.proposal.clarification!.isChoice, isTrue);

      await controllerOf(container)
          .choose(question, question.proposal.clarification!.options.last);

      final call = repository.proposeCalls.last;
      expect(call.text, isNull);
      expect(call.choice, (field: 'account', value: '2'));
      expect(call.proposalId, question.proposal.proposalId);
      final entries = stateOf(container).entries;
      expect(entries.whereType<UserMessage>().last.text, 'Nequi');
      expect(
        entries.whereType<ProposalEntry>().single.proposal.isReady,
        isTrue,
      );
    },
  );

  test(
    'a message that is not financial gets a plain answer and no card',
    () async {
      final repository = FakeTextCaptureRepository(
        proposals: [
          proposal(
            status: 'unrecognized',
            intent: null,
            amount: null,
            account: null,
            category: null,
            description: null,
            oneTap: false,
            message: 'No encontré un gasto, ingreso o transferencia.',
          ),
        ],
      );
      final container = containerFor(repository);

      await controllerOf(container).send('hola, ¿cómo estás?');

      final entries = stateOf(container).entries;
      expect(entries.whereType<ProposalEntry>(), isEmpty);
      expect(
        (entries.last as AssistantMessage).text,
        'No encontré un gasto, ingreso o transferencia.',
      );
      expect(stateOf(container).activeProposalId, isNull);
    },
  );

  test(
    'a provider failure is a copyable report and Retry sends the same turn',
    () async {
      final repository = FakeTextCaptureRepository(
        proposals: [
          const TextCaptureFailure(
            code: 'text_capture_unavailable',
            userMessage: 'No pude leer tu mensaje ahora.',
            correlationId: 'corr-1',
            technicalReason: 'http_503',
          ),
          proposal(),
        ],
      );
      final container = containerFor(repository);

      await controllerOf(container).send(taskText);

      final failure = stateOf(container).entries
          .whereType<FailureEntry>()
          .single;
      expect(failure.canRetry, isTrue);
      expect(failure.diagnostic.code, 'text_capture_unavailable');
      expect(failure.diagnostic.correlationId, 'corr-1');
      expect(failure.diagnostic.clipboardText, isNot(contains(taskText)));
      expect(stateOf(container).isBusy, isFalse);

      await controllerOf(container).retry();

      expect(repository.proposeCalls, hasLength(2));
      expect(repository.proposeCalls.last.text, taskText);
      final entries = stateOf(container).entries;
      expect(entries.whereType<FailureEntry>(), isEmpty);
      expect(entries.whereType<UserMessage>(), hasLength(1));
      expect(entries.whereType<ProposalEntry>(), hasLength(1));
    },
  );

  test('a rejected session is reported without a retry', () async {
    final repository = FakeTextCaptureRepository(
      proposals: [const InvalidSessionFailure(correlationId: 'c')],
    );
    final container = containerFor(repository);

    await controllerOf(container).send(taskText);

    final failure = stateOf(container).entries.whereType<FailureEntry>().single;
    expect(failure.canRetry, isFalse);
    expect(failure.diagnostic.code, 'session_invalid');
  });

  test('an unexpected error never leaks its text', () async {
    final repository = FakeTextCaptureRepository(
      proposals: [StateError('secret internal detail')],
    );
    final container = containerFor(repository);

    await controllerOf(container).send(taskText);

    final failure = stateOf(container).entries.whereType<FailureEntry>().single;
    expect(failure.diagnostic.code, 'unexpected_client_error');
    expect(
      failure.diagnostic.clipboardText,
      isNot(contains('secret internal detail')),
    );
    expect(failure.diagnostic.clipboardText, isNot(contains(taskText)));
  });

  test('dismissing a failure leaves the conversation intact', () async {
    final repository = FakeTextCaptureRepository(
      proposals: [const TextCaptureFailure(code: 'x', userMessage: 'm')],
    );
    final container = containerFor(repository);
    await controllerOf(container).send(taskText);

    controllerOf(container).dismissFailure();
    await controllerOf(container).retry();

    expect(stateOf(container).entries.whereType<FailureEntry>(), isEmpty);
    expect(repository.proposeCalls, hasLength(1));
  });

  test(
    'confirmed expense publishes shared and expense-feed revisions once',
    () async {
      final repository = FakeTextCaptureRepository(proposals: [proposal()]);
      final expenses = FakeExpensesRepository();
      final accountsRepository = FakeAccountsRepository();
      final budgetsController = FakeBudgetsController();
      final container = containerFor(
        repository,
        expenses: expenses,
        accountsRepository: accountsRepository,
        budgetsController: budgetsController,
      );
      await controllerOf(container).send(taskText);
      final entry = stateOf(container).entries
          .whereType<ProposalEntry>()
          .single;

      await controllerOf(container).confirm(entry, command());
      await Future<void>.delayed(Duration.zero);

      expect(repository.confirmCalls.single.$1, entry.proposal.proposalId);
      expect(repository.confirmCalls.single.$2.toJson(), {
        'intent': 'expense',
        'amount': '15900.00',
        'date': '2026-10-02',
        'account_id': 1,
        'description': 'Almuerzo en Subway',
        'category_id': 10,
      });
      final entries = stateOf(container).entries;
      expect(entries.whereType<ProposalEntry>(), isEmpty);
      expect(
        entries.whereType<ConfirmedEntry>().single.confirmation.recordId,
        701,
      );
      expect(stateOf(container).activeProposalId, isNull);
      expect(repository.confirmCalls, hasLength(1));
      expect(expenses.listCalls, 0);
      expect(expenses.historyCalls, 0);
      expect(accountsRepository.listCalls, 0);
      expect(container.read(financialMovementRevisionProvider), 1);
      expect(container.read(externalExpenseRevisionProvider), 1);
      expect(container.read(incomeRevisionProvider), 0);
      expect(budgetsController.loadCalls, 1);
    },
  );

  test(
    'text-captured income invalidates income totals but not expense feed',
    () async {
      final repository = FakeTextCaptureRepository(
        proposals: [proposal(intent: 'income')],
      )..confirmQueue.add(confirmation(intent: CaptureIntent.income));
      final container = containerFor(repository);
      await controllerOf(container).send(taskText);
      final entry = stateOf(container).entries
          .whereType<ProposalEntry>()
          .single;

      await controllerOf(container)
          .confirm(entry, command(intent: CaptureIntent.income));

      expect(repository.confirmCalls, hasLength(1));
      expect(container.read(financialMovementRevisionProvider), 1);
      expect(container.read(incomeRevisionProvider), 1);
      expect(container.read(externalExpenseRevisionProvider), 0);
    },
  );

  test('a failed Accept keeps the card open and can be retried', () async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    repository.confirmQueue.add(
      const TextCaptureFailure(
        code: 'network_unavailable',
        userMessage:
            'No pudimos confirmar si se guardó. Reintenta: no se duplicará.',
        isMutationOutcomeUncertain: true,
      ),
    );
    final container = containerFor(repository);
    await controllerOf(container).send(taskText);
    final entry = stateOf(container).entries.whereType<ProposalEntry>().single;

    await controllerOf(container).confirm(entry, command());

    var card = stateOf(container).entries.whereType<ProposalEntry>().single;
    expect(card.isConfirming, isFalse);
    expect(card.failure?.code, 'network_unavailable');
    expect(stateOf(container).activeProposalId, isNotNull);

    await controllerOf(container).confirm(card, command());

    expect(repository.confirmCalls, hasLength(2));
    expect(
      stateOf(container).entries.whereType<ConfirmedEntry>(),
      hasLength(1),
    );
  });

  test('Accept is ignored while a previous Accept is still running', () async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    final container = containerFor(repository);
    await controllerOf(container).send(taskText);
    final entry = stateOf(container).entries.whereType<ProposalEntry>().single;
    repository.gate = Completer<void>();

    final first = controllerOf(container).confirm(entry, command());
    await Future<void>.delayed(Duration.zero);
    final running = stateOf(container).entries
        .whereType<ProposalEntry>()
        .single;
    expect(running.isConfirming, isTrue);
    await controllerOf(container).confirm(running, command());
    expect(repository.confirmCalls, hasLength(1));

    repository.gate!.complete();
    await first;
    expect(repository.confirmCalls, hasLength(1));
  });

  test(
    'discarding drops the draft, tells the server and starts clean',
    () async {
      final repository = FakeTextCaptureRepository(
        proposals: [proposal(), proposal()],
      );
      final container = containerFor(repository);
      await controllerOf(container).send(taskText);
      final entry = stateOf(container).entries
          .whereType<ProposalEntry>()
          .single;

      await controllerOf(container).discard(entry);

      expect(repository.discardCalls, [entry.proposal.proposalId]);
      expect(stateOf(container).entries.whereType<ProposalEntry>(), isEmpty);
      expect(stateOf(container).activeProposalId, isNull);
      expect(
        (stateOf(container).entries.last as AssistantMessage).text,
        contains('No se guardó nada'),
      );

      await controllerOf(container).send('otro gasto');
      expect(repository.proposeCalls.last.proposalId, isNull);
    },
  );

  test('the conversation is cleared when another user signs in', () async {
    final repository = FakeTextCaptureRepository(proposals: [proposal()]);
    final container = containerFor(repository);
    await controllerOf(container).send(taskText);
    expect(stateOf(container).entries.length, greaterThan(1));

    container.invalidate(textCaptureControllerProvider);

    expect(stateOf(container).entries, hasLength(1));
    expect(stateOf(container).activeProposalId, isNull);
  });
}
