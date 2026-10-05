import 'package:finance_ai/features/receipt_capture/data/receipt_photo_guide_prefs.dart';
import 'package:finance_ai/features/receipt_capture/presentation/widgets/receipt_photo_frame_overlay.dart';
import 'package:finance_ai/features/receipt_capture/presentation/widgets/receipt_photo_guide_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReceiptPhotoGuidePrefs', () {
    test('shows guide on first launch, hides after confirm', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ReceiptPhotoGuidePrefs.shouldShowGuide(), isTrue);

      await ReceiptPhotoGuidePrefs.markGuideSeen();
      expect(await ReceiptPhotoGuidePrefs.shouldShowGuide(), isFalse);
    });

    test('guide can be shown again after clear', () async {
      SharedPreferences.setMockInitialValues(
        {ReceiptPhotoGuidePrefs.guideSeenKey: true},
      );
      expect(await ReceiptPhotoGuidePrefs.shouldShowGuide(), isFalse);

      await ReceiptPhotoGuidePrefs.clear();
      expect(await ReceiptPhotoGuidePrefs.shouldShowGuide(), isTrue);
    });

    test('uses versioned key', () {
      expect(
        ReceiptPhotoGuidePrefs.guideSeenKey,
        'finance_ai.receipt_photo_guide_seen_v1',
      );
    });
  });

  group('ReceiptPhotoGuideDialog', () {
    testWidgets('renders 3 tips and confirm button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReceiptPhotoGuideDialog()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cómo tomar una buena foto'), findsOneWidget);
      expect(find.text('1. Busca buena luz'), findsOneWidget);
      expect(find.text('2. Encuadra completo'), findsOneWidget);
      expect(find.text('3. Ponlo recto'), findsOneWidget);
      expect(find.byKey(const Key('receipt-guide-confirm')), findsOneWidget);
      expect(find.text('Solo te mostramos esto una vez.'), findsOneWidget);
    });

    testWidgets('default confirm pops the dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ReceiptPhotoGuideDialog()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('receipt-guide-confirm')));
      await tester.pumpAndSettle();

      // Dialog content is gone after pop.
      expect(find.text('Cómo tomar una buena foto'), findsNothing);
    });
  });

  group('ReceiptPhotoFrameOverlay', () {
    testWidgets('renders hint below the frame', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: ReceiptPhotoFrameOverlay(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Coloca el recibo aquí'), findsOneWidget);
    });

    testWidgets('accepts custom hint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: ReceiptPhotoFrameOverlay(hint: 'Centra el ticket'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Centra el ticket'), findsOneWidget);
    });
  });
}
