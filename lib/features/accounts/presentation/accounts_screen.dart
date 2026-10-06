import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to home',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Accounts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('accounts-add-button'),
        onPressed: result == null ? null : () => context.go('/accounts/new'),
        icon: const Icon(Icons.add),
        label: const Text('New account'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                key: const Key('accounts-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  SwitchListTile.adaptive(
                    key: const Key('accounts-show-inactive'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show inactive accounts'),
                    subtitle: const Text(
                      'Inactive accounts stay visible in financial history.',
                    ),
                    value: state.includeInactive,
                    onChanged: state.listStatus == AccountsLoadStatus.loading
                        ? null
                        : controller.setIncludeInactive,
                  ),
                  if (state.listStatus == AccountsLoadStatus.loading) ...[
                    Semantics(
                      liveRegion: true,
                      label: 'Loading accounts',
                      child: const LinearProgressIndicator(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.listDiagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: controller.load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  FilledButton.tonalIcon(
                    key: const Key('accounts-transfer-button'),
                    onPressed: result == null
                        ? null
                        : () => context.go('/accounts/transfer'),
                    icon: const Icon(Icons.swap_horiz_outlined),
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
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountsLoadingPlaceholder extends StatelessWidget {
  const _AccountsLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
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
            Icons.account_balance_wallet_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Add where your money is held',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'An account can be Cash, Nequi, Bancolombia, savings, a credit card, or another place you track money.',
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
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('account-card-${account.id}'),
            onTap: () => context.go('/accounts/${account.id}'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      account.isActive
                          ? Icons.account_balance_wallet_outlined
                          : Icons.pause_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${account.type.label} · ${account.currency.code}${account.isActive ? '' : ' · Inactive'}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
            ),
          ),
        ),
      ),
    );
  }
}
