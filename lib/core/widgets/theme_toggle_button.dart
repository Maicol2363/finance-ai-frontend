import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';

/// Sun/moon light-dark switch, mirroring the mockup header control.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeControllerProvider) == ThemeMode.dark;
    return IconButton(
      key: const Key('theme-toggle-button'),
      tooltip: isDark ? 'Tema claro' : 'Tema oscuro',
      onPressed: () => ref.read(themeControllerProvider.notifier).toggle(),
      icon: Icon(
        isDark ? FinanceIcons.nightlightRound : FinanceIcons.wbSunnyOutlined,
      ),
    );
  }
}
