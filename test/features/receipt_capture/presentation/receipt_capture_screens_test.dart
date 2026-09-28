import 'dart:io';

import 'package:finance_ai/core/diagnostics/error_diagnostic.dart';
import 'package:finance_ai/core/diagnostics/error_diagnostic_panel.dart';
import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:finance_ai/features/receipt_capture/application/receipt_capture_notifier.dart';
import 'package:finance_ai/features/receipt_capture/domain/receipt_capture_state.dart';
import 'package:finance_ai/features/receipt_capture/domain/receipt_review_form_data.dart';
import 'package:finance_ai/features/receipt_capture/presentation/receipt_capture_flow.dart';
import 'package:finance_ai/features/receipt_capture/presentation/screens/receipt_camera_screen.dart';
import 'package:finance_ai/features/receipt_capture/presentation/screens/receipt_pre_check_screen.dart';
import 'package:finance_ai/features/receipt_capture/presentation/screens/receipt_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _FakeCategoriesRepository extends Fake implements CategoriesRepository {
  @override
  Future<CategoryListResult> list({bool includeArchived = false}) async {
    return const CategoryListResult(
      categories: [],
      supportedColors: [],
      supportedIcons: [],
    );
  }
}

class _TestReceiptCaptureNotifier extends ReceiptCaptureNotifier {
  _TestReceiptCaptureNotifier(this._initialState);

  final ReceiptCaptureState _initialState;
  int rotateCalls = 0;
  int analyzeCalls = 0;
  int retryCalls = 0;

  @override
  ReceiptCaptureState build() => _initialState;

  @override
  void rotatePreCheck([int delta = 90]) {
    rotateCalls++;
    if (state is ReceiptCapturePreCheck) {
      final current = state as ReceiptCapturePreCheck;
      state = current.copyWith(
        rotationDegrees: (current.rotationDegrees + delta) % 360,
      );
    }
  }

  @override
  Future<void> analyzeReceipt() async {
    analyzeCalls++;
  }

  @override
  Future<void> retryFailedAnalysis() async {
    retryCalls++;
  }
}

class _FakeImagePicker extends Fake implements ImagePicker {
  XFile? pickedFile;
  Object? failure;

  /// Sources requested by the app, in order.
  final List<ImageSource> requestedSources = [];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    requestedSources.add(source);
    final error = failure;
    if (error != null) {
      throw error;
    }
    return pickedFile;
  }
}

/// Lets the real `XFile.length()` file IO finish and flushes the fake test
/// zone before asserting.
Future<void> _settlePicker(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
}

/// Fake for [receiptCameraLauncherProvider]: records how many times the
/// in-app camera was opened and returns [captured] (null == user cancelled).
class _FakeInAppCamera {
  _FakeInAppCamera([this.captured]);

  final XFile? captured;
  int openCount = 0;

  Future<XFile?> open(NavigatorState navigator) async {
    openCount++;
    return captured;
  }
}

/// Pumps a minimal host screen whose "Foto" button runs [startReceiptCapture],
/// the same wiring as the Gastos hub entry wheel.
Future<void> _pumpCaptureLauncher(
  WidgetTester tester, {
  required _FakeImagePicker picker,
  required _FakeInAppCamera camera,
  ImageSource source = ImageSource.camera,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        imagePickerProvider.overrideWithValue(picker),
        receiptCameraLauncherProvider.overrideWithValue(camera.open),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => startReceiptCapture(context, source: source),
                child: const Text('Foto'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Uses a roomy surface so test-font metrics do not overflow the screens.
void _useRoomyViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  late File tempImage;

  setUp(() {
    tempImage = File('${Directory.systemTemp.path}/test_screen_image.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  });

  tearDown(() {
    if (tempImage.existsSync()) {
      tempImage.deleteSync();
    }
  });

  group('startReceiptCapture', () {
    testWidgets('opens the in-app camera and pushes the pre-check screen', (
      tester,
    ) async {
      final picker = _FakeImagePicker();
      final camera = _FakeInAppCamera(XFile(tempImage.path));
      await _pumpCaptureLauncher(tester, picker: picker, camera: camera);

      await tester.tap(find.text('Foto'));
      await _settlePicker(tester);

      expect(camera.openCount, 1);
      expect(picker.requestedSources, isEmpty);
      expect(find.byType(ReceiptPreCheckScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('falls back to the gallery file dialog on desktop', (
      tester,
    ) async {
      final picker = _FakeImagePicker()..pickedFile = XFile(tempImage.path);
      final camera = _FakeInAppCamera();
      await _pumpCaptureLauncher(tester, picker: picker, camera: camera);

      await tester.tap(find.text('Foto'));
      await _settlePicker(tester);

      expect(camera.openCount, 0);
      expect(picker.requestedSources, [ImageSource.gallery]);
      expect(find.byType(ReceiptPreCheckScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('stays on the hub when the in-app camera is cancelled', (
      tester,
    ) async {
      final picker = _FakeImagePicker();
      final camera = _FakeInAppCamera(); // Returns null == cancelled.
      await _pumpCaptureLauncher(tester, picker: picker, camera: camera);

      await tester.tap(find.text('Foto'));
      await _settlePicker(tester);

      expect(camera.openCount, 1);
      expect(picker.requestedSources, isEmpty);
      expect(find.byType(ReceiptPreCheckScreen), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('shows a snackbar when the picker fails', (tester) async {
      final picker = _FakeImagePicker()
        ..failure = Exception('permission denied');
      final camera = _FakeInAppCamera();
      await _pumpCaptureLauncher(
        tester,
        picker: picker,
        camera: camera,
        source: ImageSource.gallery,
      );

      await tester.tap(find.text('Foto'));
      await _settlePicker(tester);

      expect(find.byType(ReceiptPreCheckScreen), findsNothing);
      expect(
        find.text(
          'No se pudo leer la imagen seleccionada. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      // The raw plugin exception must never reach the user.
      expect(find.textContaining('permission denied'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('ReceiptPreCheckScreen', () {
    testWidgets(
      'renders image verification header, rotate CTA, and analyze CTA',
      (tester) async {
        _useRoomyViewport(tester);

        final testNotifier = _TestReceiptCaptureNotifier(
          ReceiptCapturePreCheck(
            imagePath: tempImage.path,
            fileSizeBytes: 2048,
            rotationDegrees: 0,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const ReceiptPreCheckScreen(),
            ),
          ),
        );

        expect(find.text('Vista previa del recibo'), findsOneWidget);
        expect(find.textContaining('Rotar'), findsWidgets);
        expect(find.text('Analizar recibo'), findsOneWidget);
        expect(find.text('Galería'), findsOneWidget);
        expect(find.text('Otra foto'), findsOneWidget);

        await tester.tap(find.textContaining('Rotar').first);
        await tester.pump();
        expect(testNotifier.rotateCalls, 1);
      },
    );
    testWidgets('swaps the image for a gallery one', (tester) async {
      _useRoomyViewport(tester);
      final replacement = File(
        '${Directory.systemTemp.path}/test_screen_image_gallery.jpg',
      )..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
      addTearDown(() {
        if (replacement.existsSync()) {
          replacement.deleteSync();
        }
      });

      final picker = _FakeImagePicker()..pickedFile = XFile(replacement.path);
      final testNotifier = _TestReceiptCaptureNotifier(
        const ReceiptCapturePreCheck(
          imagePath: 'first.jpg',
          fileSizeBytes: 2048,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
            imagePickerProvider.overrideWithValue(picker),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReceiptPreCheckScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Galería'));
      await _settlePicker(tester);

      expect(picker.requestedSources, [ImageSource.gallery]);
      expect(find.byType(ReceiptPreCheckScreen), findsOneWidget);

      final state = ProviderScope.containerOf(
        tester.element(find.byType(ReceiptPreCheckScreen)),
        listen: false,
      ).read(receiptCaptureNotifierProvider);
      expect(state, isA<ReceiptCapturePreCheck>());
      expect((state as ReceiptCapturePreCheck).imagePath, replacement.path);
      expect(tester.takeException(), isNull);
    });

    testWidgets('retakes the photo with the in-app camera', (tester) async {
      _useRoomyViewport(tester);
      final replacement = File(
        '${Directory.systemTemp.path}/test_screen_image_retake.jpg',
      )..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
      addTearDown(() {
        if (replacement.existsSync()) {
          replacement.deleteSync();
        }
      });

      final picker = _FakeImagePicker();
      final camera = _FakeInAppCamera(XFile(replacement.path));
      final testNotifier = _TestReceiptCaptureNotifier(
        const ReceiptCapturePreCheck(
          imagePath: 'first.jpg',
          fileSizeBytes: 2048,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
            imagePickerProvider.overrideWithValue(picker),
            receiptCameraLauncherProvider.overrideWithValue(camera.open),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReceiptPreCheckScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Otra foto'));
      await _settlePicker(tester);

      expect(camera.openCount, 1);
      expect(picker.requestedSources, isEmpty);
      expect(find.byType(ReceiptPreCheckScreen), findsOneWidget);

      final state = ProviderScope.containerOf(
        tester.element(find.byType(ReceiptPreCheckScreen)),
        listen: false,
      ).read(receiptCaptureNotifierProvider);
      expect(state, isA<ReceiptCapturePreCheck>());
      expect((state as ReceiptCapturePreCheck).imagePath, replacement.path);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the privacy-safe diagnostic panel instead of raw text', (
      tester,
    ) async {
      _useRoomyViewport(tester);

      final testNotifier = _TestReceiptCaptureNotifier(
        ReceiptCaptureError(
          diagnostic: ErrorDiagnostic.capture(
            code: 'unexpected_client_error',
            operation: 'analyze_receipt',
            userMessage: 'No se pudo analizar el recibo. Revisa tu conexión e inténtalo de nuevo.',
            technicalReason: 'receipt_analysis_failure',
          ),
          localImagePath: tempImage.path,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReceiptPreCheckScreen(),
          ),
        ),
      );

      expect(find.byType(ErrorDiagnosticPanel), findsOneWidget);
      expect(find.text('Error code: unexpected_client_error'), findsOneWidget);
      expect(
        find.byKey(const Key('copy-error-details-button')),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining(tempImage.path), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('retry CTA asks the notifier to analyse the same photo again', (
      tester,
    ) async {
      _useRoomyViewport(tester);

      final testNotifier = _TestReceiptCaptureNotifier(
        ReceiptCaptureError(
          diagnostic: ErrorDiagnostic.capture(
            code: 'unexpected_client_error',
            operation: 'analyze_receipt',
            userMessage: 'No se pudo analizar el recibo.',
            technicalReason: 'receipt_analysis_failure',
          ),
          localImagePath: tempImage.path,
          rotationDegrees: 90,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReceiptPreCheckScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Reintentar análisis'));
      await tester.pump();

      expect(testNotifier.retryCalls, 1);
      expect(testNotifier.analyzeCalls, 0);
    });

    testWidgets('retry CTA is hidden when another attempt cannot help', (
      tester,
    ) async {
      _useRoomyViewport(tester);

      final testNotifier = _TestReceiptCaptureNotifier(
        ReceiptCaptureError(
          diagnostic: ErrorDiagnostic.capture(
            code: 'receipt_image_too_large',
            operation: 'validate_receipt_image',
            userMessage:
                'La imagen excede el límite máximo permitido de 10 MB.',
            technicalReason: 'image_exceeds_size_limit',
          ),
          localImagePath: tempImage.path,
          canRetry: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReceiptPreCheckScreen(),
          ),
        ),
      );

      expect(find.text('Reintentar análisis'), findsNothing);
      expect(find.text('Volver'), findsOneWidget);
    });
  });

  group('ReceiptReviewScreen', () {
    testWidgets('renders discrepancy banner when item sum differs from total', (
      tester,
    ) async {
      final reviewState = ReceiptCaptureReview(
        proposalId: '42',
        status: 'pending_review',
        localImagePath: tempImage.path,
        formData: ReceiptReviewFormData(
          merchant: 'Carulla',
          totalAmount: 50000.0,
          currency: 'COP',
          occurredAt: DateTime(2026, 3, 15),
          items: [
            ReceiptLineItemDraft(
              localId: '1',
              name: 'Queso',
              quantity: 1,
              unitPrice: 20000.0,
              totalPrice: 20000.0,
            ),
          ],
        ),
      );

      final testNotifier = _TestReceiptCaptureNotifier(reviewState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
            categoriesRepositoryProvider.overrideWithValue(
              _FakeCategoriesRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReceiptReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Revisar recibo'), findsOneWidget);
      expect(find.text('Confirmar gasto'), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);
      expect(find.text('Diferencia en la suma de productos'), findsOneWidget);
      expect(find.text('Queso'), findsOneWidget);
    });

    testWidgets(
      'shows warning and disables Confirmar gasto when status is not_a_receipt',
      (tester) async {
        final notAReceiptState = ReceiptCaptureReview(
          proposalId: 'non-receipt-id',
          status: 'not_a_receipt',
          localImagePath: tempImage.path,
          formData: ReceiptReviewFormData(
            merchant: '',
            totalAmount: 0.0,
            currency: 'COP',
            occurredAt: DateTime(2026, 3, 15),
            items: [],
          ),
        );

        final testNotifier = _TestReceiptCaptureNotifier(notAReceiptState);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
              categoriesRepositoryProvider.overrideWithValue(
                _FakeCategoriesRepository(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const ReceiptReviewScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('La imagen no parece ser un recibo válido'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);

        // Verify Confirm button is disabled
        final confirmBtnFinder = find.widgetWithText(
          FilledButton,
          'Confirmar gasto',
        );
        expect(confirmBtnFinder, findsOneWidget);
        final FilledButton button = tester.widget(confirmBtnFinder);
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'shows duplicate warning banner when possibleDuplicate is true',
      (tester) async {
        final duplicateState = ReceiptCaptureReview(
          proposalId: 'dup-proposal-id',
          status: 'complete',
          localImagePath: tempImage.path,
          possibleDuplicate: true,
          duplicateWarning:
              'Ya registraste una compra en D1 SAS por \$11.700 en esta fecha.',
          formData: ReceiptReviewFormData(
            merchant: 'D1 SAS',
            totalAmount: 11700.0,
            currency: 'COP',
            occurredAt: DateTime(2026, 9, 27),
            items: [],
          ),
        );

        final testNotifier = _TestReceiptCaptureNotifier(duplicateState);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
              categoriesRepositoryProvider.overrideWithValue(
                _FakeCategoriesRepository(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const ReceiptReviewScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Posible recibo duplicado'), findsOneWidget);
        expect(
          find.text(
            'Ya registraste una compra en D1 SAS por \$11.700 en esta fecha.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows the diagnostic panel when a confirmation fails', (
      tester,
    ) async {
      _useRoomyViewport(tester);

      final failureState = ReceiptCaptureReview(
        proposalId: 'proposal-failure',
        status: 'complete',
        localImagePath: tempImage.path,
        submissionDiagnostic: ErrorDiagnostic.capture(
          code: 'receipt_proposal_not_found',
          operation: 'confirm_receipt_expense',
          userMessage: 'El borrador del recibo ya no está disponible.',
          correlationId: 'corr-9',
          technicalReason: 'proposal_not_found',
        ),
        formData: ReceiptReviewFormData(
          merchant: 'D1 SAS',
          totalAmount: 11700.0,
          currency: 'COP',
          occurredAt: DateTime(2026, 9, 27),
          items: [],
        ),
      );

      final testNotifier = _TestReceiptCaptureNotifier(failureState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptCaptureNotifierProvider.overrideWith(() => testNotifier),
            categoriesRepositoryProvider.overrideWithValue(
              _FakeCategoriesRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReceiptReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ErrorDiagnosticPanel), findsOneWidget);
      expect(
        find.text('Error code: receipt_proposal_not_found'),
        findsOneWidget,
      );
      expect(
        find.text('El borrador del recibo ya no está disponible.'),
        findsWidgets,
      );
      expect(find.textContaining('Exception'), findsNothing);
    });
  });
}
