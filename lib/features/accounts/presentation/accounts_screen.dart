import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../application/accounts_controller.dart';
import '../application/accounts_state.dart';
import '../domain/account_models.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final state = ref.read(accountsControllerProvider);
      if (state.listStatus == AccountsLoadStatus.initial) {
        ref.read(accountsControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsControllerProvider);
    final controller = ref.read(accountsControllerProvider.notifier);
    final result = state.result;
    return ManagementPageScaffold(
      title: 'Cuentas',
      subtitle: 'Administra tus cuentas y saldos',
      leading: HeaderIconButton(
        icon: FinanceIcons.arrowBack,
        tooltip: 'Volver a la pantalla anterior',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      actions: const [ThemeToggleButton()],
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          key: const Key('accounts-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            FilledButton.icon(
              key: const Key('accounts-add-button'),
              onPressed: result == null
                  ? null
                  : () => context.push('/accounts/new'),
              icon: const Icon(FinanceIcons.add),
              label: const Text('Nueva cuenta'),
            ),
            const SizedBox(height: 12),
            ManageCard(
              children: [
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile.adaptive(
                    key: const Key('accounts-show-inactive'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Mostrar cuentas inactivas'),
                    subtitle: const Text(
                      'Las cuentas inactivas siguen en tu historial financiero.',
                    ),
                    value: state.includeInactive,
                    onChanged: state.listStatus == AccountsLoadStatus.loading
                        ? null
                        : controller.setIncludeInactive,
                  ),
                ),
              ],
            ),
            if (state.listStatus == AccountsLoadStatus.loading) ...[
              Semantics(
                liveRegion: true,
                label: 'Cargando cuentas',
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 16),
            ],
            if (state.listDiagnostic case final diagnostic?) ...[
              ErrorDiagnosticPanel(diagnostic: diagnostic),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: controller.load,
                icon: const Icon(FinanceIcons.refresh),
                label: const Text('Reintentar'),
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              key: const Key('accounts-transfer-button'),
              onPressed: result == null
                  ? null
                  : () => context.push('/accounts/transfer'),
              icon: Icon(FinanceIconCatalog.dataFor(FinanceIconKey.transfer)),
              label: const Text('Transferir entre cuentas'),
            ),
            const SizedBox(height: 16),
            if (result == null &&
                state.listStatus != AccountsLoadStatus.loading &&
                state.listDiagnostic == null)
              const _AccountsLoadingPlaceholder(),
            if (result != null && result.accounts.isEmpty)
              const _AccountsEmptyState(),
            if (result != null)
              for (final account in result.accounts) ...[
                _AccountCard(account: account),
              ],
          ],
        ),
      ),
    );
  }
}

class _AccountsLoadingPlaceholder extends StatelessWidget {
  const _AccountsLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Semantics(
        label: 'Cargando…',
        liveRegion: true,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AccountsEmptyState extends StatelessWidget {
  const _AccountsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            FinanceIcons.accountBalanceWalletOutlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Agrega dónde guardas tu dinero',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Una cuenta puede ser efectivo, Nequi, Bancolombia, ahorros, una tarjeta de crédito u otro lugar donde registres tu dinero.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final balance = account.balance.formatWithCurrency(account.currency.code);
    final balanceMeaning = account.balance.isNegative
        ? 'Saldo negativo: $balance'
        : 'Saldo: $balance';
    return Semantics(
      container: true,
      button: true,
      label:
          '${account.name}, ${account.type.label}, $balanceMeaning, ${account.isActive ? 'activa' : 'inactiva'}',
      child: ExcludeSemantics(
        child: ManageCard(
          children: [
            ManageRow(
              rowKey: Key('account-card-${account.id}'),
              icon: account.isActive
                  ? FinanceIconCatalog.emphasisDataFor(FinanceIconKey.account)
                  : FinanceIcons.pauseCircleOutline,
              title: account.name,
              subtitle:
                  '${account.type.label} · ${account.currency.code}${account.isActive ? '' : ' · Inactiva'}',
              onTap: () => context.push('/accounts/${account.id}'),
              trailing: [
                Text(
                  balance,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: account.balance.isNegative
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
