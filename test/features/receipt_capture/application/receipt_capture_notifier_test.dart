import 'dart:io';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/expenses/application/expenses_controller.dart';
import 'package:finance_ai/features/expenses/application/expenses_state.dart';
import 'package:finance_ai/features/expenses/application/history_controller.dart';
import 'package:finance_ai/features/expenses/application/history_state.dart';
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

class _FakeHistoryController extends HistoryController {
  int loadCalls = 0;

  @override
  HistoryState build() => const HistoryState();

  @override
  Future<void> load() async {
    loadCalls += 1;
  }
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

  /// When set, the matching call fails with this error so the failure-reporting
  /// paths can be exercised with realistic exceptions.
  Object? uploadFailure;
  Object? confirmFailure;

  /// Every upload attempt, as (path, rotation), so retries can be asserted.
  final List<(String, int)> uploads = [];

  @override
  Future<ReceiptProposalResponseDto> uploadProposal({
    required String filePath,
    int rotationDegrees = 0,
  }) async {
    uploads.add((filePath, rotationDegrees));
    final failure = uploadFailure;
    if (failure != null) {
      throw failure;
    }
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
    final failure = confirmFailure;
    if (failure != null) {
      throw failure;
    }
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
  late _FakeHistoryController fakeHistory;
  late File sampleFile;

  setUp(() {
    fakeRemote = _FakeRemoteDataSource();
    fakeCache = _FakePhotoCacheRepository();
    fakePicker = _FakeImagePicker();
    fakeHistory = _FakeHistoryController();

    sampleFile = File('${Directory.systemTemp.path}/notifier_test.jpg')
      ..writeAsBytesSync([1, 2, 3, 4, 5]);

    fakePicker.pickedFile = XFile(sampleFile.path);

    container = ProviderContainer(
      overrides: [
        receiptCaptureRemoteDataSourceProvider.overrideWithValue(fakeRemote),
        receiptPhotoCacheRepositoryProvider.overrideWithValue(fakeCache),
        imagePickerProvider.overrideWithValue(fakePicker),
        expensesControllerProvider.overrideWith(_FakeExpensesController.new),
        historyControllerProvider.overrideWith(() => fakeHistory),
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
        expect(fakeHistory.loadCalls, 1);
        expect(fakeCache.stored[200], sampleFile.path);

        final state = container.read(receiptCaptureNotifierProvider);
        expect(state, isA<ReceiptCaptureSuccess>());
        final success = state as ReceiptCaptureSuccess;
        expect(success.expenseId, 200);
        expect(success.localSavedImagePath, '/cache/receipts/200.jpg');
      },
    );

    test('unreadable picked file reports a safe inspection failure', () async {
      fakePicker.pickedFile = XFile(
        '${Directory.systemTemp.path}/missing_receipt_image.jpg',
      );

      final notifier = container.read(receiptCaptureNotifierProvider.notifier);
      await notifier.pickImage(ImageSource.camera);

      final state = container.read(receiptCaptureNotifierProvider);
      expect(state, isA<ReceiptCaptureError>());
      final error = state as ReceiptCaptureError;

      expect(error.diagnostic.code, 'unexpected_client_error');
      expect(error.diagnostic.operation, 'validate_receipt_image');
      expect(error.diagnostic.technicalReason, 'image_inspection_failure');

      final report = error.diagnostic.clipboardText;
      expect(report, isNot(contains('Exception')));
      expect(report, isNot(contains('missing_receipt_image')));
    });

    test(
      'analysis failure reports a safe diagnostic without the raw exception',
      () async {
        const leakedPath = '/data/user/0/com.financeai/files/receipts/42.jpg';
        fakeRemote.uploadFailure = const FileSystemException(
          'Cannot open file',
          leakedPath,
        );

        final notifier = container.read(
          receiptCaptureNotifierProvider.notifier,
        );
        await notifier.pickImage(ImageSource.camera);
        await notifier.analyzeReceipt();

        final state = container.read(receiptCaptureNotifierProvider);
        expect(state, isA<ReceiptCaptureError>());
        final error = state as ReceiptCaptureError;

        expect(error.diagnostic.code, 'unexpected_client_error');
        expect(error.diagnostic.operation, 'analyze_receipt');
        expect(error.diagnostic.technicalReason, 'receipt_analysis_failure');
        expect(error.localImagePath, sampleFile.path);

        final report = error.diagnostic.clipboardText;
        expect(report, isNot(contains('FileSystemException')));
        expect(report, isNot(contains(leakedPath)));
        expect(report, isNot(contains(sampleFile.path)));
      },
    );

    test('analysis failure keeps the server code and correlation ID', () async {
      fakeRemote.uploadFailure = const ExpenseFailure(
        code: 'receipt_not_readable',
        userMessage: 'No pudimos leer el recibo. Intenta con otra foto.',
        correlationId: 'corr-123',
        technicalReason: 'vision_provider_unavailable',
      );

      final notifier = container.read(receiptCaptureNotifierProvider.notifier);
      await notifier.pickImage(ImageSource.camera);
      await notifier.analyzeReceipt();

      final state = container.read(receiptCaptureNotifierProvider);
      expect(state, isA<ReceiptCaptureError>());
      final diagnostic = (state as ReceiptCaptureError).diagnostic;

      expect(diagnostic.code, 'receipt_not_readable');
      expect(diagnostic.correlationId, 'corr-123');
      expect(diagnostic.operation, 'analyze_receipt');
      expect(diagnostic.technicalReason, 'vision_provider_unavailable');
      expect(
        diagnostic.userMessage,
        'No pudimos leer el recibo. Intenta con otra foto.',
      );
    });

    test(
      'oversize image reports the size code without the file path',
      () async {
        final bigFile = File('${Directory.systemTemp.path}/notifier_big.jpg')
          ..writeAsBytesSync(List<int>.filled(10 * 1024 * 1024 + 1, 0));
        addTearDown(() {
          if (bigFile.existsSync()) {
            bigFile.deleteSync();
          }
        });

        final notifier = container.read(
          receiptCaptureNotifierProvider.notifier,
        );
        await notifier.useImageFile(XFile(bigFile.path));

        final state = container.read(receiptCaptureNotifierProvider);
        expect(state, isA<ReceiptCaptureError>());
        final error = state as ReceiptCaptureError;

        expect(error.diagnostic.code, 'receipt_image_too_large');
        expect(error.diagnostic.operation, 'validate_receipt_image');
        expect(error.diagnostic.technicalReason, 'image_exceeds_size_limit');
        expect(error.localImagePath, bigFile.path);
        expect(error.diagnostic.clipboardText, isNot(contains(bigFile.path)));
      },
    );

    test(
      'retryFailedAnalysis re-uploads with the rotation the user applied',
      () async {
        fakeRemote.uploadFailure = const FileSystemException(
          'Cannot open file',
          '/data/user/0/com.financeai/files/receipts/42.jpg',
        );

        final notifier = container.read(
          receiptCaptureNotifierProvider.notifier,
        );
        await notifier.pickImage(ImageSource.camera);
        notifier.rotatePreCheck();
        await notifier.analyzeReceipt();

        final failed = container.read(receiptCaptureNotifierProvider);
        expect(failed, isA<ReceiptCaptureError>());
        expect((failed as ReceiptCaptureError).canRetry, isTrue);
        expect(failed.rotationDegrees, 90);

        fakeRemote.uploadFailure = null;
        await notifier.retryFailedAnalysis();

        expect(
          container.read(receiptCaptureNotifierProvider),
          isA<ReceiptCaptureReview>(),
        );
        expect(fakeRemote.uploads, [
          (sampleFile.path, 90),
          (sampleFile.path, 90),
        ]);
      },
    );

    test(
      'retryFailedAnalysis ignores failures that cannot be retried',
      () async {
        final bigFile = File(
          '${Directory.systemTemp.path}/notifier_retry_big.jpg',
        )..writeAsBytesSync(List<int>.filled(10 * 1024 * 1024 + 1, 0));
        addTearDown(() {
          if (bigFile.existsSync()) {
            bigFile.deleteSync();
          }
        });

        final notifier = container.read(
          receiptCaptureNotifierProvider.notifier,
        );
        await notifier.useImageFile(XFile(bigFile.path));

        final failed = container.read(receiptCaptureNotifierProvider);
        expect(failed, isA<ReceiptCaptureError>());
        expect((failed as ReceiptCaptureError).canRetry, isFalse);

        await notifier.retryFailedAnalysis();

        expect(
          container.read(receiptCaptureNotifierProvider),
          isA<ReceiptCaptureError>(),
        );
        expect(fakeRemote.uploads, isEmpty);
      },
    );

    test(
      'confirm failure reports a safe diagnostic on the review state',
      () async {
        fakeRemote.confirmFailure = const FileSystemException(
          'Cannot open file',
          '/data/user/0/com.financeai/files/receipts/42.jpg',
        );

        final notifier = container.read(
          receiptCaptureNotifierProvider.notifier,
        );
        await notifier.pickImage(ImageSource.camera);
        await notifier.analyzeReceipt();
        final review = container.read(
          receiptCaptureNotifierProvider,
        ) as ReceiptCaptureReview;
        notifier.updateFormData(review.formData.copyWith(accountId: 1));

        final result = await notifier.confirmExpense();

        expect(result, isNull);
        final state = container.read(
          receiptCaptureNotifierProvider,
        ) as ReceiptCaptureReview;
        final diagnostic = state.submissionDiagnostic;
        expect(diagnostic, isNotNull);
        expect(diagnostic!.code, 'unexpected_client_error');
        expect(diagnostic.operation, 'confirm_receipt_expense');
        expect(diagnostic.technicalReason, 'receipt_confirmation_failure');
        expect(state.submissionError, isNull);
        expect(
          diagnostic.clipboardText,
          isNot(contains('FileSystemException')),
        );
      },
    );
  });
}
