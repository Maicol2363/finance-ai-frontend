import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/text_capture/presentation/widgets/capture_wheel.dart';
import 'package:finance_ai/features/text_capture/presentation/widgets/chat_bubbles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('thinking dots pulse without opacity layers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ThinkingBubble()),
      ),
    );

    final indicator = find.byKey(const Key('chat-thinking'));
    final dots = find.descendant(
      of: indicator,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    List<double> alphas() => dots
        .evaluate()
        .map(
          (element) =>
              ((element.widget as DecoratedBox).decoration as BoxDecoration)
                  .color!
                  .a,
        )
        .toList();

    final initialAlphas = alphas();
    expect(initialAlphas, hasLength(3));
    expect(
      find.descendant(of: indicator, matching: find.byType(FadeTransition)),
      findsNothing,
    );
    expect(
      find.descendant(of: indicator, matching: find.byType(Opacity)),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 275));

    expect(alphas().first, greaterThan(initialAlphas.first));
    expect(
      find.descendant(of: indicator, matching: find.byType(Opacity)),
      findsNothing,
    );
  });

  testWidgets('capture wheel options remain actionable after animating', (
    tester,
  ) async {
    var photoCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaptureWheel(
            onPhoto: () => photoCalls++,
            onAi: _noop,
            onManual: _noop,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('expenses-create-fab')));
    await tester.pump();

    expect(find.byKey(const Key('expenses-wheel-photo')), findsOneWidget);
    expect(find.byKey(const Key('expenses-wheel-ai')), findsOneWidget);
    expect(find.byKey(const Key('expenses-wheel-manual')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const Key('expenses-wheel-photo')));
    await tester.pumpAndSettle();

    expect(photoCalls, 1);
    expect(find.byKey(const Key('expenses-wheel-photo')), findsNothing);
  });
}

void _noop() {}
