import '../../accounts/domain/account_models.dart';

/// Category reference embedded in expense payloads (HU-008/HU-011).
class ExpenseCategory {
  const ExpenseCategory({required this.id, required this.name});

  factory ExpenseCategory.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! int || id < 1 || name is! String || name.trim().isEmpty) {
      throw const FormatException('Invalid expense category response');
    }
    return ExpenseCategory(id: id, name: name);
  }

  final int id;
  final String name;
}

/// Lifecycle of an expense transaction as exposed by HU-008.
enum ExpenseStatus {
  pending,
  confirmed,
  voided;

  static ExpenseStatus fromWire(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid expense status');
    }
    return ExpenseStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw const FormatException('Unsupported expense status'),
    );
  }
}

/// Origin of a transaction as exposed by the API.
enum CaptureSource {
  manual,
  ai,
  import;

  static CaptureSource fromWire(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid capture source');
    }
    final normalized = switch (value.toLowerCase()) {
      'receipt_photo_ai' || 'text_ai' || 'audio_ai' || 'ai' => 'ai',
      'manual' => 'manual',
      'import' => 'import',
      _ => value,
    };
    return CaptureSource.values.firstWhere(
      (item) => item.name == normalized,
      orElse: () => throw const FormatException('Unsupported capture source'),
    );
  }
}

/// Single line item within an expense/receipt.
class ExpenseItem {
  const ExpenseItem({
    required this.name,
    required this.amount,
    required this.quantity,
    this.unitPrice,
    this.categoryName,
    this.categoryId,
    this.note,
  });

  factory ExpenseItem.fromJson(Map<String, Object?> json) {
    final category = json['category'];
    final categoryMap = category is Map<String, Object?> ? category : null;
    return ExpenseItem(
      name: json['name'] as String? ?? '',
      amount: MoneyAmount.parseApi(json['amount'] as String? ?? '0.00'),
      quantity: json['quantity'] as String? ?? '1.000',
      unitPrice: json['unit_price'] != null
          ? MoneyAmount.parseApi(json['unit_price'] as String)
          : null,
      categoryName:
          json['category_name'] as String? ?? categoryMap?['name'] as String?,
      categoryId: categoryMap?['id'] as int?,
      note: json['note'] as String?,
    );
  }

  final String name;
  final MoneyAmount amount;
  final String quantity;
  final MoneyAmount? unitPrice;
  final String? categoryName;
  final int? categoryId;
  final String? note;
}

/// Owned expense detail returned by `GET /api/v1/expenses[/{id}]`.
class Expense {
  const Expense({
    required this.id,
    required this.transactionId,
    required this.receiptId,
    required this.name,
    required this.amount,
    required this.quantity,
    required this.unitPrice,
    required this.note,
    required this.category,
    required this.receiptName,
    required this.receiptNote,
    required this.store,
    required this.description,
    required this.occurredAt,
    required this.status,
    required this.captureSource,
    required this.accountId,
    required this.accountName,
    required this.accountIsActive,
    required this.currency,
    required this.currencyCode,
    required this.createdAt,
    required this.updatedAt,
    required this.receiptImage,
    required this.imagePath,
    this.receiptTotal,
    this.items = const [],
  });

  factory Expense.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final transactionId = json['transaction_id'];
    final receiptId = json['receipt_id'];
    final name = json['name'];
    final amount = json['amount'];
    final quantity = json['quantity'];
    final receiptName = json['receipt_name'];
    final store = json['store'];
    final occurredAt = json['occurred_at'];
    final accountId = json['account_id'];
    final accountName = json['account_name'];
    final accountIsActive = json['account_is_active'];
    final currency = json['currency'];
    final currencyCode = json['currency_code'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    if (id is! int ||
        id < 1 ||
        transactionId is! int ||
        transactionId < 1 ||
        receiptId is! int ||
        receiptId < 1 ||
        name is! String ||
        name.trim().isEmpty ||
        amount is! String ||
        quantity is! String ||
        quantity.isEmpty ||
        receiptName is! String ||
        receiptName.trim().isEmpty ||
        store is! String ||
        store.isEmpty ||
        occurredAt is! String ||
        accountId is! int ||
        accountId < 1 ||
        accountName is! String ||
        accountName.isEmpty ||
        accountIsActive is! bool ||
        currency is! Map<String, Object?> ||
        currencyCode is! String ||
        currencyCode.isEmpty ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const FormatException('Invalid expense response');
    }
    final unitPrice = json['unit_price'];
    final note = json['note'];
    final category = json['category'];
    final receiptNote = json['receipt_note'];
    final description = json['description'];
    final receiptImage = json['receipt_image'];
    final imagePath = json['image_path'];
    if ((unitPrice != null && unitPrice is! String) ||
        (note != null && note is! String) ||
        (category != null && category is! Map<String, Object?>) ||
        (receiptNote != null && receiptNote is! String) ||
        (description != null && description is! String) ||
        (receiptImage != null && receiptImage is! String) ||
        (imagePath != null && imagePath is! String)) {
      throw const FormatException('Invalid expense response');
    }
    final parsedOccurredAt = DateTime.tryParse(occurredAt);
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedOccurredAt == null ||
        parsedCreatedAt == null ||
        parsedUpdatedAt == null) {
      throw const FormatException('Invalid expense timestamp');
    }
    final receiptTotal = json['receipt_total'];
    final rawItems = json['items'];
    final List<ExpenseItem> items = rawItems is List
        ? rawItems
              .whereType<Map<String, Object?>>()
              .map((e) => ExpenseItem.fromJson(e))
              .toList(growable: false)
        : const [];

    return Expense(
      id: id,
      transactionId: transactionId,
      receiptId: receiptId,
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
      receiptName: receiptName,
      receiptNote: receiptNote as String?,
      store: store,
      description: description as String?,
      occurredAt: parsedOccurredAt.toUtc(),
      status: ExpenseStatus.fromWire(json['status']),
      captureSource: CaptureSource.fromWire(json['capture_source']),
      accountId: accountId,
      accountName: accountName,
      accountIsActive: accountIsActive,
      currency: CurrencySummary.fromJson(currency),
      currencyCode: currencyCode,
      createdAt: parsedCreatedAt.toUtc(),
      updatedAt: parsedUpdatedAt.toUtc(),
      receiptImage: receiptImage as String?,
      imagePath: imagePath as String?,
      receiptTotal: receiptTotal is String
          ? MoneyAmount.parseApi(receiptTotal)
          : null,
      items: items,
    );
  }

  final int id;
  final int transactionId;
  final int receiptId;
  final String name;
  final MoneyAmount amount;

  /// Raw `\"1.000\"` wire string; kept unparsed to preserve the stored scale.
  final String quantity;
  final MoneyAmount? unitPrice;
  final String? note;
  final ExpenseCategory? category;
  final String receiptName;
  final String? receiptNote;
  final String store;
  final String? description;
  final DateTime occurredAt;
  final ExpenseStatus status;
  final CaptureSource captureSource;
  final int accountId;
  final String accountName;
  final bool accountIsActive;
  final CurrencySummary currency;
  final String currencyCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Persisted attachment references (no physical upload flow in HU-008).
  final String? receiptImage;
  final String? imagePath;
  final MoneyAmount? receiptTotal;
  final List<ExpenseItem> items;

  bool get isEditable => status == ExpenseStatus.confirmed;
}

class ExpenseListResult {
  const ExpenseListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasNext,
  });

  factory ExpenseListResult.fromJson(Map<String, Object?> json) {
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
      throw const FormatException('Invalid expense list response');
    }
    final items = rawItems
        .map((value) {
          if (value is! Map<String, Object?>) {
            throw const FormatException('Invalid expense list item');
          }
          return Expense.fromJson(value);
        })
        .toList(growable: false);
    return ExpenseListResult(
      items: List.unmodifiable(items),
      total: total,
      page: page,
      pageSize: pageSize,
      hasNext: hasNext,
    );
  }

  final List<Expense> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasNext;
}

/// Payload for creating a manual expense via `POST /api/v1/expenses` (HU-006).
class ExpenseCreateCommand {
  const ExpenseCreateCommand({
    required this.accountId,
    required this.amount,
    required this.merchant,
    this.occurredAt,
    this.categoryId,
    this.note,
  });

  final int accountId;
  final MoneyAmount amount;
  final String merchant;
  final DateTime? occurredAt;
  final int? categoryId;
  final String? note;

  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'amount': amount.toApiString(),
    'merchant': merchant,
    if (occurredAt != null)
      'occurred_at': occurredAt!.toUtc().toIso8601String(),
    if (categoryId != null) 'category_id': categoryId,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };
}

/// Editable fields for `PATCH /api/v1/expenses/{id}` (HU-008).
///
/// Only set fields travel on the wire. `clearNote` / `clearCategory` send an
/// explicit `null` because the backend distinguishes "absent" from "clear".
/// One receipt line submitted with an expense update.
///
/// Money travels as a 2-decimal string so the API receives the exact value
/// instead of a binary floating point approximation.
class ExpenseItemUpdateCommand {
  const ExpenseItemUpdateCommand({
    required this.name,
    required this.totalPrice,
    this.quantity = 1,
    this.unitPrice,
    this.categoryId,
    this.note,
  });

  final String name;
  final double totalPrice;
  final double quantity;
  final double? unitPrice;
  final int? categoryId;
  final String? note;

  Map<String, Object?> toJson() => {
    'name': name,
    'total_price': totalPrice.toStringAsFixed(2),
    'quantity': quantity.toString(),
    if (unitPrice != null) 'unit_price': unitPrice!.toStringAsFixed(2),
    if (categoryId != null) 'category_id': categoryId,
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}

class ExpenseUpdateCommand {
  const ExpenseUpdateCommand({
    this.name,
    this.amount,
    this.note,
    this.clearNote = false,
    this.receiptName,
    this.receiptNote,
    this.categoryId,
    this.clearCategory = false,
    this.accountId,
    this.occurredAt,
    this.description,
    this.items,
  });

  final String? name;
  final MoneyAmount? amount;
  final String? note;
  final bool clearNote;
  final String? receiptName;
  final String? receiptNote;
  final int? categoryId;
  final bool clearCategory;
  final int? accountId;
  final DateTime? occurredAt;
  final String? description;

  /// Receipt lines that replace the stored ones; null leaves them untouched.
  final List<ExpenseItemUpdateCommand>? items;

  Map<String, Object?> toJson() => {
    if (name != null) 'name': name,
    if (amount != null) 'amount': amount!.toApiString(),
    if (clearNote) 'note': null else if (note != null) 'note': note,
    if (receiptName != null) 'receipt_name': receiptName,
    if (receiptNote != null) 'receipt_note': receiptNote,
    if (clearCategory)
      'category_id': null
    else if (categoryId != null)
      'category_id': categoryId,
    if (accountId != null) 'account_id': accountId,
    if (occurredAt != null)
      'occurred_at': occurredAt!.toUtc().toIso8601String(),
    if (description != null) 'description': description,
    if (items != null) 'items': [for (final item in items!) item.toJson()],
  };
}

class ExpenseFailure implements Exception {
  const ExpenseFailure({
    required this.code,
    required this.userMessage,
    this.fieldErrors = const {},
    this.correlationId = 'unavailable',
    this.technicalReason = 'expense_operation_failure',
    this.isMutationOutcomeUncertain = false,
  });

  final String code;
  final String userMessage;
  final Map<String, List<String>> fieldErrors;
  final String correlationId;
  final String technicalReason;
  final bool isMutationOutcomeUncertain;
}
