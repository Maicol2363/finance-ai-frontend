import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/manage_widgets.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../application/categories_controller.dart';
import '../application/categories_state.dart';
import '../domain/category_models.dart';
import 'category_visuals.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        ref.read(categoriesControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoriesControllerProvider);
    final controller = ref.read(categoriesControllerProvider.notifier);
    final categories = state.result?.categories;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Categorías',
              subtitle: 'Clasifica tus gastos',
              leading: HeaderIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Volver',
                onPressed: () => context.go('/home'),
              ),
              actions: const [ThemeToggleButton()],
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      if (state.loadStatus == CategoriesLoadStatus.loading)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Cargando categorías',
                        ),
                      if (state.diagnostic case final diagnostic?)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            children: [
                              ErrorDiagnosticPanel(diagnostic: diagnostic),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: controller.load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: CatalogAddButton(
                          key: const Key('categories-add-button'),
                          label: 'Agregar categoría',
                          hint: 'Color e ícono opcionales',
                          onPressed: state.result == null || state.isSaving
                              ? null
                              : () => context.go('/categories/new'),
                        ),
                      ),
                      if (state.mutationDiagnostic case final diagnostic?)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: ErrorDiagnosticPanel(diagnostic: diagnostic),
                        ),
                      Expanded(
                        child: categories == null
                            ? state.loadStatus == CategoriesLoadStatus.loading
                                ? const Center(child: CircularProgressIndicator())
                                : const SizedBox.shrink()
                            : categories.isEmpty
                            ? const _EmptyCategories()
                            : RefreshIndicator(
                                onRefresh: controller.load,
                                child: ReorderableListView.builder(
                                  key: const Key('categories-list'),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    100,
                                  ),
                                  buildDefaultDragHandles: false,
                                  itemCount: categories.length,
                                  onReorderItem: state.isSaving
                                      ? (_, _) {}
                                      : (oldIndex, newIndex) => _reorder(
                                          categories,
                                          oldIndex,
                                          newIndex,
                                        ),
                                  itemBuilder: (context, index) =>
                                      _CategoryCard(
                                        key: ValueKey(categories[index].id),
                                        category: categories[index],
                                        index: index,
                                        count: categories.length,
                                        disabled: state.isSaving,
                                        onMove: (offset) =>
                                            _move(categories, index, offset),
                                      ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reorder(List<Category> categories, int oldIndex, int newIndex) {
    final ids = categories.map((item) => item.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    ref.read(categoriesControllerProvider.notifier).reorder(ids);
  }

  void _move(List<Category> categories, int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= categories.length) return;
    final ids = categories.map((item) => item.id).toList();
    final value = ids.removeAt(index);
    ids.insert(target, value);
    ref.read(categoriesControllerProvider.notifier).reorder(ids);
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required super.key,
    required this.category,
    required this.index,
    required this.count,
    required this.disabled,
    required this.onMove,
  });

  final Category category;
  final int index;
  final int count;
  final bool disabled;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) => ManageCard(
    children: [
      ManageRow(
        rowKey: Key('category-card-${category.id}'),
        icon: category.icon.value,
        swatchColor: category.color.value,
        title: category.name,
        subtitle: 'Posición ${index + 1}',
        onTap: disabled
            ? null
            : () => context.go('/categories/${category.id}/edit'),
        trailing: [
          ManageActionButton(
            key: Key('category-up-${category.id}'),
            tooltip: 'Mover ${category.name} arriba',
            icon: Icons.keyboard_arrow_up,
            onPressed: disabled || index == 0 ? null : () => onMove(-1),
          ),
          const SizedBox(width: 6),
          ManageActionButton(
            key: Key('category-down-${category.id}'),
            tooltip: 'Mover ${category.name} abajo',
            icon: Icons.keyboard_arrow_down,
            onPressed: disabled || index == count - 1 ? null : () => onMove(1),
          ),
          const SizedBox(width: 6),
          ReorderableDragStartListener(
            index: index,
            enabled: !disabled,
            child: const ManageActionButton(
              tooltip: 'Arrastrar para reordenar',
              icon: Icons.drag_handle,
            ),
          ),
        ],
      ),
    ],
  );
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 64),
      Icon(
        Icons.category_outlined,
        size: 60,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 16),
      Text(
        'Crea una categoría para clasificar tus gastos',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        'Los nuevos gastos requerirán una categoría. No hay opción «Sin categoría».',
        textAlign: TextAlign.center,
      ),
    ],
  );
}
