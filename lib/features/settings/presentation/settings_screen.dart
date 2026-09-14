import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../categories/application/categories_controller.dart';
import '../../categories/application/categories_state.dart';
import '../../income_sources/domain/income_source_models.dart';
import '../../income_sources/presentation/income_sources_controller.dart';
import '../../income_sources/presentation/income_sources_state.dart';

/// Mockup `screen-ajustes`: Mi cuenta / Catalogos / Apariencia groups
/// (Phase 3 limits stay hidden until their stories exist).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      if (ref.read(categoriesControllerProvider).loadStatus ==
          CategoriesLoadStatus.initial) {
        ref.read(categoriesControllerProvider.notifier).load();
      }
      if (ref.read(accountsControllerProvider).listStatus ==
          AccountsLoadStatus.initial) {
        ref.read(accountsControllerProvider.notifier).load();
      }
      if (ref.read(incomeSourcesControllerProvider).status ==
          IncomeSourcesStatus.loading) {
        ref.read(incomeSourcesControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);
    final accounts = ref.watch(accountsControllerProvider).result?.accounts;
    final categories = ref
        .watch(categoriesControllerProvider)
        .result
        ?.categories;
    final incomeSources = ref.watch(incomeSourcesControllerProvider).items;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(
              title: 'Ajustes',
              subtitle: 'Personaliza tu app',
              actions: [ThemeToggleButton()],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  const SectionTitle('Mi cuenta'),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        rowKey: const Key('settings-accounts-row'),
                        label: 'Cuentas y saldos',
                        subtitle: _countLabel(
                          accounts?.length,
                          singular: 'cuenta',
                          plural: 'cuentas',
                        ),
                        onTap: () => context.go('/accounts'),
                      ),
                    ],
                  ),
                  const SectionTitle('Catálogos'),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        rowKey: const Key('settings-categories-row'),
                        label: 'Categorías',
                        subtitle: _countLabel(
                          categories?.length,
                          singular: 'categoría',
                          plural: 'categorías',
                        ),
                        onTap: () => context.go('/categories'),
                      ),
                      SettingsRow(
                        rowKey: const Key('settings-income-sources-row'),
                        label: 'Fuentes de ingreso',
                        subtitle: _incomeSourcesLabel(incomeSources),
                        onTap: () => context.push('/income-sources'),
                      ),
                    ],
                  ),
                  const SectionTitle('Apariencia'),
                  SettingsGroup(
                    children: [
                      SettingsRow(
                        label: 'Tema',
                        subtitle: 'Claro u oscuro',
                        value: themeMode == ThemeMode.dark ? 'Oscuro' : 'Claro',
                        leading: ManageIcon(
                          themeMode == ThemeMode.dark
                              ? Icons.nightlight_round
                              : Icons.wb_sunny_outlined,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Elegir tema',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                            ),
                            SegmentedControl(
                              keyPrefix: 'theme-mode',
                              labels: const ['Claro', 'Oscuro'],
                              selectedIndex: themeMode == ThemeMode.dark
                                  ? 1
                                  : 0,
                              onChanged: (index) => ref
                                  .read(themeControllerProvider.notifier)
                                  .setDark(index == 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _countLabel(
    int? count, {
    required String singular,
    required String plural,
  }) {
    if (count == null) {
      return null;
    }
    return count == 1 ? '1 $singular' : '$count $plural';
  }

  String? _incomeSourcesLabel(List<IncomeSource> sources) {
    if (sources.isEmpty) {
      return null;
    }
    return sources.map((source) => source.name).join(' · ');
  }
}
