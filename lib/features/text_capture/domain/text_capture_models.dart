import 'package:flutter/foundation.dart';

/// What the assistant understood the user wants to register.
enum CaptureIntent {
  expense('expense', 'Gasto'),
  income('income', 'Ingreso'),
  transfer('transfer', 'Transferencia');

  const CaptureIntent(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CaptureIntent? tryParse(Object? value) {
    for (final intent in CaptureIntent.values) {
      if (intent.wireValue == value) {
        return intent;
      }
    }
    return null;
  }
}

enum ProposalStatus {
  ready('ready'),
  needsClarification('needs_clarification'),
  unrecognized('unrecognized'),
  confirmed('confirmed'),
  discarded('discarded');

  const ProposalStatus(this.wireValue);

  final String wireValue;

  static ProposalStatus parse(Object? value) {
    return ProposalStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => throw const FormatException('Unsupported proposal status'),
    );
  }
}

@immutable
class AccountRef {
  const AccountRef({
    required this.id,
    required this.name,
    required this.currencyCode,
  });

  factory AccountRef.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final currency = json['currency_code'];
    if (id is! int || name is! String || currency is! String) {
      throw const FormatException('Invalid account reference');
    }
    return AccountRef(id: id, name: name, currencyCode: currency);
  }

  final int id;
  final String name;
  final String currencyCode;
}

@immutable
class CatalogRef {
  const CatalogRef({required this.id, required this.name});

  factory CatalogRef.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! int || name is! String) {
      throw const FormatException('Invalid catalog reference');
    }
    return CatalogRef(id: id, name: name);
  }

  final int id;
  final String name;
}

@immutable
class ClarificationOption {
  const ClarificationOption({
    required this.value,
    required this.label,
    this.detail,
  });

  factory ClarificationOption.fromJson(Map<String, Object?> json) {
    final value = json['value'];
    final label = json['label'];
    if (value is! String || label is! String) {
      throw const FormatException('Invalid clarification option');
    }
    final detail = json['detail'];
    return ClarificationOption(
      value: value,
      label: label,
      detail: detail is String ? detail : null,
    );
  }

  final String value;
  final String label;
  final String? detail;
}

/// The single short question asked when the text is genuinely ambiguous.
@immutable
class Clarification {
  const Clarification({
    required this.field,
    required this.question,
    this.options = const [],
  });

  factory Clarification.fromJson(Map<String, Object?> json) {
    final field = json['field'];
    final question = json['question'];
    final options = json['options'];
    if (field is! String || question is! String) {
      throw const FormatException('Invalid clarification');
    }
    return Clarification(
      field: field,
      question: question,
      options: options is List<Object?>
          ? options
                .whereType<Map<String, Object?>>()
                .map(ClarificationOption.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  /// `intent`, `amount`, `account`, `destination_account`, `destination_amount`.
  final String field;
  final String question;
  final List<ClarificationOption> options;

  /// Options can be tapped; the other fields are answered by typing.
  bool get isChoice => options.isNotEmpty;
}

/// A proposed operation. Nothing is saved until the user confirms it.
@immutable
class TextProposal {
  const TextProposal({
    required this.proposalId,
    required this.revision,
    required this.status,
    required this.intent,
    required this.confidence,
    required this.oneTap,
    required this.originalText,
    this.followUps = const [],
    this.message,
    this.amount,
    this.currencyCode,
    this.destinationAmount,
    this.date,
    this.description,
    this.account,
    this.destinationAccount,
    this.category,
    this.incomeSource,
    this.clarification,
    this.notes = const [],
  });

  factory TextProposal.fromJson(Map<String, Object?> json) {
    final proposalId = json['proposal_id'];
    final revision = json['revision'];
    final confidence = json['confidence'];
    final oneTap = json['one_tap'];
    final originalText = json['original_text'];
    if (proposalId is! String ||
        revision is! int ||
        confidence is! num ||
        oneTap is! bool ||
        originalText is! String) {
      throw const FormatException('Invalid text proposal');
    }
    Map<String, Object?>? object(String key) {
      final value = json[key];
      return value is Map<String, Object?> ? value : null;
    }

    final account = object('account');
    final destination = object('destination_account');
    final category = object('category');
    final source = object('income_source');
    final clarification = object('clarification');
    final date = json['date'];
    return TextProposal(
      proposalId: proposalId,
      revision: revision,
      status: ProposalStatus.parse(json['status']),
      intent: CaptureIntent.tryParse(json['intent']),
      confidence: confidence.toDouble(),
      oneTap: oneTap,
      originalText: originalText,
      followUps: _strings(json['follow_ups']),
      message: json['message'] is String ? json['message']! as String : null,
      amount: json['amount'] is String ? json['amount']! as String : null,
      currencyCode: json['currency_code'] is String
          ? json['currency_code']! as String
          : null,
      destinationAmount: json['destination_amount'] is String
          ? json['destination_amount']! as String
          : null,
      date: date is String ? DateTime.tryParse(date) : null,
      description: json['description'] is String
          ? json['description']! as String
          : null,
      account: account == null ? null : AccountRef.fromJson(account),
      destinationAccount: destination == null
          ? null
          : AccountRef.fromJson(destination),
      category: category == null ? null : CatalogRef.fromJson(category),
      incomeSource: source == null ? null : CatalogRef.fromJson(source),
      clarification: clarification == null
          ? null
          : Clarification.fromJson(clarification),
      notes: _strings(json['notes']),
    );
  }

  static List<String> _strings(Object? value) => value is List<Object?>
      ? value.whereType<String>().toList(growable: false)
      : const [];

  final String proposalId;
  final int revision;
  final ProposalStatus status;
  final CaptureIntent? intent;
  final double confidence;
  final bool oneTap;
  final String originalText;
  final List<String> followUps;
  final String? message;

  /// Decimal strings straight from the API (`"15900.00"`).
  final String? amount;
  final String? currencyCode;
  final String? destinationAmount;
  final DateTime? date;
  final String? description;
  final AccountRef? account;
  final AccountRef? destinationAccount;
  final CatalogRef? category;
  final CatalogRef? incomeSource;
  final Clarification? clarification;
  final List<String> notes;

  bool get isReady => status == ProposalStatus.ready;
  bool get needsClarification => status == ProposalStatus.needsClarification;
}

/// Final values sent on Accept. They go through the same validation as the
/// manual forms on the server.
@immutable
class TextProposalConfirmCommand {
  const TextProposalConfirmCommand({
    required this.intent,
    required this.amount,
    required this.date,
    required this.accountId,
    this.description,
    this.destinationAccountId,
    this.destinationAmount,
    this.categoryId,
    this.incomeSourceId,
  });

  final CaptureIntent intent;
  final String amount;
  final DateTime date;
  final int accountId;
  final String? description;
  final int? destinationAccountId;
  final String? destinationAmount;
  final int? categoryId;
  final int? incomeSourceId;

  Map<String, Object?> toJson() => {
    'intent': intent.wireValue,
    'amount': amount,
    'date': _dateOnly(date),
    'account_id': accountId,
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
    if (intent == CaptureIntent.transfer && destinationAccountId != null)
      'destination_account_id': destinationAccountId,
    if (intent == CaptureIntent.transfer && destinationAmount != null)
      'destination_amount': destinationAmount,
    if (intent == CaptureIntent.expense && categoryId != null)
      'category_id': categoryId,
    if (intent == CaptureIntent.income && incomeSourceId != null)
      'income_source_id': incomeSourceId,
  };

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

@immutable
class TextCaptureConfirmation {
  const TextCaptureConfirmation({
    required this.intent,
    required this.recordId,
    required this.amount,
    required this.currencyCode,
    required this.accountName,
    this.description,
    this.destinationAccountName,
    this.replayed = false,
  });

  factory TextCaptureConfirmation.fromJson(Map<String, Object?> json) {
    final intent = CaptureIntent.tryParse(json['intent']);
    final recordId = json['record_id'];
    final amount = json['amount'];
    final currency = json['currency_code'];
    final account = json['account_name'];
    if (intent == null ||
        recordId is! int ||
        amount is! String ||
        currency is! String ||
        account is! String) {
      throw const FormatException('Invalid text capture confirmation');
    }
    return TextCaptureConfirmation(
      intent: intent,
      recordId: recordId,
      amount: amount,
      currencyCode: currency,
      accountName: account,
      description: json['description'] is String
          ? json['description']! as String
          : null,
      destinationAccountName: json['destination_account_name'] is String
          ? json['destination_account_name']! as String
          : null,
      replayed: json['replayed'] == true,
    );
  }

  final CaptureIntent intent;
  final int recordId;
  final String amount;
  final String currencyCode;
  final String accountName;
  final String? description;
  final String? destinationAccountName;
  final bool replayed;
}

/// A failed text-capture call, already reduced to safe, user-visible fields.
class TextCaptureFailure implements Exception {
  const TextCaptureFailure({
    required this.code,
    required this.userMessage,
    this.correlationId = 'unavailable',
    this.technicalReason = 'text_capture_failure',
    this.isRetryable = true,
    this.isMutationOutcomeUncertain = false,
  });

  final String code;
  final String userMessage;
  final String correlationId;
  final String technicalReason;

  /// The same request can be sent again (network or provider problem).
  final bool isRetryable;

  /// Accept was sent but its outcome is unknown: retrying is safe because the
  /// server records a proposal once, and a repeat returns the first result.
  final bool isMutationOutcomeUncertain;
}
