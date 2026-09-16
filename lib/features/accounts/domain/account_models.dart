enum AccountType {
  cash('cash', 'Cash'),
  bank('bank', 'Bank account'),
  digitalWallet('digital_wallet', 'Digital wallet'),
  savings('savings', 'Savings'),
  creditCard('credit_card', 'Credit card'),
  other('other', 'Other');

  const AccountType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static AccountType fromWire(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid account type');
    }
    return AccountType.values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => throw const FormatException('Unsupported account type'),
    );
  }
}

class MoneyAmount {
  const MoneyAmount._(this.minorUnits);

  static const int maximumMinorUnits = 999999999999999999;

  // Performance optimization: Cache compiled RegExp instances statically
  // to avoid re-compiling regular expression patterns on every MoneyAmount parse call.
  static final RegExp _apiPattern = RegExp(r'^(-?)(\d+)\.(\d{2})$');
  static final RegExp _userInputPattern = RegExp(r'^(-?)(\d+)(?:[\.,](\d{0,2}))?$');

  factory MoneyAmount.fromMinorUnits(int minorUnits) {
    if (minorUnits.abs() > maximumMinorUnits) {
      throw const FormatException(
        'Money amount is outside the supported range',
      );
    }
    return MoneyAmount._(minorUnits);
  }

  factory MoneyAmount.parseApi(String source) {
    final match = _apiPattern.firstMatch(source);
    if (match == null) {
      throw const FormatException('Invalid API money amount');
    }
    final magnitude = int.tryParse('${match.group(2)}${match.group(3)}');
    if (magnitude == null || magnitude > maximumMinorUnits) {
      throw const FormatException(
        'Money amount is outside the supported range',
      );
    }
    return MoneyAmount._(match.group(1) == '-' ? -magnitude : magnitude);
  }

  static MoneyAmount? tryParseUserInput(String source) {
    final normalized = source.trim();
    final match = _userInputPattern.firstMatch(normalized);
    if (match == null) {
      return null;
    }
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    final magnitude = int.tryParse('${match.group(2)}$fraction');
    if (magnitude == null || magnitude > maximumMinorUnits) {
      return null;
    }
    return MoneyAmount._(match.group(1) == '-' ? -magnitude : magnitude);
  }

  final int minorUnits;

  bool get isNegative => minorUnits < 0;

  String toApiString() {
    final magnitude = minorUnits.abs();
    final whole = magnitude ~/ 100;
    final fraction = (magnitude % 100).toString().padLeft(2, '0');
    return '${isNegative ? '-' : ''}$whole.$fraction';
  }

  String formatWithCurrency(String currencyCode) =>
      '$currencyCode ${toApiString()}';

  @override
  bool operator ==(Object other) =>
      other is MoneyAmount && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;
}

class CurrencySummary {
  const CurrencySummary({
    required this.id,
    required this.code,
    required this.name,
    required this.decimals,
  });

  factory CurrencySummary.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final code = json['code'];
    final name = json['name'];
    final decimals = json['decimals'];
    if (id is! int ||
        code is! String ||
        code.isEmpty ||
        name is! String ||
        name.isEmpty ||
        decimals is! int ||
        decimals < 0) {
      throw const FormatException('Invalid currency response');
    }
    return CurrencySummary(id: id, code: code, name: name, decimals: decimals);
  }

  final int id;
  final String code;
  final String name;
  final int decimals;
}

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.openingBalance,
    required this.balance,
    required this.currencyIsLocked,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Account.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final currency = json['currency'];
    final openingBalance = json['opening_balance'];
    final balance = json['balance'];
    final currencyIsLocked = json['currency_is_locked'];
    final isActive = json['is_active'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    if (id is! int ||
        id < 1 ||
        name is! String ||
        name.isEmpty ||
        currency is! Map<String, Object?> ||
        openingBalance is! String ||
        balance is! String ||
        currencyIsLocked is! bool ||
        isActive is! bool ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid account response');
    }
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedCreatedAt == null || parsedUpdatedAt == null) {
      throw const FormatException('Invalid account timestamp');
    }
    return Account(
      id: id,
      name: name,
      type: AccountType.fromWire(json['type']),
      currency: CurrencySummary.fromJson(currency),
      openingBalance: MoneyAmount.parseApi(openingBalance),
      balance: MoneyAmount.parseApi(balance),
      currencyIsLocked: currencyIsLocked,
      isActive: isActive,
      createdAt: parsedCreatedAt.toUtc(),
      updatedAt: parsedUpdatedAt.toUtc(),
    );
  }

  final int id;
  final String name;
  final AccountType type;
  final CurrencySummary currency;
  final MoneyAmount openingBalance;
  final MoneyAmount balance;
  final bool currencyIsLocked;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AccountListResult {
  const AccountListResult({
    required this.accounts,
    required this.suggestedCurrencyCode,
    required this.supportedCurrencies,
    required this.accountTypes,
  });

  factory AccountListResult.fromJson(Map<String, Object?> json) {
    final rawAccounts = json['accounts'];
    final suggestedCurrencyCode = json['suggested_currency_code'];
    final rawCurrencies = json['supported_currencies'];
    final rawTypes = json['account_types'];
    if (rawAccounts is! List<Object?> ||
        suggestedCurrencyCode is! String ||
        suggestedCurrencyCode.isEmpty ||
        rawCurrencies is! List<Object?> ||
        rawTypes is! List<Object?>) {
      throw const FormatException('Invalid account list response');
    }
    final accounts = rawAccounts
        .map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Invalid account list item');
          }
          return Account.fromJson(value);
        })
        .toList(growable: false);
    final currencies = rawCurrencies
        .map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Invalid currency list item');
          }
          return CurrencySummary.fromJson(value);
        })
        .toList(growable: false);
    final types = rawTypes.map(AccountType.fromWire).toList(growable: false);
    if (currencies.isEmpty ||
        types.isEmpty ||
        !currencies.any((item) => item.code == suggestedCurrencyCode)) {
      throw const FormatException('Invalid account options response');
    }
    return AccountListResult(
      accounts: List.unmodifiable(accounts),
      suggestedCurrencyCode: suggestedCurrencyCode,
      supportedCurrencies: List.unmodifiable(currencies),
      accountTypes: List.unmodifiable(types),
    );
  }

  final List<Account> accounts;
  final String suggestedCurrencyCode;
  final List<CurrencySummary> supportedCurrencies;
  final List<AccountType> accountTypes;

  Account? accountById(int id) {
    for (final account in accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }
}

class AccountCreateCommand {
  const AccountCreateCommand({
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.openingBalance,
  });

  final String name;
  final AccountType type;
  final String currencyCode;
  final MoneyAmount openingBalance;

  Map<String, Object?> toJson() => {
    'name': name,
    'type': type.wireValue,
    'currency_code': currencyCode,
    'opening_balance': openingBalance.toApiString(),
  };
}

class AccountUpdateCommand {
  const AccountUpdateCommand({
    this.name,
    this.type,
    this.currencyCode,
    this.openingBalance,
  });

  final String? name;
  final AccountType? type;
  final String? currencyCode;
  final MoneyAmount? openingBalance;

  Map<String, Object?> toJson() => {
    if (name != null) 'name': name,
    if (type != null) 'type': type!.wireValue,
    if (currencyCode != null) 'currency_code': currencyCode,
    if (openingBalance != null)
      'opening_balance': openingBalance!.toApiString(),
  };
}

class AccountFailure implements Exception {
  const AccountFailure({
    required this.code,
    required this.userMessage,
    this.fieldErrors = const {},
    this.correlationId = 'unavailable',
    this.technicalReason = 'account_operation_failure',
    this.isRetryable = false,
    this.isMutationOutcomeUncertain = false,
  });

  final String code;
  final String userMessage;
  final Map<String, List<String>> fieldErrors;
  final String correlationId;
  final String technicalReason;
  final bool isRetryable;
  final bool isMutationOutcomeUncertain;
}
