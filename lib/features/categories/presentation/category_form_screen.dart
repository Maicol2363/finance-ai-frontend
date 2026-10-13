import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/management_page_scaffold.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../application/categories_controller.dart';
import '../application/categories_state.dart';
import '../domain/category_models.dart';
import 'category_visuals.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({
    this.categoryId,
    this.returnToPrevious = false,
    super.key,
  });

  final int? categoryId;

  /// When `true` the form was opened from another flow (manual expense
  /// capture) and must return to it instead of the categories list.
  final bool returnToPrevious;

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
      child: ManagementPageScaffold(
        title: widget.categoryId == null
            ? 'Nueva categoría'
            : 'Editar categoría',
        subtitle: 'Nombre, color e ícono',
        leading: HeaderIconButton(
          icon: FinanceIcons.arrowBack,
          tooltip: widget.returnToPrevious
              ? 'Volver al registro'
              : 'Volver a categorías',
          onPressed: state.isSaving ? null : _goBack,
        ),
        actions: [
          if (widget.categoryId != null && category != null)
            HeaderIconButton(
              key: const Key('category-delete-button'),
              tooltip: 'Eliminar categoría',
              icon: FinanceIcons.deleteOutline,
              onPressed: state.isSaving ? null : () => _confirmDelete(category),
            ),
          const ThemeToggleButton(),
        ],
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (state.loadStatus == CategoriesLoadStatus.loading)
              const LinearProgressIndicator(
                semanticsLabel: 'Cargando categoría',
              ),
            if (state.diagnostic case final diagnostic?) ...[
              ErrorDiagnosticPanel(diagnostic: diagnostic),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: ref.read(categoriesControllerProvider.notifier).load,
                icon: const Icon(FinanceIcons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
            if (missing)
              const Text('Esta categoría ya no está disponible.')
            else if (_initialized)
              _form(state, category),
          ],
        ),
      ),
    );
  }

  Widget _form(CategoriesState state, Category? category) => ManagementFormCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.mutationDiagnostic case final diagnostic?) ...[
          ErrorDiagnosticPanel(diagnostic: diagnostic),
          const SizedBox(height: 18),
        ],
        TextField(
          key: const Key('category-name-field'),
          controller: _nameController,
          focusNode: _nameFocus,
          enabled: !state.isSaving,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Comida, Transporte, Salud…',
            errorText: state.fieldErrors['name']?.firstOrNull,
            counterText: '',
          ),
          onChanged: (_) {
            ref
                .read(categoriesControllerProvider.notifier)
                .clearFieldError('name');
            setState(() {});
          },
          onSubmitted: (_) => _submit(),
        ),
        const FieldLabel('Color', uppercase: false),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: (state.result?.supportedColors ?? CategoryColor.values)
              .map(
                (color) => Tooltip(
                  message: color.label,
                  child: Semantics(
                    selected: color == _color,
                    button: true,
                    label: color.label,
                    child: InkWell(
                      key: Key('category-color-${color.name}'),
                      customBorder: const CircleBorder(),
                      onTap: state.isSaving
                          ? null
                          : () => setState(() => _color = color),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.value,
                          shape: BoxShape.circle,
                          border: color == _color
                              ? Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: color == _color
                            ? const Icon(
                                FinanceIcons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const FieldLabel('Ícono', uppercase: false),
        Wrap(
          key: const Key('category-icon-field'),
          spacing: 10,
          runSpacing: 10,
          children: (state.result?.supportedIcons ?? CategoryIcon.values)
              .map(
                (icon) => Tooltip(
                  message: icon.label,
                  child: Semantics(
                    selected: icon == _icon,
                    button: true,
                    label: icon.label,
                    child: InkWell(
                      key: Key('category-icon-${icon.name}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: state.isSaving
                          ? null
                          : () => setState(() => _icon = icon),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: icon == _icon
                              ? context.palette.primarySoft
                              : context.palette.soft,
                          borderRadius: BorderRadius.circular(12),
                          border: icon == _icon
                              ? Border.all(
                                  color: context.palette.primary,
                                  width: 1.6,
                                )
                              : null,
                        ),
                        child: Icon(
                          icon.value,
                          size: 20,
                          color: icon == _icon
                              ? context.palette.primary
                              : context.palette.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        _preview(),
        const SizedBox(height: 26),
        FilledButton(
          key: const Key('category-save-button'),
          onPressed: state.isSaving ? null : _submit,
          child: state.isSaving
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(
                  category == null ? 'Guardar categoría' : 'Guardar cambios',
                ),
        ),
      ],
    ),
  );

  Widget _preview() => Container(
    decoration: BoxDecoration(
      color: context.palette.soft,
      border: Border.all(color: context.palette.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ManageRow(
      icon: _icon.value,
      swatchColor: _color.value,
      title: _nameController.text.trim().isEmpty
          ? 'Nueva categoría'
          : _nameController.text.trim(),
      subtitle: 'Vista previa',
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

  void _goBack() {
    if (widget.returnToPrevious && context.canPop()) {
      context.pop();
      return;
    }
    context.go('/categories');
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
      if (widget.returnToPrevious && context.canPop()) {
        context.pop();
        return;
      }
      context.go('/categories');
    } else if (outcome == CategoryMutationOutcome.invalid) {
      _nameFocus.requestFocus();
    }
  }

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar categoría?'),
        content: Text(
          '¿Eliminar “${category.name}” de forma permanente? El nombre se puede reutilizar. El historial de gastos mostrará “Categoría eliminada” y los presupuestos vinculados también se eliminarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('category-confirm-delete-button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
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
