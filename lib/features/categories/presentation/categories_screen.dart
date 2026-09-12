import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
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
      if (mounted &&
          ref.read(categoriesControllerProvider).loadStatus ==
              CategoriesLoadStatus.initial) {
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
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to home',
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Categories'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('categories-add-button'),
        onPressed: state.result == null || state.isSaving
            ? null
            : () => context.go('/categories/new'),
        icon: const Icon(Icons.add),
        label: const Text('New category'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                if (state.loadStatus == CategoriesLoadStatus.loading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Loading categories',
                  ),
                if (state.diagnostic case final diagnostic?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        ErrorDiagnosticPanel(diagnostic: diagnostic),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: controller.load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (state.mutationDiagnostic case final diagnostic?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: ErrorDiagnosticPanel(diagnostic: diagnostic),
                  ),
                Expanded(
                  child: categories == null
                      ? const Center(child: CircularProgressIndicator())
                      : categories.isEmpty
                      ? const _EmptyCategories()
                      : RefreshIndicator(
                          onRefresh: controller.load,
                          child: ReorderableListView.builder(
                            key: const Key('categories-list'),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                            buildDefaultDragHandles: false,
                            itemCount: categories.length,
                            onReorderItem: state.isSaving
                                ? (_, _) {}
                                : (oldIndex, newIndex) =>
                                      _reorder(categories, oldIndex, newIndex),
                            itemBuilder: (context, index) => _CategoryCard(
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      key: Key('category-card-${category.id}'),
      onTap: disabled
          ? null
          : () => context.go('/categories/${category.id}/edit'),
      leading: CircleAvatar(
        backgroundColor: category.color.value.withValues(alpha: 0.16),
        foregroundColor: category.color.value,
        child: Icon(category.icon.value),
      ),
      title: Text(category.name),
      subtitle: Text('Position ${index + 1}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('category-up-${category.id}'),
            tooltip: 'Move ${category.name} up',
            onPressed: disabled || index == 0 ? null : () => onMove(-1),
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            key: Key('category-down-${category.id}'),
            tooltip: 'Move ${category.name} down',
            onPressed: disabled || index == count - 1 ? null : () => onMove(1),
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          ReorderableDragStartListener(
            index: index,
            enabled: !disabled,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.drag_handle, semanticLabel: 'Drag to reorder'),
            ),
          ),
        ],
      ),
    ),
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
        'Create a category to classify expenses',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        'New expenses will require a category. There is no selectable Uncategorized option.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}
