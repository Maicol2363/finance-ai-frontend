class ReceiptLineItemDraft {
  final String localId;
  String name;
  double quantity;
  double? unitPrice;
  double totalPrice;
  int? categoryId;
  String? note;

  ReceiptLineItemDraft({
    required this.localId,
    required this.name,
    this.quantity = 1.0,
    this.unitPrice,
    required this.totalPrice,
    this.categoryId,
    this.note,
  });

  ReceiptLineItemDraft copyWith({
    String? localId,
    String? name,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    int? categoryId,
    String? note,
  }) {
    return ReceiptLineItemDraft(
      localId: localId ?? this.localId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
    );
  }

  String get id => localId;
  String get description => name;
}

class ReceiptReviewFormData {
  String merchant;
  double totalAmount;
  DateTime occurredAt;
  int? accountId;
  int? categoryId;
  String? suggestedCategory;
  String? newCategoryName;
  String? paymentMethod;
  String? suggestedAccount;
  String currency;
  String? note;
  List<ReceiptLineItemDraft> items;

  ReceiptReviewFormData({
    required this.merchant,
    required this.totalAmount,
    required this.occurredAt,
    this.accountId,
    this.categoryId,
    this.suggestedCategory,
    this.newCategoryName,
    this.paymentMethod,
    this.suggestedAccount,
    this.currency = 'COP',
    this.note,
    required this.items,
  });

  /// Computes the sum of all item total prices.
  double get itemsTotalSum =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Checks if there is an arithmetic mismatch between line items and total.
  bool get hasArithmeticDiscrepancy =>
      items.isNotEmpty && (itemsTotalSum - totalAmount).abs() > 0.05;

  /// Absolute difference between line item sum and total amount.
  double get arithmeticDifference => (itemsTotalSum - totalAmount).abs();

  double get itemsSum => itemsTotalSum;
  double get discrepancy => totalAmount - itemsTotalSum;
  bool get hasDiscrepancy => hasArithmeticDiscrepancy;
  DateTime get date => occurredAt;

  /// Whether the core required fields are filled and valid.
  bool get isValid =>
      merchant.trim().isNotEmpty && totalAmount > 0 && accountId != null;

  ReceiptReviewFormData copyWith({
    String? merchant,
    double? totalAmount,
    DateTime? occurredAt,
    DateTime? date,
    int? accountId,
    bool clearAccountId = false,
    int? categoryId,
    bool clearCategoryId = false,
    String? suggestedCategory,
    String? newCategoryName,
    bool clearNewCategoryName = false,
    String? paymentMethod,
    String? suggestedAccount,
    String? currency,
    String? note,
    List<ReceiptLineItemDraft>? items,
  }) {
    return ReceiptReviewFormData(
      merchant: merchant ?? this.merchant,
      totalAmount: totalAmount ?? this.totalAmount,
      occurredAt: date ?? occurredAt ?? this.occurredAt,
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      newCategoryName: clearNewCategoryName
          ? null
          : (newCategoryName ?? this.newCategoryName),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      suggestedAccount: suggestedAccount ?? this.suggestedAccount,
      currency: currency ?? this.currency,
      note: note ?? this.note,
      items: items ?? List.from(this.items),
    );
  }
}
