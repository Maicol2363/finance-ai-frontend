import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/catalog_labels.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../../../core/widgets/theme_toggle_button.dart';
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
    return ManagementPageScaffold(
      title: 'Detalle de cuenta',
      subtitle: 'Consulta saldos y movimientos',
      leading: HeaderIconButton(
        icon: FinanceIcons.arrowBack,
        tooltip: 'Volver a cuentas',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/accounts'),
      ),
      actions: const [ThemeToggleButton()],
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (state.detailStatus == AccountDetailStatus.loading) ...[
            Semantics(
              liveRegion: true,
              label: 'Cargando detalles de la cuenta',
              child: const LinearProgressIndicator(),
            ),
            const SizedBox(height: 20),
          ],
          if (state.detailDiagnostic case final diagnostic?) ...[
            ErrorDiagnosticPanel(diagnostic: diagnostic),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => controller.loadDetail(widget.accountId),
              icon: const Icon(FinanceIcons.refresh),
              label: const Text('Reintentar'),
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
                  : () => context.push('/accounts/${widget.accountId}/edit'),
              icon: const Icon(FinanceIcons.editOutlined),
              label: const Text('Editar cuenta'),
            ),
            const SizedBox(height: 12),
            if (account.isActive)
              OutlinedButton.icon(
                key: const Key('account-deactivate-button'),
                onPressed: state.isSaving
                    ? null
                    : () => _confirmDeactivation(account),
                icon: const Icon(FinanceIcons.pauseCircleOutline),
                label: const Text('Desactivar cuenta'),
              )
            else
              OutlinedButton.icon(
                key: const Key('account-reactivate-button'),
                onPressed: state.isSaving
                    ? null
                    : () => _setActive(account, isActive: true),
                icon: const Icon(FinanceIcons.playCircleOutline),
                label: const Text('Reactivar cuenta'),
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
              icon: const Icon(FinanceIcons.deleteOutline),
              label: const Text('Eliminar cuenta definitivamente'),
            ),
          ],
          if (state.isSaving) ...[
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              label: 'Guardando estado de la cuenta',
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
              icon: const Icon(FinanceIcons.sync),
              label: const Text('Actualizar antes de volver a intentar'),
            ),
          ],
          if (account != null) ...[
            const SizedBox(height: 28),
            AccountIncomeActivity(accountId: account.id),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeactivation(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Desactivar esta cuenta?'),
        content: const Text(
          'La cuenta seguirá en tu historial, pero no estará disponible para registrar nuevos movimientos.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('account-confirm-deactivate-button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Desactivar'),
                ),
              ),
            ],
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
        title: const Text('¿Eliminar esta cuenta definitivamente?'),
        content: const Text(
          'La cuenta se elimina si no tiene movimientos. Esta acción no se puede deshacer. Si tiene movimientos, debes desactivarla.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('account-confirm-delete-button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Eliminar definitivamente'),
                ),
              ),
            ],
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
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/accounts');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta eliminada definitivamente.')),
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
        content: Text(isActive ? 'Cuenta reactivada.' : 'Cuenta desactivada.'),
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
              account.isActive
                  ? FinanceIcons.checkCircleOutline
                  : FinanceIcons.pause,
            ),
            label: Text(account.isActive ? 'Activa' : 'Inactiva'),
          ),
        ),
        const SizedBox(height: 20),
        ManageCard(
          children: [
            Semantics(
              label: account.balance.isNegative
                  ? 'Saldo actual negativo: $balance'
                  : 'Saldo actual: $balance',
              child: ExcludeSemantics(
                child: ManageRow(title: 'Saldo actual', subtitle: balance),
              ),
            ),
            ManageRow(
              title: 'Saldo inicial',
              subtitle: account.openingBalance.formatWithCurrency(
                account.currency.code,
              ),
            ),
            ManageRow(title: 'Tipo', subtitle: account.type.label),
            ManageRow(
              title: 'Moneda',
              subtitle:
                  '${account.currency.code} · ${CatalogLabels.display(account.currency.name)}',
            ),
          ],
        ),
        if (account.currencyIsLocked)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'La moneda está bloqueada porque esta cuenta ya tiene movimientos confirmados.',
            ),
          ),
      ],
    );
  }
}
