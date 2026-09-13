import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/error_diagnostic_panel.dart';
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
    final nameError = state.fieldErrors['name']?.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Income Sources')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.diagnostic != null) ...[
                    ErrorDiagnosticPanel(diagnostic: state.diagnostic!),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('income-source-name-field'),
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'New income source',
                            errorText: nameError,
                          ),
                          onSubmitted: (_) => _add(controller),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        key: const Key('income-source-add-button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 52),
                        ),
                        onPressed: state.busy ? null : () => _add(controller),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _body(state, controller)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _add(IncomeSourcesController controller) async {
    final created = await controller.add(_nameController.text);
    if (created) {
      _nameController.clear();
    }
  }

  Widget _body(IncomeSourcesState state, IncomeSourcesController controller) {
    if (state.status == IncomeSourcesStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == IncomeSourcesStatus.failure) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Income sources are unavailable.'),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('income-source-retry-button'),
              onPressed: controller.load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(child: Text('No income sources yet. Add one above.'));
    }
    return ListView.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final source = state.items[index];
        return ListTile(
          key: Key('income-source-tile-${source.id}'),
          title: Text(source.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: Key('income-source-rename-${source.id}'),
                tooltip: 'Rename',
                icon: const Icon(Icons.edit),
                onPressed: state.busy
                    ? null
                    : () => _rename(controller, source),
              ),
              IconButton(
                key: Key('income-source-delete-${source.id}'),
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: state.busy
                    ? null
                    : () => _confirmDelete(controller, source),
              ),
            ],
          ),
        );
      },
    );
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
        title: const Text('Delete income source'),
        content: Text(
          'Permanently delete "${source.name}"? Historical transactions keep the source cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('income-source-delete-confirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
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
      title: const Text('Rename income source'),
      content: TextField(
        key: const Key('income-source-rename-field'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('income-source-rename-confirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
