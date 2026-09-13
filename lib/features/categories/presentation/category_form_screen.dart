import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../application/categories_controller.dart';
import '../application/categories_state.dart';
import '../domain/category_models.dart';
import 'category_visuals.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({this.categoryId, super.key});

  final int? categoryId;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  CategoryColor _color = CategoryColor.blue;
  CategoryIcon _icon = CategoryIcon.other;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      final controller = ref.read(categoriesControllerProvider.notifier);
      controller.clearMutationFeedback();
      if (ref.read(categoriesControllerProvider).result == null) {
        controller.load();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoriesControllerProvider);
    final category = widget.categoryId == null
        ? null
        : state.result?.categoryById(widget.categoryId!);
    _initialize(category);
    final missing =
        widget.categoryId != null &&
        state.loadStatus == CategoriesLoadStatus.ready &&
        category == null;
    return PopScope(
      canPop: !state.isSaving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to categories',
            onPressed: state.isSaving ? null : () => context.go('/categories'),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            widget.categoryId == null ? 'New category' : 'Edit category',
          ),
          actions: [
            if (widget.categoryId != null && category != null)
              IconButton(
                key: const Key('category-delete-button'),
                tooltip: 'Delete category',
                onPressed: state.isSaving
                    ? null
                    : () => _confirmDelete(category),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  if (state.loadStatus == CategoriesLoadStatus.loading)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Loading category',
                    ),
                  if (state.diagnostic case final diagnostic?) ...[
                    ErrorDiagnosticPanel(diagnostic: diagnostic),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: ref
                          .read(categoriesControllerProvider.notifier)
                          .load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                  if (missing)
                    const Text('This category is no longer available.')
                  else if (_initialized)
                    _form(state, category),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(CategoriesState state, Category? category) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        category == null
            ? 'Create a category that matches how you understand your spending.'
            : 'Update the name and visual style used throughout the app.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 24),
      _preview(),
      const SizedBox(height: 24),
      if (state.mutationDiagnostic case final diagnostic?) ...[
        ErrorDiagnosticPanel(diagnostic: diagnostic),
        const SizedBox(height: 20),
      ],
      TextField(
        key: const Key('category-name-field'),
        controller: _nameController,
        focusNode: _nameFocus,
        enabled: !state.isSaving,
        maxLength: 100,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Category name',
          hintText: 'Food, Transport, Health…',
          errorText: state.fieldErrors['name']?.firstOrNull,
        ),
        onChanged: (_) {
          ref
              .read(categoriesControllerProvider.notifier)
              .clearFieldError('name');
          setState(() {});
        },
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 16),
      Text('Color', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: (state.result?.supportedColors ?? CategoryColor.values)
            .map(
              (color) => ChoiceChip(
                key: Key('category-color-${color.name}'),
                selected: color == _color,
                avatar: CircleAvatar(backgroundColor: color.value),
                label: Text(color.label),
                onSelected: state.isSaving
                    ? null
                    : (_) => setState(() => _color = color),
              ),
            )
            .toList(growable: false),
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<CategoryIcon>(
        key: const Key('category-icon-field'),
        initialValue: _icon,
        decoration: const InputDecoration(labelText: 'Icon'),
        items: (state.result?.supportedIcons ?? CategoryIcon.values)
            .map(
              (icon) => DropdownMenuItem(
                value: icon,
                child: Row(
                  children: [
                    Icon(icon.value),
                    const SizedBox(width: 12),
                    Text(icon.label),
                  ],
                ),
              ),
            )
            .toList(growable: false),
        onChanged: state.isSaving
            ? null
            : (value) {
                if (value != null) setState(() => _icon = value);
              },
      ),
      const SizedBox(height: 28),
      FilledButton(
        key: const Key('category-save-button'),
        onPressed: state.isSaving ? null : _submit,
        child: state.isSaving
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(category == null ? 'Save category' : 'Save changes'),
      ),
    ],
  );

  Widget _preview() => Semantics(
    label:
        'Category preview ${_nameController.text.trim().isEmpty ? 'New category' : _nameController.text.trim()}',
    child: Card(
      color: _color.value.withValues(alpha: 0.12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _color.value,
          foregroundColor: Colors.white,
          child: Icon(_icon.value),
        ),
        title: Text(
          _nameController.text.trim().isEmpty
              ? 'New category'
              : _nameController.text.trim(),
        ),
        subtitle: const Text('Preview'),
      ),
    ),
  );

  void _initialize(Category? category) {
    if (_initialized || (widget.categoryId != null && category == null)) return;
    _initialized = true;
    if (category != null) {
      _nameController.text = category.name;
      _color = category.color;
      _icon = category.icon;
    }
  }

  Future<void> _submit() async {
    final outcome = await ref
        .read(categoriesControllerProvider.notifier)
        .save(
          categoryId: widget.categoryId,
          name: _nameController.text,
          color: _color,
          icon: _icon,
        );
    if (!mounted) return;
    if (outcome == CategoryMutationOutcome.success) {
      context.go('/categories');
    } else if (outcome == CategoryMutationOutcome.invalid) {
      _nameFocus.requestFocus();
    }
  }

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete “${category.name}” permanently? The name can be reused. Future expense history will show “Category deleted” when this category was used.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('category-confirm-delete-button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final outcome = await ref
        .read(categoriesControllerProvider.notifier)
        .deleteCategory(category.id);
    if (mounted && outcome == CategoryMutationOutcome.success) {
      context.go('/categories');
    }
  }
}
