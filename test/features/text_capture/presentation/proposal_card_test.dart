import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/text_capture/application/text_capture_state.dart';
import 'package:finance_ai/features/text_capture/presentation/widgets/proposal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../text_capture_test_support.dart';

void main() {
  testWidgets('proposal summary adapts to large text without overflow', (
    tester,
  ) async {
    const description =
        'Compra en un comercio con un nombre suficientemente largo para ocupar varias líneas';
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(repository: FakeTextCaptureRepository()),
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ProposalCard(
                  entry: ProposalEntry(1, proposal(description: description)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Descripción'), findsOneWidget);
    expect(find.text(description), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('proposal-description'))).height,
      greaterThan(48),
    );
  });
}
