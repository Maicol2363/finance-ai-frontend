import 'package:flutter/foundation.dart';

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

@immutable
class ExtractedReceiptItemDto {
  final String name;
  final double totalPrice;
  final double quantity;
  final double? unitPrice;
  final String? categorySuggestion;

  const ExtractedReceiptItemDto({
    required this.name,
    required this.totalPrice,
    this.quantity = 1.0,
    this.unitPrice,
    this.categorySuggestion,
  });

  factory ExtractedReceiptItemDto.fromJson(Map<String, dynamic> json) {
    return ExtractedReceiptItemDto(
      name: json['name'] as String? ?? '',
      totalPrice:
          _parseDouble(json['total_price']) ??
          _parseDouble(json['amount']) ??
          0.0,
      quantity: _parseDouble(json['quantity']) ?? 1.0,
      unitPrice: _parseDouble(json['unit_price']),
      categorySuggestion: json['category_suggestion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'total_price': totalPrice,
      'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (categorySuggestion != null) 'category_suggestion': categorySuggestion,
    };
  }
}

@immutable
class ReceiptExtractionDto {
  final String? merchantName;
  final String? date;
  final double? totalAmount;
  final double? taxAmount;
  final String currency;
  final String? categorySuggestion;
  final int? categoryId;
  final String? paymentMethod;
  final String? suggestedAccount;
  final List<ExtractedReceiptItemDto> items;
  final bool isReceipt;

  const ReceiptExtractionDto({
    this.merchantName,
    this.date,
    this.totalAmount,
    this.taxAmount,
    this.currency = 'COP',
    this.categorySuggestion,
    this.categoryId,
    this.paymentMethod,
    this.suggestedAccount,
    this.items = const [],
    this.isReceipt = true,
  });

  factory ReceiptExtractionDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return ReceiptExtractionDto(
      merchantName: json['merchant_name'] as String?,
      date: json['purchase_date'] as String? ?? json['date'] as String?,
      totalAmount: _parseDouble(json['total_amount']),
      taxAmount: _parseDouble(json['tax_amount']),
      currency: json['currency'] as String? ?? 'COP',
      categorySuggestion:
          json['suggested_category'] as String? ??
          json['category_suggestion'] as String?,
      categoryId: json['category_id'] as int?,
      paymentMethod: json['payment_method'] as String?,
      suggestedAccount: json['suggested_account'] as String?,
      items: rawItems
          .map(
            (e) => ExtractedReceiptItemDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      isReceipt:
          json['is_receipt'] as bool? ??
          (json['status'] != null ? json['status'] != 'not_a_receipt' : true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (merchantName != null) 'merchant_name': merchantName,
      if (date != null) 'date': date,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (taxAmount != null) 'tax_amount': taxAmount,
      'currency': currency,
      if (categorySuggestion != null) 'category_suggestion': categorySuggestion,
      if (categoryId != null) 'category_id': categoryId,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (suggestedAccount != null) 'suggested_account': suggestedAccount,
      'items': items.map((e) => e.toJson()).toList(),
      'is_receipt': isReceipt,
    };
  }
}

@immutable
class ReceiptProposalResponseDto {
  final String proposalId;
  final String status;
  final ReceiptExtractionDto extractedData;
  final List<String> issues;
  final String expiresAt;
  final bool possibleDuplicate;
  final String? duplicateWarning;

  const ReceiptProposalResponseDto({
    required this.proposalId,
    required this.status,
    required this.extractedData,
    this.issues = const [],
    required this.expiresAt,
    this.possibleDuplicate = false,
    this.duplicateWarning,
  });

  factory ReceiptProposalResponseDto.fromJson(Map<String, dynamic> json) {
    final rawIssues = json['issues'] as List<dynamic>? ?? [];
    final extractedJson = json['extracted_data'] is Map<String, dynamic>
        ? json['extracted_data'] as Map<String, dynamic>
        : json;
    return ReceiptProposalResponseDto(
      proposalId: json['proposal_id'] as String? ?? '',
      status: json['status'] as String? ?? 'complete',
      extractedData: ReceiptExtractionDto.fromJson(extractedJson),
      issues: rawIssues.map((e) {
        if (e is Map<String, dynamic>) {
          return e['message'] as String? ??
              e['code'] as String? ??
              e.toString();
        }
        return e.toString();
      }).toList(),
      expiresAt: json['expires_at'] as String? ?? '',
      possibleDuplicate: json['possible_duplicate'] as bool? ?? false,
      duplicateWarning: json['duplicate_warning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'proposal_id': proposalId,
      'status': status,
      'extracted_data': extractedData.toJson(),
      'issues': issues,
      'expires_at': expiresAt,
      'possible_duplicate': possibleDuplicate,
      if (duplicateWarning != null) 'duplicate_warning': duplicateWarning,
    };
  }
}

@immutable
class ConfirmedReceiptItemDto {
  final String name;
  final double totalPrice;
  final double quantity;
  final double? unitPrice;
  final int? categoryId;
  final String? note;

  const ConfirmedReceiptItemDto({
    required this.name,
    required this.totalPrice,
    this.quantity = 1.0,
    this.unitPrice,
    this.categoryId,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'total_price': totalPrice,
      'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  factory ConfirmedReceiptItemDto.fromJson(Map<String, dynamic> json) {
    return ConfirmedReceiptItemDto(
      name: json['name'] as String? ?? '',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      categoryId: json['category_id'] as int?,
      note: json['note'] as String?,
    );
  }
}

@immutable
class ReceiptProposalConfirmRequestDto {
  final int accountId;
  final double totalAmount;
  final String merchant;
  final String occurredAt;
  final String currency;
  final int? categoryId;
  final String? newCategoryName;
  final String? note;
  final List<ConfirmedReceiptItemDto> items;

  const ReceiptProposalConfirmRequestDto({
    required this.accountId,
    required this.totalAmount,
    required this.merchant,
    required this.occurredAt,
    required this.currency,
    this.categoryId,
    this.newCategoryName,
    this.note,
    this.items = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'total_amount': totalAmount,
      'merchant': merchant,
      'occurred_at': occurredAt,
      'currency': currency,
      if (categoryId != null) 'category_id': categoryId,
      if (newCategoryName != null && newCategoryName!.trim().isNotEmpty)
        'new_category_name': newCategoryName!.trim(),
      if (note != null && note!.isNotEmpty) 'note': note,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
