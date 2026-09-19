import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../application/accounts_controller.dart';
import '../application/accounts_state.dart';
import '../domain/account_models.dart';
import '../../incomes/presentation/income_list_screen.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({required this.accountId, super.key});

  final int accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        final controller = ref.read(accountsControllerProvider.notifier);
        controller.clearMutationFeedback();
        controller.loadDetail(widget.accountId);
      }
    });
  }

  @override
  void didUpdateWidget(AccountDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      ref
          .read(accountsControllerProvider.notifier)
          .loadDetail(widget.accountId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountsControllerProvider);
    final controller = ref.read(accountsControllerProvider.notifier);
    final account = state.detailAccountId == widget.accountId
        ? state.detailAccount
        : null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to accounts',
          onPressed: () => context.go('/accounts'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Account details'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                if (state.detailStatus == AccountDetailStatus.loading) ...[
                  Semantics(
                    liveRegion: true,
                    label: 'Loading account details',
                    child: const LinearProgressIndicator(),
                  ),
                  const SizedBox(height: 20),
                ],
                if (state.detailDiagnostic case final diagnostic?) ...[
                  ErrorDiagnosticPanel(diagnostic: diagnostic),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => controller.loadDetail(widget.accountId),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(height: 20),
                ],
                if (account != null) _AccountDetails(account: account),
                if (account != null) ...[
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const Key('account-edit-button'),
                    onPressed: state.isSaving
                        ? null
                        : () =>
                              context.go('/accounts/${widget.accountId}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit account'),
                  ),
                  const SizedBox(height: 12),
                  if (account.isActive)
                    OutlinedButton.icon(
                      key: const Key('account-deactivate-button'),
                      onPressed: state.isSaving
                          ? null
                          : () => _confirmDeactivation(account),
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Deactivate account'),
                    )
                  else
                    OutlinedButton.icon(
                      key: const Key('account-reactivate-button'),
                      onPressed: state.isSaving
                          ? null
                          : () => _setActive(account, isActive: true),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Reactivate account'),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('account-delete-button'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: state.isSaving
                        ? null
                        : () => _confirmDeletion(account),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete account permanently'),
                  ),
                ],
                if (state.isSaving) ...[
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    label: 'Saving account status',
                    child: const LinearProgressIndicator(),
                  ),
                ],
                if (state.mutationDiagnostic case final diagnostic?) ...[
                  const SizedBox(height: 20),
                  ErrorDiagnosticPanel(diagnostic: diagnostic),
                ],
                if (state.requiresMutationReview) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: controller.resolveUncertainMutation,
                    icon: const Icon(Icons.sync),
                    label: const Text('Refresh before trying again'),
                  ),
                ],
                if (account != null) ...[
                  const SizedBox(height: 28),
                  AccountIncomeActivity(accountId: account.id),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeactivation(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate this account?'),
        content: const Text(
          'This account will remain in your history but will no longer be available for new financial entries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('account-confirm-deactivate-button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _setActive(account, isActive: false);
    }
  }

  Future<void> _confirmDeletion(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this account permanently?'),
        content: const Text(
          'This permanently removes the account if it has no financial activity. This cannot be undone. Accounts with activity must be deactivated instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('account-confirm-delete-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final outcome = await ref
        .read(accountsControllerProvider.notifier)
        .deleteAccount(account.id);
    if (!mounted || outcome != AccountMutationOutcome.success) {
      return;
    }
    context.go('/accounts');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account permanently deleted.')),
    );
  }

  Future<void> _setActive(Account account, {required bool isActive}) async {
    final outcome = await ref
        .read(accountsControllerProvider.notifier)
        .setActive(account.id, isActive: isActive);
    if (!mounted || outcome != AccountMutationOutcome.success) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isActive ? 'Account reactivated.' : 'Account deactivated.',
        ),
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final balance = account.balance.formatWithCurrency(account.currency.code);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(account.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: Icon(
              account.isActive ? Icons.check_circle_outline : Icons.pause,
            ),
            label: Text(account.isActive ? 'Active' : 'Inactive'),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          label: account.balance.isNegative
              ? 'Negative current balance $balance'
              : 'Current balance $balance',
          child: ExcludeSemantics(
            child: _DetailRow(label: 'Current balance', value: balance),
          ),
        ),
        _DetailRow(
          label: 'Opening balance',
          value: account.openingBalance.formatWithCurrency(
            account.currency.code,
          ),
        ),
        _DetailRow(label: 'Type', value: account.type.label),
        _DetailRow(
          label: 'Currency',
          value: '${account.currency.code} · ${account.currency.name}',
        ),
        if (account.currencyIsLocked)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Currency is locked because this account has confirmed activity.',
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
