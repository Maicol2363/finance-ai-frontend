import 'package:finance_ai/features/receipt_capture/domain/receipt_review_form_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptLineItemDraft', () {
    test(
      'calculates totalPrice accurately based on quantity and unitPrice',
      () {
        final item = ReceiptLineItemDraft(
          localId: 'item-1',
          name: 'Leche Alquería',
          quantity: 3,
          unitPrice: 4500,
          totalPrice: 13500,
        );

        expect(item.id, 'item-1');
        expect(item.localId, 'item-1');
        expect(item.name, 'Leche Alquería');
        expect(item.description, 'Leche Alquería');
        expect(item.quantity, 3);
        expect(item.unitPrice, 4500);
        expect(item.totalPrice, 13500);
      },
    );

    test('copyWith updates specified fields only', () {
      final original = ReceiptLineItemDraft(
        localId: 'item-1',
        name: 'Pan Tajado',
        quantity: 1,
        unitPrice: 6000,
        totalPrice: 6000,
      );

      final updated = original.copyWith(
        name: 'Pan Tajado Bimbo',
        quantity: 2,
        totalPrice: 12000,
      );

      expect(updated.localId, 'item-1');
      expect(updated.name, 'Pan Tajado Bimbo');
      expect(updated.quantity, 2);
      expect(updated.unitPrice, 6000);
      expect(updated.totalPrice, 12000);
    });
  });

  group('ReceiptReviewFormData', () {
    test('computes itemsSum and detects zero discrepancy when matching totalAmount', () {
      final form = ReceiptReviewFormData(
        merchant: 'Éxito Calle 80',
        totalAmount: 25000,
        currency: 'COP',
        occurredAt: DateTime(2026, 3, 15),
        accountId: 1,
        categoryId: 2,
        items: [
          ReceiptLineItemDraft(
            localId: '1',
            name: 'Arroz Diana',
            quantity: 2,
            unitPrice: 5000,
            totalPrice: 10000,
          ),
          ReceiptLineItemDraft(
            localId: '2',
            name: 'Aceite Premier',
            quantity: 1,
            unitPrice: 15000,
            totalPrice: 15000,
          ),
        ],
      );

      expect(form.itemsSum, 25000);
      expect(form.itemsTotalSum, 25000);
      expect(form.discrepancy, 0);
      expect(form.hasDiscrepancy, isFalse);
      expect(form.hasArithmeticDiscrepancy, isFalse);
      expect(form.isValid, isTrue);
    });

    test('detects positive discrepancy when header total exceeds item sum', () {
      final form = ReceiptReviewFormData(
        merchant: 'Carulla',
        totalAmount: 30000,
        currency: 'COP',
        occurredAt: DateTime(2026, 3, 15),
        accountId: 1,
        items: [
          ReceiptLineItemDraft(
            localId: '1',
            name: 'Café Juan Valdez',
            quantity: 1,
            unitPrice: 20000,
            totalPrice: 20000,
          ),
        ],
      );

      expect(form.itemsSum, 20000);
      expect(form.discrepancy, 10000); // 30000 - 20000
      expect(form.hasDiscrepancy, isTrue);
      expect(form.hasArithmeticDiscrepancy, isTrue);
      expect(form.isValid, isTrue);
    });

    test('detects negative discrepancy when item sum exceeds header total', () {
      final form = ReceiptReviewFormData(
        merchant: 'D1 Supermercados',
        totalAmount: 18000,
        currency: 'COP',
        occurredAt: DateTime(2026, 3, 15),
        accountId: 1,
        items: [
          ReceiptLineItemDraft(
            localId: '1',
            name: 'Queso Campesino',
            quantity: 1,
            unitPrice: 12000,
            totalPrice: 12000,
          ),
          ReceiptLineItemDraft(
            localId: '2',
            name: 'Mantequilla',
            quantity: 1,
            unitPrice: 8000,
            totalPrice: 8000,
          ),
        ],
      );

      expect(form.itemsSum, 20000);
      expect(form.discrepancy, -2000);
      expect(form.hasDiscrepancy, isTrue);
    });

    test('validates required fields: merchant, totalAmount > 0, accountId', () {
      final validForm = ReceiptReviewFormData(
        merchant: 'Jumbo',
        totalAmount: 50000,
        currency: 'COP',
        occurredAt: DateTime.now(),
        accountId: 2,
        items: [],
      );
      expect(validForm.isValid, isTrue);

      final emptyMerchant = validForm.copyWith(merchant: '   ');
      expect(emptyMerchant.isValid, isFalse);

      final zeroTotal = validForm.copyWith(totalAmount: 0);
      expect(zeroTotal.isValid, isFalse);

      final negativeTotal = validForm.copyWith(totalAmount: -100);
      expect(negativeTotal.isValid, isFalse);

      final missingAccount = validForm.copyWith(clearAccountId: true);
      expect(missingAccount.isValid, isFalse);
    });
  });
}
