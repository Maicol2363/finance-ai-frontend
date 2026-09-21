import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../data/incomes_repository.dart';
import '../domain/income_models.dart';

class IncomeListScreen extends ConsumerStatefulWidget {
  const IncomeListScreen({super.key});

  @override
  ConsumerState<IncomeListScreen> createState() => _IncomeListScreenState();
}

class _IncomeListScreenState extends ConsumerState<IncomeListScreen> {
  late Future<List<Income>> _incomeFuture;
  int _loadedRevision = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _incomeFuture = ref.read(incomesRepositoryProvider).list();
  }

  @override
  Widget build(BuildContext context) {
    final revision = ref.watch(incomeRevisionProvider);
    if (revision != _loadedRevision) {
      _loadedRevision = revision;
      _reload();
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver al inicio',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Ingresos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('income-add-button'),
        onPressed: () => context.go('/incomes/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo ingreso'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FutureBuilder<List<Income>>(
              future: _incomeFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _IncomeLoadError(
                    error: snapshot.error!,
                    operation: 'list_incomes',
                    onRetry: () => setState(_reload),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Aún no tienes ingresos registrados.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _incomeFuture;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final income = items[index];
                      return ListTile(
                        key: Key('income-row-${income.id}'),
                        title: Text(
                          income.description ??
                              income.incomeSourceName ??
                              'Ingreso',
                        ),
                        subtitle: Text(
                          '${incomeDateWire(income.date)} · ${income.accountName}',
                        ),
                        trailing: Text(
                          income.amount.formatWithCurrency(income.currencyCode),
                        ),
                        onTap: () => context.go('/incomes/${income.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AccountIncomeActivity extends ConsumerStatefulWidget {
  const AccountIncomeActivity({required this.accountId, super.key});

  final int accountId;

  @override
  ConsumerState<AccountIncomeActivity> createState() =>
      _AccountIncomeActivityState();
}

class _AccountIncomeActivityState extends ConsumerState<AccountIncomeActivity> {
  late Future<List<Income>> _incomeFuture;
  int _loadedRevision = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(AccountIncomeActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) _reload();
  }

  void _reload() {
    _incomeFuture = ref
        .read(incomesRepositoryProvider)
        .list(accountId: widget.accountId);
  }

  @override
  Widget build(BuildContext context) {
    final revision = ref.watch(incomeRevisionProvider);
    if (revision != _loadedRevision) {
      _loadedRevision = revision;
      _reload();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Actividad de ingresos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Income>>(
          future: _incomeFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return _IncomeLoadError(
                error: snapshot.error!,
                operation: 'load_account_income_activity',
                onRetry: () => setState(_reload),
              );
            }
            if (snapshot.data!.isEmpty) {
              return const Text('Sin ingresos en esta cuenta.');
            }
            return Column(
              children: [
                for (final income in snapshot.data!)
                  ListTile(
                    key: Key('account-income-${income.id}'),
                    title: Text(
                      income.description ??
                          income.incomeSourceName ??
                          'Ingreso',
                    ),
                    subtitle: Text(incomeDateWire(income.date)),
                    trailing: Text(
                      income.amount.formatWithCurrency(income.currencyCode),
                    ),
                    onTap: () => context.go('/incomes/${income.id}'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _IncomeLoadError extends StatelessWidget {
  const _IncomeLoadError({
    required this.error,
    required this.operation,
    required this.onRetry,
  });

  final Object error;
  final String operation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error is IncomeFailure ? error as IncomeFailure : null;
    final diagnostic = ErrorDiagnostic.capture(
      code: failure?.code ?? 'unexpected_client_error',
      operation: operation,
      userMessage:
          failure?.userMessage ??
          'No pudimos cargar los ingresos. Inténtalo de nuevo.',
      correlationId: failure?.correlationId ?? 'unavailable',
      technicalReason:
          failure?.technicalReason ?? 'unclassified_client_failure',
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ErrorDiagnosticPanel(diagnostic: diagnostic),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
