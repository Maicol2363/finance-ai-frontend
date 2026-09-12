import 'dart:async';

import 'package:finance_ai/features/categories/application/categories_controller.dart';
import 'package:finance_ai/features/categories/application/categories_state.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
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

CategoryListResult result([List<Category>? values]) => CategoryListResult(
  categories: values ?? [category(), category(id: 2, name: 'Wants', order: 1)],
  supportedColors: CategoryColor.values,
  supportedIcons: CategoryIcon.values,
);

class FakeCategoriesRepository implements CategoriesRepository {
  CategoryListResult current = result();
  Object? failure;
  Completer<Category>? pendingCreate;
  int listCalls = 0;

  @override
  Future<CategoryListResult> list() async {
    listCalls += 1;
    if (failure case final value?) throw value;
    return current;
  }

  @override
  Future<Category> get(int categoryId) async =>
      current.categoryById(categoryId)!;

  @override
  Future<Category> create(CategoryCreateCommand command) async {
    if (failure case final value?) throw value;
    if (pendingCreate case final pending?) return pending.future;
    final created = category(
      id: 3,
      name: command.name,
      order: current.categories.length,
    );
    current = result([...current.categories, created]);
    return created;
  }

  @override
  Future<Category> update(int categoryId, CategoryUpdateCommand command) async {
    if (failure case final value?) throw value;
    final changed = category(id: categoryId, name: command.name);
    current = result([
      for (final item in current.categories)
        if (item.id == categoryId) changed else item,
    ]);
    return changed;
  }

  @override
  Future<CategoryListResult> reorder(List<int> categoryIds) async {
    if (failure case final value?) throw value;
    current = result([
      for (var index = 0; index < categoryIds.length; index++)
        category(
          id: categoryIds[index],
          name: current.categoryById(categoryIds[index])!.name,
          order: index,
        ),
    ]);
    return current;
  }

  @override
  Future<void> deleteCategory(int categoryId) async {
    if (failure case final value?) throw value;
    current = result(
      current.categories.where((item) => item.id != categoryId).toList(),
    );
  }
}

ProviderContainer containerFor(FakeCategoriesRepository repository) =>
    ProviderContainer(
      overrides: [categoriesRepositoryProvider.overrideWithValue(repository)],
    );

void main() {
  test('loads, creates, updates, reorders, and permanently deletes', () async {
    final repository = FakeCategoriesRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(categoriesControllerProvider.notifier);

    await controller.load();
    expect(
      await controller.save(
        name: ' Food ',
        color: CategoryColor.orange,
        icon: CategoryIcon.food,
      ),
      CategoryMutationOutcome.success,
    );
    expect(
      await controller.save(
        categoryId: 1,
        name: 'Essentials',
        color: CategoryColor.blue,
        icon: CategoryIcon.essentials,
      ),
      CategoryMutationOutcome.success,
    );
    expect(
      await controller.reorder([3, 2, 1]),
      CategoryMutationOutcome.success,
    );
    expect(await controller.deleteCategory(2), CategoryMutationOutcome.success);
    expect(
      container
          .read(categoriesControllerProvider)
          .result
          ?.categories
          .map((e) => e.id),
      [3, 1],
    );
  });

  test('validates names and ignores a concurrent save', () async {
    final pending = Completer<Category>();
    final repository = FakeCategoriesRepository()..pendingCreate = pending;
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(categoriesControllerProvider.notifier);

    expect(
      await controller.save(
        name: ' ',
        color: CategoryColor.blue,
        icon: CategoryIcon.other,
      ),
      CategoryMutationOutcome.invalid,
    );
    expect(
      container.read(categoriesControllerProvider).fieldErrors,
      contains('name'),
    );
    controller.clearFieldError('name');
    final first = controller.save(
      name: 'Food',
      color: CategoryColor.orange,
      icon: CategoryIcon.food,
    );
    expect(
      await controller.save(
        name: 'Other',
        color: CategoryColor.gray,
        icon: CategoryIcon.other,
      ),
      CategoryMutationOutcome.ignored,
    );
    repository.current = result([
      ...repository.current.categories,
      category(id: 3, name: 'Food', order: 2),
    ]);
    pending.complete(category(id: 3, name: 'Food', order: 2));
    expect(await first, CategoryMutationOutcome.success);
  });

  test('safe failure diagnostics never copy category form values', () async {
    final repository = FakeCategoriesRepository()
      ..failure = const CategoryFailure(
        code: 'category_name_conflict',
        userMessage: 'Choose a different category name.',
        correlationId: 'category-conflict',
        technicalReason: 'http_409',
      );
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(categoriesControllerProvider.notifier);

    await controller.load();
    repository.failure = const CategoryFailure(
      code: 'category_name_conflict',
      userMessage: 'Choose a different category name.',
      correlationId: 'category-conflict',
      technicalReason: 'http_409',
    );
    final outcome = await controller.save(
      name: 'Private category name',
      color: CategoryColor.red,
      icon: CategoryIcon.other,
    );
    expect(outcome, CategoryMutationOutcome.failure);
    final report = container
        .read(categoriesControllerProvider)
        .mutationDiagnostic
        ?.clipboardText;
    expect(report, contains('category-conflict'));
    expect(report, isNot(contains('Private category name')));
    controller.clearMutationFeedback();
  });
}
