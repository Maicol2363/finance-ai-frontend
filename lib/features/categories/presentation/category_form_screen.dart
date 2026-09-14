import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/theme_toggle_button.dart';
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
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: widget.categoryId == null
                    ? 'Nueva categoría'
                    : 'Editar categoría',
                subtitle: 'Nombre, color e ícono',
                leading: HeaderIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver a categorías',
                  onPressed: state.isSaving
                      ? null
                      : () => context.go('/categories'),
                ),
                actions: [
                  if (widget.categoryId != null && category != null)
                    IconButton(
                      key: const Key('category-delete-button'),
                      tooltip: 'Eliminar categoría',
                      onPressed: state.isSaving
                          ? null
                          : () => _confirmDelete(category),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  const ThemeToggleButton(),
                ],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                      children: [
                        if (state.loadStatus == CategoriesLoadStatus.loading)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Cargando categoría',
                          ),
                        if (state.diagnostic case final diagnostic?) ...[
                          ErrorDiagnosticPanel(diagnostic: diagnostic),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: ref
                                .read(categoriesControllerProvider.notifier)
                                .load,
                            icon: const Icon(Icons.refresh),
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
                ),
              ),
            ],
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
            ? 'Crea una categoría que refleje cómo entiendes tus gastos.'
            : 'Actualiza el nombre y el estilo visual que se usa en la app.',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 20),
      _preview(),
      const SizedBox(height: 20),
      if (state.mutationDiagnostic case final diagnostic?) ...[
        ErrorDiagnosticPanel(diagnostic: diagnostic),
        const SizedBox(height: 18),
      ],
      const FieldLabel('Nombre', uppercase: false, topSpacing: 0),
      TextField(
        key: const Key('category-name-field'),
        controller: _nameController,
        focusNode: _nameFocus,
        enabled: !state.isSaving,
        maxLength: 100,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
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
                child: GestureDetector(
                  key: Key('category-color-${color.name}'),
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
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 2,
                            )
                          : null,
                    ),
                    child: color == _color
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
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
                child: GestureDetector(
                  key: Key('category-icon-${icon.name}'),
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
            )
            .toList(growable: false),
      ),
      const SizedBox(height: 26),
      FilledButton(
        key: const Key('category-save-button'),
        onPressed: state.isSaving ? null : _submit,
        child: state.isSaving
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(category == null ? 'Guardar categoría' : 'Guardar cambios'),
      ),
    ],
  );

  Widget _preview() => ManageCard(
    children: [
      ManageRow(
        icon: _icon.value,
        swatchColor: _color.value,
        title: _nameController.text.trim().isEmpty
            ? 'Nueva categoría'
            : _nameController.text.trim(),
        subtitle: 'Vista previa',
      ),
    ],
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
        title: const Text('¿Eliminar categoría?'),
        content: Text(
          '¿Eliminar “${category.name}” de forma permanente? El nombre se puede reutilizar. El historial de gastos mostrará “Categoría eliminada” cuando se haya usado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('category-confirm-delete-button'),
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
