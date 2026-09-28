import '../../accounts/domain/account_models.dart';

/// Account option for transfer forms. Only owned accounts ever reach here
/// because the backend scopes every transfer read to the bearer owner.
class TransferAccount {
  const TransferAccount({
    required this.id,
    required this.name,
    required this.currencyCode,
  });

  factory TransferAccount.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final currencyCode = json['currency_code'];
    if (id is! int ||
        id < 1 ||
        name is! String ||
        name.trim().isEmpty ||
        currencyCode is! String ||
        currencyCode.isEmpty) {
      throw const FormatException('Invalid transfer account');
    }
    return TransferAccount(id: id, name: name, currencyCode: currencyCode);
  }

  final int id;
  final String name;
  final String currencyCode;
}

/// Confirmed transfer returned by `POST /api/v1/transfers`.
class Transfer {
  const Transfer({
    required this.id,
    required this.sourceAccount,
    required this.sourceAmount,
    required this.destinationAccount,
    required this.destinationAmount,
    required this.date,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transfer.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final sourceAccount = json['source_account'];
    final sourceAmount = json['source_amount'];
    final destinationAccount = json['destination_account'];
    final destinationAmount = json['destination_amount'];
    final date = json['date'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    if (id is! int ||
        id < 1 ||
        sourceAccount is! Map<String, Object?> ||
        sourceAmount is! String ||
        destinationAccount is! Map<String, Object?> ||
        destinationAmount is! String ||
        date is! String ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid transfer response');
    }
    final description = json['description'];
    if (description != null && description is! String) {
      throw const FormatException('Invalid transfer response');
    }
    final parsedDate = DateTime.tryParse(date);
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedDate == null ||
        parsedCreatedAt == null ||
        parsedUpdatedAt == null) {
      throw const FormatException('Invalid transfer timestamp');
    }
    return Transfer(
      id: id,
      sourceAccount: TransferAccount.fromJson(sourceAccount),
      sourceAmount: MoneyAmount.parseApi(sourceAmount),
      destinationAccount: TransferAccount.fromJson(destinationAccount),
      destinationAmount: MoneyAmount.parseApi(destinationAmount),
      date: DateTime.utc(parsedDate.year, parsedDate.month, parsedDate.day),
      description: description as String?,
      createdAt: parsedCreatedAt.toUtc(),
      updatedAt: parsedUpdatedAt.toUtc(),
    );
  }

  final int id;
  final TransferAccount sourceAccount;
  final MoneyAmount sourceAmount;
  final TransferAccount destinationAccount;
  final MoneyAmount destinationAmount;
  final DateTime date;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCrossCurrency =>
      sourceAccount.currencyCode != destinationAccount.currencyCode;
}

/// Creation command for `POST /api/v1/transfers`.
///
/// Both amounts travel explicitly: for cross-currency transfers the user
/// declares what left and what arrived, so no exchange-rate lookup exists.
class TransferCreateCommand {
  const TransferCreateCommand({
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.sourceAmount,
    required this.destinationAmount,
    required this.date,
    required this.description,
  });

  final int sourceAccountId;
  final int destinationAccountId;
  final MoneyAmount sourceAmount;

  /// Null means "same amount as the source" (same-currency transfers).
  final MoneyAmount? destinationAmount;
  final DateTime date;
  final String? description;

  static String _formatDate(DateTime value) {
    final date = value.toUtc();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Map<String, Object?> toJson() => {
    'source_account_id': sourceAccountId,
    'destination_account_id': destinationAccountId,
    'source_amount': sourceAmount.toApiString(),
    if (destinationAmount != null)
      'destination_amount': destinationAmount!.toApiString(),
    'date': _formatDate(date),
    if (description != null) 'description': description,
  };
}

class TransferFailure implements Exception {
  const TransferFailure({
    required this.code,
    required this.userMessage,
    this.fieldErrors = const {},
    this.correlationId = 'unavailable',
    this.technicalReason = 'transfer_operation_failure',
    this.isMutationOutcomeUncertain = false,
  });

  final String code;
  final String userMessage;
  final Map<String, List<String>> fieldErrors;
  final String correlationId;
  final String technicalReason;
  final bool isMutationOutcomeUncertain;
}
