import '../../accounts/domain/account_models.dart';

class Income {
  const Income({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.currencyCode,
    required this.amount,
    required this.date,
    required this.description,
    required this.incomeSourceId,
    required this.incomeSourceName,
  });

  factory Income.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final accountId = json['account_id'];
    final accountName = json['account_name'];
    final currencyCode = json['currency_code'];
    final rawAmount = json['amount'];
    final rawDate = json['date'];
    final description = json['description'];
    final sourceId = json['income_source_id'];
    final sourceName = json['income_source_name'];
    if (id is! int ||
        id < 1 ||
        accountId is! int ||
        accountId < 1 ||
        accountName is! String ||
        accountName.isEmpty ||
        currencyCode is! String ||
        currencyCode.isEmpty ||
        rawAmount is! String ||
        rawDate is! String ||
        (description != null && description is! String) ||
        (sourceId != null && (sourceId is! int || sourceId < 1)) ||
        (sourceName != null && sourceName is! String)) {
      throw const FormatException('Invalid income response');
    }
    final amount = MoneyAmount.parseApi(rawAmount);
    final date = parseIncomeDate(rawDate);
    if (amount.minorUnits <= 0) {
      throw const FormatException('Income amount must be positive');
    }
    return Income(
      id: id,
      accountId: accountId,
      accountName: accountName,
      currencyCode: currencyCode,
      amount: amount,
      date: date,
      description: description as String?,
      incomeSourceId: sourceId as int?,
      incomeSourceName: sourceName as String?,
    );
  }

  final int id;
  final int accountId;
  final String accountName;
  final String currencyCode;
  final MoneyAmount amount;
  final DateTime date;
  final String? description;
  final int? incomeSourceId;
  final String? incomeSourceName;
}

DateTime parseIncomeDate(String text) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    throw const FormatException('Invalid income date');
  }
  final date = DateTime.tryParse(text);
  if (date == null ||
      date.year.toString().padLeft(4, '0') != text.substring(0, 4) ||
      date.month.toString().padLeft(2, '0') != text.substring(5, 7) ||
      date.day.toString().padLeft(2, '0') != text.substring(8, 10)) {
    throw const FormatException('Invalid income date');
  }
  return DateTime.utc(date.year, date.month, date.day);
}

String incomeDateWire(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class IncomeWriteCommand {
  const IncomeWriteCommand({
    required this.accountId,
    required this.amount,
    required this.date,
    this.description,
    this.incomeSourceId,
  });

  final int accountId;
  final MoneyAmount amount;
  final DateTime date;
  final String? description;
  final int? incomeSourceId;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'amount': amount.toApiString(),
    'date': incomeDateWire(date),
    'description': description?.trim().isEmpty == true
        ? null
        : description?.trim(),
    'income_source_id': incomeSourceId,
  };
}

class IncomeFailure implements Exception {
  const IncomeFailure({
    required this.code,
    required this.userMessage,
    this.correlationId = 'unavailable',
    this.technicalReason = 'request_failure',
    this.fieldErrors = const {},
    this.outcomeUncertain = false,
  });

  final String code;
  final String userMessage;
  final String correlationId;
  final String technicalReason;
  final Map<String, List<String>> fieldErrors;
  final bool outcomeUncertain;
}
