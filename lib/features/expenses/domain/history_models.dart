import '../../accounts/domain/account_models.dart';
import 'expense_models.dart';

/// Transaction kinds exposed by `GET /api/v1/history` (HU-011).
enum TransactionType {
  expense,
  income,
  transfer;

  static TransactionType fromWire(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid transaction type');
    }
    return TransactionType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw const FormatException('Unsupported transaction type'),
    );
  }
}

/// Period presets accepted by the history endpoint.
enum HistoryPeriod {
  week,
  weekly,
  month,
  monthly,
  custom;

  static HistoryPeriod fromWire(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid history period');
    }
    return HistoryPeriod.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw const FormatException('Unsupported history period'),
    );
  }
}

/// Shape of a receipt entry, used by the history `receipt_kind` filter.
enum ReceiptKind {
  /// A receipt with a single expense line.
  single,

  /// A receipt with several expense lines.
  multi,
}

/// Signed account movement with its own currency metadata.
class HistoryMovement {
  const HistoryMovement({
    required this.accountId,
    required this.accountName,
    required this.amount,
    required this.currency,
    required this.currencyCode,
  });

  factory HistoryMovement.fromJson(Map<String, Object?> json) {
    final accountId = json['account_id'];
    final accountName = json['account_name'];
    final amount = json['amount'];
    final currency = json['currency'];
    final currencyCode =
        json['currency_code'] ??
        (currency is Map<String, Object?> ? currency['code'] : null);
    if (accountId is! int ||
        accountId < 1 ||
        accountName is! String ||
        accountName.isEmpty ||
        amount is! String ||
        currency is! Map<String, Object?> ||
        currencyCode is! String ||
        currencyCode.isEmpty) {
      throw const FormatException('Invalid history movement');
    }
    return HistoryMovement(
      accountId: accountId,
      accountName: accountName,
      amount: MoneyAmount.parseApi(amount),
      currency: CurrencySummary.fromJson(currency),
      currencyCode: currencyCode,
    );
  }

  final int accountId;
  final String accountName;
  final MoneyAmount amount;
  final CurrencySummary currency;
  final String currencyCode;
}

/// Single line item inside a history expense group.
class HistoryExpenseItem {
  const HistoryExpenseItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.quantity,
    required this.unitPrice,
    required this.note,
    required this.category,
    required this.imagePath,
  });

  factory HistoryExpenseItem.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final amount = json['amount'];
    final quantity = json['quantity'];
    if (id is! int ||
        id < 1 ||
        name is! String ||
        name.trim().isEmpty ||
        amount is! String ||
        quantity is! String ||
        quantity.isEmpty) {
      throw const FormatException('Invalid history expense item');
    }
    final unitPrice = json['unit_price'];
    final note = json['note'];
    final category = json['category'];
    final imagePath = json['image_path'];
    if ((unitPrice != null && unitPrice is! String) ||
        (note != null && note is! String) ||
        (category != null && category is! Map<String, Object?>) ||
        (imagePath != null && imagePath is! String)) {
      throw const FormatException('Invalid history expense item');
    }
    return HistoryExpenseItem(
      id: id,
      name: name,
      amount: MoneyAmount.parseApi(amount),
      quantity: quantity,
      unitPrice: unitPrice == null
          ? null
          : MoneyAmount.parseApi(unitPrice as String),
      note: note as String?,
      category: category == null
          ? null
          : ExpenseCategory.fromJson(category as Map<String, Object?>),
      imagePath: imagePath as String?,
    );
  }

  final int id;
  final String name;
  final MoneyAmount amount;
  final String quantity;
  final MoneyAmount? unitPrice;
  final String? note;
  final ExpenseCategory? category;
  final String? imagePath;
}

/// Receipt group attached to an expense history entry.
class HistoryExpense {
  const HistoryExpense({
    required this.receiptId,
    required this.name,
    required this.occurredAt,
    required this.purchasedAt,
    required this.totalAmount,
    required this.note,
    required this.store,
    required this.storeName,
    required this.items,
    required this.receiptImage,
  });

  factory HistoryExpense.fromJson(Map<String, Object?> json) {
    final receiptId = json['receipt_id'] ?? json['id'];
    final store = json['store'] ?? json['store_name'];
    final storeName = json['store_name'] ?? json['store'];
    final name = json['name'] ?? store;
    final totalAmount = json['total_amount'] ?? json['total'];
    final rawItems = json['items'];
    if (receiptId is! int ||
        receiptId < 1 ||
        name is! String ||
        name.isEmpty ||
        totalAmount is! String ||
        store is! String ||
        store.isEmpty ||
        storeName is! String ||
        storeName.isEmpty ||
        rawItems is! List<Object?>) {
      throw const FormatException('Invalid history expense');
    }
    final note = json['note'] ?? json['purchase_reason'];
    final receiptImage = json['receipt_image'];
    if ((note != null && note is! String) ||
        (receiptImage != null && receiptImage is! String)) {
      throw const FormatException('Invalid history expense');
    }
    final occurredAt = json['occurred_at'] ?? json['purchased_at'];
    final purchasedAt = json['purchased_at'] ?? json['occurred_at'];
    if (occurredAt is! String || purchasedAt is! String) {
      throw const FormatException('Invalid history expense timestamp');
    }
    final parsedOccurredAt = DateTime.tryParse(occurredAt);
    final parsedPurchasedAt = DateTime.tryParse(purchasedAt);
    if (parsedOccurredAt == null || parsedPurchasedAt == null) {
      throw const FormatException('Invalid history expense timestamp');
    }
    final items = rawItems
        .map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Invalid history expense item');
          }
          return HistoryExpenseItem.fromJson(value);
        })
        .toList(growable: false);
    return HistoryExpense(
      receiptId: receiptId,
      name: name,
      occurredAt: parsedOccurredAt.toUtc(),
      purchasedAt: parsedPurchasedAt.toUtc(),
      totalAmount: MoneyAmount.parseApi(totalAmount),
      note: note as String?,
      store: store,
      storeName: storeName,
      items: List.unmodifiable(items),
      receiptImage: receiptImage as String?,
    );
  }

  final int receiptId;
  final String name;
  final DateTime occurredAt;
  final DateTime purchasedAt;
  final MoneyAmount totalAmount;
  final String? note;
  final String store;
  final String storeName;
  final List<HistoryExpenseItem> items;
  final String? receiptImage;
}

/// One row of the unified history feed.
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.type,
    required this.status,
    required this.occurredAt,
    required this.description,
    required this.captureSource,
    required this.incomeSource,
    required this.movements,
    required this.expense,
  });

  factory HistoryItem.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final occurredAt = json['occurred_at'];
    final rawMovements = json['movements'];
    final rawType = json['type'] ?? json['transaction_type'];
    if (id is! int ||
        id < 1 ||
        occurredAt is! String ||
        rawMovements is! List<Object?>) {
      throw const FormatException('Invalid history item');
    }
    final description = json['description'];
    final incomeSource = json['income_source'] ?? json['income_source_name'];
    final expense = json['expense'];
    if ((description != null && description is! String) ||
        (incomeSource != null && incomeSource is! String) ||
        (expense != null && expense is! Map<String, Object?>)) {
      throw const FormatException('Invalid history item');
    }
    final parsedOccurredAt = DateTime.tryParse(occurredAt);
    if (parsedOccurredAt == null) {
      throw const FormatException('Invalid history timestamp');
    }
    final movements = rawMovements
        .map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Invalid history movement');
          }
          return HistoryMovement.fromJson(value);
        })
        .toList(growable: false);
    return HistoryItem(
      id: id,
      type: TransactionType.fromWire(rawType),
      status: ExpenseStatus.fromWire(json['status']),
      occurredAt: parsedOccurredAt.toUtc(),
      description: description as String?,
      captureSource: CaptureSource.fromWire(json['capture_source']),
      incomeSource: incomeSource as String?,
      movements: List.unmodifiable(movements),
      expense: expense == null
          ? null
          : HistoryExpense.fromJson(expense as Map<String, Object?>),
    );
  }

  final int id;
  final TransactionType type;
  final ExpenseStatus status;
  final DateTime occurredAt;
  final String? description;
  final CaptureSource captureSource;
  final String? incomeSource;
  final List<HistoryMovement> movements;
  final HistoryExpense? expense;
}

class HistoryResult {
  const HistoryResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasNext,
  });

  factory HistoryResult.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    final total = json['total'];
    final page = json['page'];
    final pageSize = json['page_size'];
    final hasNext = json['has_next'];
    if (rawItems is! List<Object?> ||
        total is! int ||
        total < 0 ||
        page is! int ||
        page < 1 ||
        pageSize is! int ||
        pageSize < 1 ||
        hasNext is! bool) {
      throw const FormatException('Invalid history response');
    }
    final items = rawItems
        .map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Invalid history list item');
          }
          return HistoryItem.fromJson(value);
        })
        .toList(growable: false);
    return HistoryResult(
      items: List.unmodifiable(items),
      total: total,
      page: page,
      pageSize: pageSize,
      hasNext: hasNext,
    );
  }

  final List<HistoryItem> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasNext;
}

/// Query parameters for `GET /api/v1/history`.
///
/// `custom` requires both dates; `week`/`month` presets travel without dates,
/// mirroring the backend contract.
class HistoryFilters {
  const HistoryFilters({
    this.search,
    this.type,
    this.categoryId,
    this.accountId,
    this.period,
    this.startDate,
    this.endDate,
    this.store,
    this.captureSource,
    this.receiptKind,
    this.page = 1,
    this.pageSize = 50,
  });

  final String? search;
  final TransactionType? type;
  final int? categoryId;
  final int? accountId;
  final HistoryPeriod? period;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Merchant filter, matched against the receipt store.
  final String? store;

  /// Capture-source group (`ai` covers photo, text and voice captures).
  final CaptureSource? captureSource;

  /// Receipt shape: one expense line or several.
  final ReceiptKind? receiptKind;
  final int page;
  final int pageSize;

  /// True when at least one user-facing filter is set (paging excluded), so the
  /// screen can show the active-filter chips and the "clear filters" action.
  bool get hasActiveFilters =>
      (search?.trim().isNotEmpty ?? false) ||
      type != null ||
      categoryId != null ||
      accountId != null ||
      period != null ||
      startDate != null ||
      endDate != null ||
      (store?.trim().isNotEmpty ?? false) ||
      captureSource != null ||
      receiptKind != null;

  static String _formatDate(DateTime value) {
    final date = value.toUtc();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Map<String, String> toQueryParameters() {
    final params = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    final trimmedSearch = search?.trim();
    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      params['search'] = trimmedSearch;
    }
    if (type != null) {
      params['type'] = type!.name;
    }
    if (categoryId != null) {
      params['category_id'] = '$categoryId';
    }
    if (accountId != null) {
      params['account_id'] = '$accountId';
    }
    final trimmedStore = store?.trim();
    if (trimmedStore != null && trimmedStore.isNotEmpty) {
      params['store'] = trimmedStore;
    }
    if (captureSource != null) {
      params['capture_source'] = captureSource!.name;
    }
    if (receiptKind != null) {
      params['receipt_kind'] = receiptKind!.name;
    }
    if (period != null) {
      params['period'] = period!.name;
    }
    if (startDate != null) {
      params['start_date'] = _formatDate(startDate!);
    }
    if (endDate != null) {
      params['end_date'] = _formatDate(endDate!);
    }
    return params;
  }
}

class HistoryFailure implements Exception {
  const HistoryFailure({
    required this.code,
    required this.userMessage,
    this.fieldErrors = const {},
    this.correlationId = 'unavailable',
    this.technicalReason = 'history_operation_failure',
    this.isMutationOutcomeUncertain = false,
  });

  final String code;
  final String userMessage;
  final Map<String, List<String>> fieldErrors;
  final String correlationId;
  final String technicalReason;
  final bool isMutationOutcomeUncertain;
}
