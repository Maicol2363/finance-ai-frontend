import 'package:finance_ai/features/text_capture/domain/text_capture_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../text_capture_test_support.dart';

void main() {
  group('TextProposal', () {
    test('parses a ready expense with its grounded references', () {
      final parsed = proposal(
        description: 'Almuerzo en Subway',
        notes: ['Revisa los datos antes de confirmar.'],
      );

      expect(parsed.status, ProposalStatus.ready);
      expect(parsed.intent, CaptureIntent.expense);
      expect(parsed.oneTap, isTrue);
      expect(parsed.amount, '15900.00');
      expect(parsed.date, DateTime(2026, 10, 2));
      expect(parsed.account?.name, 'Efectivo');
      expect(parsed.account?.currencyCode, 'COP');
      expect(parsed.category?.id, 10);
      expect(parsed.clarification, isNull);
      expect(parsed.notes, ['Revisa los datos antes de confirmar.']);
      expect(parsed.originalText, contains('Subway'));
    });

    test('parses a transfer with both accounts and the arrived amount', () {
      final parsed = proposal(
        intent: 'transfer',
        category: null,
        destinationAccount: const {
          'id': 4,
          'name': 'Dólares',
          'currency_code': 'USD',
        },
        destinationAmount: '100.00',
      );

      expect(parsed.intent, CaptureIntent.transfer);
      expect(parsed.destinationAccount?.currencyCode, 'USD');
      expect(parsed.destinationAmount, '100.00');
      expect(parsed.category, isNull);
    });

    test('parses the single clarification with its options', () {
      final parsed = accountQuestion();

      expect(parsed.needsClarification, isTrue);
      expect(parsed.oneTap, isFalse);
      expect(parsed.clarification?.field, 'account');
      expect(parsed.clarification?.isChoice, isTrue);
      expect(parsed.clarification?.options.map((o) => o.label), [
        'Efectivo',
        'Nequi',
      ]);
      expect(parsed.clarification?.options.first.detail, 'COP');
    });

    test('a typed question has no options', () {
      final parsed = proposal(
        status: 'needs_clarification',
        amount: null,
        clarification: const {'field': 'amount', 'question': '¿De cuánto fue?'},
      );

      expect(parsed.clarification?.isChoice, isFalse);
    });

    test('unknown intents and malformed payloads are rejected safely', () {
      expect(CaptureIntent.tryParse('loan'), isNull);
      expect(
        () => TextProposal.fromJson({...proposalJson(), 'status': 'weird'}),
        throwsFormatException,
      );
      expect(
        () => TextProposal.fromJson({...proposalJson(), 'revision': 'x'}),
        throwsFormatException,
      );
      expect(
        () => TextProposal.fromJson({
          ...proposalJson(),
          'account': {'id': 'x'},
        }),
        throwsFormatException,
      );
    });
  });

  group('TextProposalConfirmCommand', () {
    test('an expense sends its category and never transfer fields', () {
      final json = TextProposalConfirmCommand(
        intent: CaptureIntent.expense,
        amount: '15900.00',
        date: DateTime(2026, 10, 2),
        accountId: 1,
        description: '  Almuerzo  ',
        categoryId: 10,
        incomeSourceId: 20,
        destinationAccountId: 2,
        destinationAmount: '5.00',
      ).toJson();

      expect(json, {
        'intent': 'expense',
        'amount': '15900.00',
        'date': '2026-10-02',
        'account_id': 1,
        'description': 'Almuerzo',
        'category_id': 10,
      });
    });

    test('an income sends its source and a transfer its destination', () {
      final income = TextProposalConfirmCommand(
        intent: CaptureIntent.income,
        amount: '2000000.00',
        date: DateTime(2026, 1, 5),
        accountId: 2,
        incomeSourceId: 20,
        categoryId: 10,
      ).toJson();
      final transfer = TextProposalConfirmCommand(
        intent: CaptureIntent.transfer,
        amount: '400000.00',
        date: DateTime(2026, 10, 2),
        accountId: 1,
        destinationAccountId: 4,
        destinationAmount: '100.00',
        categoryId: 10,
      ).toJson();

      expect(income, {
        'intent': 'income',
        'amount': '2000000.00',
        'date': '2026-01-05',
        'account_id': 2,
        'income_source_id': 20,
      });
      expect(transfer, {
        'intent': 'transfer',
        'amount': '400000.00',
        'date': '2026-10-02',
        'account_id': 1,
        'destination_account_id': 4,
        'destination_amount': '100.00',
      });
    });
  });

  test('a confirmation parses and reports a replay', () {
    final parsed = TextCaptureConfirmation.fromJson({
      'proposal_id': '11111111-1111-4111-8111-111111111111',
      'intent': 'transfer',
      'record_id': 905,
      'amount': '90000.00',
      'currency_code': 'COP',
      'date': '2026-10-02',
      'description': null,
      'account_name': 'Nequi',
      'destination_account_name': 'Efectivo',
      'replayed': true,
    });

    expect(parsed.intent, CaptureIntent.transfer);
    expect(parsed.destinationAccountName, 'Efectivo');
    expect(parsed.replayed, isTrue);
    expect(
      () => TextCaptureConfirmation.fromJson({'intent': 'expense'}),
      throwsFormatException,
    );
  });
}
