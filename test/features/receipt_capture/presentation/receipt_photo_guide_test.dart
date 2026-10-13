import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:finance_ai/core/theme/app_palette.dart';
import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/receipt_capture/data/receipt_photo_guide_prefs.dart';
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
      SharedPreferences.setMockInitialValues({
        ReceiptPhotoGuidePrefs.guideSeenKey: true,
      });
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
        const MaterialApp(home: Scaffold(body: ReceiptPhotoGuideDialog())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cómo tomar una buena foto'), findsOneWidget);
      expect(find.text('1. Busca buena luz'), findsOneWidget);
      expect(find.text('2. Encuadra completo'), findsOneWidget);
      expect(find.text('3. Ponlo recto'), findsOneWidget);
      expect(find.byKey(const Key('receipt-guide-confirm')), findsOneWidget);
      expect(find.text('Solo te mostramos esto una vez.'), findsOneWidget);
    });

    testWidgets('guide copy and illustrations use both theme palettes', (
      tester,
    ) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Theme(
              data: theme,
              child: const Scaffold(body: ReceiptPhotoGuideDialog()),
            ),
          ),
        );

        final palette = theme.extension<AppPalette>()!;
        expect(
          tester
              .widget<Text>(
                find.text(
                  'Sigue estos 3 tips para que la IA lea tu recibo a la primera:',
                ),
              )
              .style!
              .color,
          palette.muted,
        );
        expect(
          tester
              .widget<Text>(
                find.text('Evita sombras y brillos sobre el papel.'),
              )
              .style!
              .color,
          palette.muted,
        );
        expect(
          tester
              .widget<Icon>(find.byIcon(FinanceIcons.lightModeOutlined))
              .color,
          palette.primaryDark,
        );
        expect(
          tester
              .widget<Text>(find.text('Solo te mostramos esto una vez.'))
              .style!
              .color,
          palette.muted,
        );
      }
    });

    testWidgets('default confirm pops the dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ReceiptPhotoGuideDialog())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('receipt-guide-confirm')));
      await tester.pumpAndSettle();

      // Dialog content is gone after pop.
      expect(find.text('Cómo tomar una buena foto'), findsNothing);
    });
  });
}
