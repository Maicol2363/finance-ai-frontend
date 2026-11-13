import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../../core/formatters/catalog_labels.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/management_page_scaffold.dart';
import '../../../../core/widgets/manage_widgets.dart';
import '../domain/income_source_models.dart';
import 'income_sources_controller.dart';
import 'income_sources_state.dart';

class IncomeSourcesScreen extends ConsumerStatefulWidget {
  const IncomeSourcesScreen({super.key});

  @override
  ConsumerState<IncomeSourcesScreen> createState() =>
      _IncomeSourcesScreenState();
}

class _IncomeSourcesScreenState extends ConsumerState<IncomeSourcesScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incomeSourcesControllerProvider);
    final controller = ref.read(incomeSourcesControllerProvider.notifier);
    return ManagementPageScaffold(
      title: 'Fuentes de ingreso',
      subtitle: 'Nombra de dónde viene tu dinero',
      leading: HeaderIconButton(
        icon: FinanceIcons.arrowBack,
        tooltip: 'Volver',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.diagnostic != null) ...[
            ErrorDiagnosticPanel(diagnostic: state.diagnostic!),
            const SizedBox(height: 16),
          ],
          _addCard(state, controller),
          const SizedBox(height: 16),
          Expanded(child: _body(state, controller)),
        ],
      ),
    );
  }

  Widget _addCard(
    IncomeSourcesState state,
    IncomeSourcesController controller,
  ) {
    return ManagementFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('income-source-name-field'),
            controller: _nameController,
            enabled: !state.busy,
            decoration: InputDecoration(
              labelText: 'Nueva fuente',
              hintText: 'Salario, Freelance, Otros…',
              errorText: state.fieldErrors['name']?.firstOrNull,
            ),
            onSubmitted: (_) => _add(controller),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('income-source-add-button'),
            onPressed: state.busy ? null : () => _add(controller),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Widget _body(IncomeSourcesState state, IncomeSourcesController controller) {
    if (state.status == IncomeSourcesStatus.loading) {
      return Semantics(
        label: 'Cargando…',
        liveRegion: true,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == IncomeSourcesStatus.failure) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Las fuentes de ingreso no están disponibles.'),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('income-source-retry-button'),
              onPressed: controller.load,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(
        child: Text('Aún no hay fuentes de ingreso. Agrega una arriba.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final source in state.items)
          ManageCard(
            children: [
              ManageRow(
                rowKey: Key('income-source-tile-${source.id}'),
                icon: FinanceIconCatalog.dataFor(FinanceIconKey.income),
                title: CatalogLabels.display(source.name),
                subtitle: 'Fuente de ingreso',
                trailing: [
                  ManageActionButton(
                    key: Key('income-source-rename-${source.id}'),
                    tooltip: 'Renombrar',
                    icon: FinanceIcons.editOutlined,
                    onPressed: state.busy
                        ? null
                        : () => _rename(controller, source),
                  ),
                  const SizedBox(width: 6),
                  ManageActionButton(
                    key: Key('income-source-delete-${source.id}'),
                    tooltip: 'Eliminar',
                    icon: FinanceIcons.deleteOutline,
                    destructive: true,
                    onPressed: state.busy
                        ? null
                        : () => _confirmDelete(controller, source),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _add(IncomeSourcesController controller) async {
    final created = await controller.add(_nameController.text);
    if (created) {
      _nameController.clear();
    }
  }

  Future<void> _rename(
    IncomeSourcesController controller,
    IncomeSource source,
  ) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _RenameIncomeSourceDialog(initialName: source.name),
    );
    if (newName == null) {
      return;
    }
    await controller.rename(source.id, newName);
  }

  Future<void> _confirmDelete(
    IncomeSourcesController controller,
    IncomeSource source,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar fuente de ingreso'),
        content: Text(
          '¿Eliminar “${source.name}” de forma permanente? El historial conservará la fuente sin nombre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('income-source-delete-confirm'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.delete(source.id);
    }
  }
}

class _RenameIncomeSourceDialog extends StatefulWidget {
  const _RenameIncomeSourceDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameIncomeSourceDialog> createState() =>
      _RenameIncomeSourceDialogState();
}

class _RenameIncomeSourceDialogState extends State<_RenameIncomeSourceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renombrar fuente de ingreso'),
      content: TextField(
        key: const Key('income-source-rename-field'),
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Nuevo nombre'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('income-source-rename-confirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
