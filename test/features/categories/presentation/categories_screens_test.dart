import 'package:finance_ai/app.dart';
import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Category category({int id = 1, String name = 'Needs', int order = 0}) =>
    Category(
      id: id,
      name: name,
      color: CategoryColor.blue,
      icon: CategoryIcon.essentials,
      sortOrder: order,
      createdAt: DateTime.utc(2026, 9, 12),
      updatedAt: DateTime.utc(2026, 9, 12),
    );

CategoryListResult result(List<Category> categories) => CategoryListResult(
  categories: categories,
  supportedColors: CategoryColor.values,
  supportedIcons: CategoryIcon.values,
);

class WidgetCategoriesRepository implements CategoriesRepository {
  CategoryListResult current = result([
    category(),
    category(id: 2, name: 'Wants', order: 1),
  ]);
  CategoryCreateCommand? saved;
  List<int>? reordered;

  @override
  Future<CategoryListResult> list() async => current;

  @override
  Future<Category> get(int categoryId) async =>
      current.categoryById(categoryId)!;

  @override
  Future<Category> create(CategoryCreateCommand command) async {
    saved = command;
    final created = Category(
      id: 3,
      name: command.name,
      color: command.color,
      icon: command.icon,
      sortOrder: current.categories.length,
      createdAt: DateTime.utc(2026, 9, 12),
      updatedAt: DateTime.utc(2026, 9, 12),
    );
    current = result([...current.categories, created]);
    return created;
  }

  @override
  Future<Category> update(int categoryId, CategoryUpdateCommand command) async {
    final changed = Category(
      id: categoryId,
      name: command.name,
      color: command.color,
      icon: command.icon,
      sortOrder: current.categoryById(categoryId)!.sortOrder,
      createdAt: DateTime.utc(2026, 9, 12),
      updatedAt: DateTime.utc(2026, 9, 12),
    );
    current = result([
      for (final item in current.categories)
        if (item.id == categoryId) changed else item,
    ]);
    return changed;
  }

  @override
  Future<CategoryListResult> reorder(List<int> categoryIds) async {
    reordered = categoryIds;
    current = result([
      for (var index = 0; index < categoryIds.length; index++)
        Category(
          id: categoryIds[index],
          name: current.categoryById(categoryIds[index])!.name,
          color: current.categoryById(categoryIds[index])!.color,
          icon: current.categoryById(categoryIds[index])!.icon,
          sortOrder: index,
          createdAt: DateTime.utc(2026, 9, 12),
          updatedAt: DateTime.utc(2026, 9, 12),
        ),
    ]);
    return current;
  }

  @override
  Future<void> deleteCategory(int categoryId) async {
    current = result(
      current.categories.where((item) => item.id != categoryId).toList(),
    );
  }
}

Future<void> pumpCategories(
  WidgetTester tester,
  WidgetCategoriesRepository repository,
  String location,
) async {
  final router = createAppRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [categoriesRepositoryProvider.overrideWithValue(repository)],
      child: FinanceApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('list renders visuals and accessible move controls', (
    tester,
  ) async {
    final repository = WidgetCategoriesRepository();
    await pumpCategories(tester, repository, '/categories');

    expect(find.byKey(const Key('categories-list')), findsOneWidget);
    expect(find.text('Needs'), findsOneWidget);
    expect(find.text('Posición 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('category-down-1')));
    await tester.pumpAndSettle();
    expect(repository.reordered, [2, 1]);
    expect(find.text('Posición 1'), findsOneWidget);
  });

  testWidgets('create form previews and saves selected appearance', (
    tester,
  ) async {
    final repository = WidgetCategoriesRepository();
    await pumpCategories(tester, repository, '/categories/new');

    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Food',
    );
    await tester.tap(find.byKey(const Key('category-color-orange')));
    await tester.ensureVisible(find.byKey(const Key('category-icon-food')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-icon-food')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('category-save-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-save-button')));
    await tester.pumpAndSettle();

    expect(repository.saved?.name, 'Food');
    expect(repository.saved?.color, CategoryColor.orange);
    expect(repository.saved?.icon, CategoryIcon.food);
    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('invalid category name shows a copyable safe diagnostic', (
    tester,
  ) async {
    final repository = WidgetCategoriesRepository();
    await pumpCategories(tester, repository, '/categories/new');

    final saveButton = find.byKey(const Key('category-save-button'));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Error code: category_invalid'), findsOneWidget);
    expect(find.byKey(const Key('copy-error-details-button')), findsOneWidget);
    expect(
      find.text('El nombre de la categoría es obligatorio.'),
      findsOneWidget,
    );
    expect(repository.saved, isNull);
  });

  testWidgets('editing can permanently delete after confirmation', (
    tester,
  ) async {
    final repository = WidgetCategoriesRepository();
    await pumpCategories(tester, repository, '/categories/1/edit');

    expect(find.text('Needs'), findsWidgets);
    await tester.tap(find.byKey(const Key('category-delete-button')));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar categoría?'), findsOneWidget);
    expect(find.textContaining('Categoría eliminada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('category-confirm-delete-button')));
    await tester.pumpAndSettle();

    expect(repository.current.categoryById(1), isNull);
    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('empty list explains required classification', (tester) async {
    final repository = WidgetCategoriesRepository()..current = result([]);
    await pumpCategories(tester, repository, '/categories');
    expect(
      find.text('Crea una categoría para clasificar tus gastos'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No hay opción «Sin categoría»'),
      findsOneWidget,
    );
  });
}
