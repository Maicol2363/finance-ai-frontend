import 'dart:io';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/expenses/application/expenses_controller.dart';
import 'package:finance_ai/features/expenses/application/expenses_state.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/receipt_capture/application/receipt_capture_notifier.dart';
import 'package:finance_ai/features/receipt_capture/data/receipt_capture_remote_data_source.dart';
import 'package:finance_ai/features/receipt_capture/data/receipt_photo_cache_repository.dart';
import 'package:finance_ai/features/receipt_capture/domain/receipt_capture_state.dart';
import 'package:finance_ai/features/receipt_capture/domain/receipt_proposal_dto.dart';
import 'package:finance_ai/features/receipt_capture/domain/receipt_review_form_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

class _FakeAuthSessionController extends AuthSessionController {
  @override
  Future<T> runProtected<T>(
    Future<T> Function(String accessCredential) request,
  ) => request('test-token');
}

class _FakeExpensesController extends ExpensesController {
  @override
  ExpensesState build() => const ExpensesState();

  @override
  Future<void> load({int? page, int? pageSize}) async {}
}

class _FakeRemoteDataSource extends ReceiptCaptureRemoteDataSource {
  _FakeRemoteDataSource()
    : super(
        FinanceApiClient(
          MockClient((_) async => http.Response('{}', 200)),
          Uri.parse('http://localhost'),
          const Duration(seconds: 1),
        ),
        _FakeAuthSessionController(),
      );

  ReceiptProposalResponseDto? proposalResponse;
  Expense? confirmResponse;
  bool discardCalled = false;

  @override
  Future<ReceiptProposalResponseDto> uploadProposal({
    required String filePath,
    int rotationDegrees = 0,
  }) async {
    if (proposalResponse != null) {
      return proposalResponse!;
    }
    return const ReceiptProposalResponseDto(
      proposalId: '99',
      status: 'pending_review',
      extractedData: ReceiptExtractionDto(
        merchantName: 'Farmatodo',
        totalAmount: 45000.0,
        currency: 'COP',
        date: '2026-03-15T10:00:00Z',
        items: [
          ExtractedReceiptItemDto(
            name: 'Bloqueador Solar',
            quantity: 1,
            unitPrice: 45000.0,
            totalPrice: 45000.0,
          ),
        ],
      ),
      expiresAt: '2026-03-15T10:00:00Z',
    );
  }

  @override
  Future<void> discardProposal({required String proposalId}) async {
    discardCalled = true;
  }

  @override
  Future<Expense> confirmProposal({
    required String proposalId,
    required ReceiptProposalConfirmRequestDto command,
  }) async {
    if (confirmResponse != null) {
      return confirmResponse!;
    }
    return Expense.fromJson({
      'id': 200,
      'transaction_id': 200,
      'receipt_id': 200,
      'name': command.merchant,
      'amount': command.totalAmount.toStringAsFixed(2),
      'quantity': '1',
      'receipt_name': command.merchant,
      'store': command.merchant,
      'occurred_at': '2026-03-15T10:00:00Z',
      'date': '2026-03-15T10:00:00Z',
      'status': 'confirmed',
      'capture_source': 'ai',
      'account_id': command.accountId,
      'account_name': 'Efectivo',
      'account_is_active': true,
      'currency': {'id': 1, 'code': 'COP', 'name': 'Peso', 'decimals': 2},
      'currency_code': 'COP',
      'created_at': '2026-03-15T10:00:00Z',
      'updated_at': '2026-03-15T10:00:00Z',
    });
  }
}

class _FakePhotoCacheRepository implements ReceiptPhotoCacheRepository {
  final Map<int, String> stored = {};

  @override
  Future<String> saveReceiptPhoto({
    required int expenseId,
    required String sourceFilePath,
  }) async {
    stored[expenseId] = sourceFilePath;
    return '/cache/receipts/$expenseId.jpg';
  }

  @override
  Future<File?> getCachedReceiptPhoto(int expenseId) async {
    if (stored.containsKey(expenseId)) {
      return File(stored[expenseId]!);
    }
    return null;
  }

  @override
  Future<void> deleteCachedReceiptPhoto(int expenseId) async {
    stored.remove(expenseId);
  }
}

class _FakeImagePicker extends Fake implements ImagePicker {
  XFile? pickedFile;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return pickedFile;
  }
}

void main() {
  late ProviderContainer container;
  late _FakeRemoteDataSource fakeRemote;
  late _FakePhotoCacheRepository fakeCache;
  late _FakeImagePicker fakePicker;
  late File sampleFile;

  setUp(() {
    fakeRemote = _FakeRemoteDataSource();
    fakeCache = _FakePhotoCacheRepository();
    fakePicker = _FakeImagePicker();

    sampleFile = File('${Directory.systemTemp.path}/notifier_test.jpg')
      ..writeAsBytesSync([1, 2, 3, 4, 5]);

    fakePicker.pickedFile = XFile(sampleFile.path);

    container = ProviderContainer(
      overrides: [
        receiptCaptureRemoteDataSourceProvider.overrideWithValue(fakeRemote),
        receiptPhotoCacheRepositoryProvider.overrideWithValue(fakeCache),
        imagePickerProvider.overrideWithValue(fakePicker),
        expensesControllerProvider.overrideWith(_FakeExpensesController.new),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (sampleFile.existsSync()) {
      sampleFile.deleteSync();
    }
  });

  group('ReceiptCaptureNotifier', () {
    test('initial state is ReceiptCaptureIdle', () {
      final state = container.read(receiptCaptureNotifierProvider);
      expect(state, isA<ReceiptCaptureIdle>());
    });

    test('pickImage transitions to ReceiptCapturePreCheck', () async {
      final notifier = container.read(receiptCaptureNotifierProvider.notifier);
      await notifier.pickImage(ImageSource.camera);

      final state = container.read(receiptCaptureNotifierProvider);
      expect(state, isA<ReceiptCapturePreCheck>());
      final preCheck = state as ReceiptCapturePreCheck;
      expect(preCheck.imagePath, sampleFile.path);
      expect(preCheck.rotationDegrees, 0);
    });

    test('rotatePreCheck cycles rotation through 0, 90, 180, 270, 0', () async {
      final notifier = container.read(receiptCaptureNotifierProvider.notifier);
      await notifier.pickImage(ImageSource.camera);

      notifier.rotatePreCheck();
      var state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCapturePreCheck;
      expect(state.rotationDegrees, 90);

      notifier.rotatePreCheck();
      state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCapturePreCheck;
      expect(state.rotationDegrees, 180);

      notifier.rotatePreCheck();
      state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCapturePreCheck;
      expect(state.rotationDegrees, 270);

      notifier.rotatePreCheck();
      state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCapturePreCheck;
      expect(state.rotationDegrees, 0);
    });

    test(
      'analyzeReceipt uploads image and moves to ReceiptCaptureReview',
      () async {
        final notifier = container.read(
          receiptCaptureNotifierProvider.notifier,
        );
        await notifier.pickImage(ImageSource.camera);
        await notifier.analyzeReceipt();

        final state = container.read(receiptCaptureNotifierProvider);
        expect(state, isA<ReceiptCaptureReview>());
        final review = state as ReceiptCaptureReview;
        expect(review.proposalId, '99');
        expect(review.formData.merchant, 'Farmatodo');
        expect(review.formData.totalAmount, 45000.0);
        expect(review.formData.items.length, 1);
        expect(review.formData.items.first.name, 'Bloqueador Solar');
      },
    );

    test('form mutations update Review state correctly', () async {
      final notifier = container.read(receiptCaptureNotifierProvider.notifier);
      await notifier.pickImage(ImageSource.camera);
      await notifier.analyzeReceipt();

      final current = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCaptureReview;
      notifier.updateFormData(
        current.formData.copyWith(merchant: 'Farmatodo Chicó'),
      );
      var state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCaptureReview;
      expect(state.formData.merchant, 'Farmatodo Chicó');

      notifier.updateFormData(state.formData.copyWith(totalAmount: 50000.0));
      state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCaptureReview;
      expect(state.formData.totalAmount, 50000.0);

      notifier.updateFormData(state.formData.copyWith(accountId: 5));
      state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCaptureReview;
      expect(state.formData.accountId, 5);

      notifier.updateFormData(state.formData.copyWith(categoryId: 2));
      state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCaptureReview;
      expect(state.formData.categoryId, 2);

      notifier.updateFormData(state.formData.copyWith(note: 'Compra personal'));
      state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCaptureReview;
      expect(state.formData.note, 'Compra personal');
    });

    test('line items add, update, remove operations work', () async {
      final notifier = container.read(receiptCaptureNotifierProvider.notifier);
      await notifier.pickImage(ImageSource.camera);
      await notifier.analyzeReceipt();

      final newItem = ReceiptLineItemDraft(
        localId: 'manual-item',
        name: 'Agua Cristal',
        quantity: 2,
        unitPrice: 2500,
        totalPrice: 5000,
      );

      notifier.addLineItem(newItem);
      var state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCaptureReview;
      expect(state.formData.items.length, 2);
      expect(state.formData.items.last.name, 'Agua Cristal');

      final modified = newItem.copyWith(quantity: 3, totalPrice: 7500);
      notifier.updateLineItem(1, modified);
      state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCaptureReview;
      expect(state.formData.items.last.quantity, 3);
      expect(state.formData.items.last.totalPrice, 7500);

      notifier.removeLineItem(1);
      state = container.read(
        receiptCaptureNotifierProvider,
      ) as ReceiptCaptureReview;
      expect(state.formData.items.length, 1);
      expect(
        state.formData.items.any((i) => i.localId == 'manual-item'),
        isFalse,
      );
    });

    test('discardProposal invokes remote delete and resets to Idle', () async {
      final notifier = container.read(receiptCaptureNotifierProvider.notifier);
      await notifier.pickImage(ImageSource.camera);
      await notifier.analyzeReceipt();

      await notifier.discardProposal();

      expect(fakeRemote.discardCalled, isTrue);
      final state = container.read(receiptCaptureNotifierProvider);
      expect(state, isA<ReceiptCaptureIdle>());
    });

    test(
      'confirmExpense saves local cache and moves to ReceiptCaptureSuccess',
      () async {
        final notifier = container.read(
          receiptCaptureNotifierProvider.notifier,
        );
        await notifier.pickImage(ImageSource.camera);
        await notifier.analyzeReceipt();

        final current = container.read(
          receiptCaptureNotifierProvider,
        ) as ReceiptCaptureReview;
        notifier.updateFormData(current.formData.copyWith(accountId: 1));

        final result = await notifier.confirmExpense();

        expect(result, isNotNull);
        expect(result!.id, 200);
        expect(fakeCache.stored[200], sampleFile.path);

        final state = container.read(receiptCaptureNotifierProvider);
        expect(state, isA<ReceiptCaptureSuccess>());
        final success = state as ReceiptCaptureSuccess;
        expect(success.expenseId, 200);
        expect(success.localSavedImagePath, '/cache/receipts/200.jpg');
      },
    );
  });
}
