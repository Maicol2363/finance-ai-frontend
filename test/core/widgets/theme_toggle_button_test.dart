import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/core/theme/theme_controller.dart';
import 'package:finance_ai/core/widgets/theme_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('theme toggle switches the app between light and dark', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: _ToggleHarness()));

    expect(find.byIcon(FinanceIcons.wbSunnyOutlined), findsOneWidget);
    expect(find.text('light'), findsOneWidget);

    await tester.tap(find.byKey(const Key('theme-toggle-button')));
    await tester.pumpAndSettle();

    expect(find.byIcon(FinanceIcons.nightlightRound), findsOneWidget);
    expect(find.text('dark'), findsOneWidget);
  });
}

class _ToggleHarness extends ConsumerWidget {
  const _ToggleHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: Builder(
        builder: (innerContext) => Scaffold(
          body: Column(
            children: [
              const ThemeToggleButton(),
              Text(
                Theme.of(innerContext).brightness == Brightness.dark
                    ? 'dark'
                    : 'light',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
