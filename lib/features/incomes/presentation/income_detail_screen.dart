import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../data/incomes_repository.dart';
import '../domain/income_models.dart';

class IncomeDetailScreen extends ConsumerStatefulWidget {
  const IncomeDetailScreen({required this.incomeId, super.key});

  final int incomeId;

  @override
  ConsumerState<IncomeDetailScreen> createState() => _IncomeDetailScreenState();
}

class _IncomeDetailScreenState extends ConsumerState<IncomeDetailScreen> {
  late Future<Income> _incomeFuture;
  int _loadedRevision = 0;
  bool _deleting = false;
  bool _uncertain = false;
  ErrorDiagnostic? _diagnostic;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(IncomeDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incomeId != widget.incomeId) _reload();
  }

  void _reload() {
    _incomeFuture = ref.read(incomesRepositoryProvider).get(widget.incomeId);
  }

  Future<void> _confirmDelete() async {
    if (_deleting || _uncertain) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este ingreso?'),
        content: const Text(
          'Se quitará de la actividad y se revertirá su efecto en el saldo. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('income-confirm-delete-button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar ingreso'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _diagnostic = null;
    });
    try {
      await ref.read(incomesRepositoryProvider).delete(widget.incomeId);
      if (!mounted) return;
      ref.read(incomeRevisionProvider.notifier).changed();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/incomes');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingreso eliminado y saldo actualizado.')),
      );
    } on IncomeFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _uncertain = failure.outcomeUncertain;
        _diagnostic = ErrorDiagnostic.capture(
          code: failure.code,
          operation: 'delete_income',
          userMessage: failure.userMessage,
          correlationId: failure.correlationId,
          technicalReason: failure.technicalReason,
        );
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _diagnostic = ErrorDiagnostic.capture(
          code: 'unexpected_client_error',
          operation: 'delete_income',
          userMessage: 'No pudimos confirmar la eliminación. Revisa la lista antes de intentarlo de nuevo.',
          technicalReason: 'unclassified_client_failure',
        );
        _uncertain = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final revision = ref.watch(incomeRevisionProvider);
    if (revision != _loadedRevision) {
      _loadedRevision = revision;
      _reload();
    }
    return ManagementPageScaffold(
      title: 'Detalle del ingreso',
      maxWidth: 680,
      leading: HeaderIconButton(
        icon: FinanceIcons.arrowBack,
        tooltip: context.canPop() ? 'Volver' : 'Volver a ingresos',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/incomes');
          }
        },
      ),
      body: FutureBuilder<Income>(
        future: _incomeFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final failure = error is IncomeFailure ? error : null;
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ErrorDiagnosticPanel(
                    diagnostic: ErrorDiagnostic.capture(
                      code: failure?.code ?? 'unexpected_client_error',
                      operation: 'load_income_detail',
                      userMessage:
                          failure?.userMessage ??
                          'No pudimos cargar este ingreso.',
                      correlationId: failure?.correlationId ?? 'unavailable',
                      technicalReason:
                          failure?.technicalReason ??
                          'unclassified_client_failure',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(_reload),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final income = snapshot.data!;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Text(
                income.amount.formatWithCurrency(income.currencyCode),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              ManageCard(
                children: [
                  ManageRow(title: 'Cuenta', subtitle: income.accountName),
                  ManageRow(
                    title: 'Fecha',
                    subtitle: incomeDateWire(income.date),
                  ),
                  ManageRow(
                    title: 'Fuente',
                    subtitle: income.incomeSourceName ?? 'Sin fuente',
                  ),
                  ManageRow(
                    title: 'Descripción',
                    subtitle: income.description ?? 'Sin descripción',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('income-edit-button'),
                onPressed: _deleting || _uncertain
                    ? null
                    : () async {
                        await context.push('/incomes/${income.id}/edit');
                        if (context.mounted) {
                          setState(_reload);
                        }
                      },
                icon: const Icon(FinanceIcons.editOutlined),
                label: const Text('Editar ingreso'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('income-delete-button'),
                onPressed: _deleting || _uncertain ? null : _confirmDelete,
                icon: const Icon(FinanceIcons.deleteOutline),
                label: const Text('Eliminar ingreso'),
              ),
              if (_deleting) const LinearProgressIndicator(),
              if (_diagnostic != null) ...[
                const SizedBox(height: 16),
                ErrorDiagnosticPanel(diagnostic: _diagnostic!),
              ],
              if (_uncertain)
                OutlinedButton(
                  onPressed: () => context.go('/incomes'),
                  child: const Text('Revisar lista antes de volver a intentar'),
                ),
            ],
          );
        },
      ),
    );
  }
}
