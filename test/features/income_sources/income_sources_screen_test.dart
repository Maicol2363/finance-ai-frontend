import 'package:finance_ai/core/theme/app_theme.dart';
import 'package:finance_ai/features/income_sources/data/income_sources_repository.dart';
import 'package:finance_ai/features/income_sources/domain/income_source_models.dart';
import 'package:finance_ai/features/income_sources/presentation/income_sources_controller.dart';
import 'package:finance_ai/features/income_sources/presentation/income_sources_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ScreenFakeRepository implements IncomeSourcesRepository {
  ScreenFakeRepository({
    this.items = const [IncomeSource(id: 1, name: 'Salary')],
  });

  List<IncomeSource> items;
  final created = <String>[];
  final deleted = <int>[];

  @override
  Future<List<IncomeSource>> list({required String accessCredential}) async =>
      List.of(items);

  @override
  Future<IncomeSource> create({
    required String accessCredential,
    required String name,
  }) async {
    created.add(name);
    final record = IncomeSource(id: 2, name: name.trim());
    items = [...items, record];
    return record;
  }

  @override
  Future<IncomeSource> rename({
    required String accessCredential,
    required int id,
    required String name,
  }) async {
    final updated = IncomeSource(id: id, name: name.trim());
    items = items.map((item) => item.id == id ? updated : item).toList();
    return updated;
  }

  @override
  Future<void> delete({
    required String accessCredential,
    required int id,
  }) async {
    deleted.add(id);
    items = items.where((item) => item.id != id).toList();
  }
}

Future<void> pumpScreen(
  WidgetTester tester,
  ScreenFakeRepository repository, {
  Size surfaceSize = const Size(1600, 1000),
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        incomeSourcesRepositoryProvider.overrideWithValue(repository),
        accessCredentialProvider.overrideWithValue('token'),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const IncomeSourcesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the catalog and adds a value', (tester) async {
    final repository = ScreenFakeRepository();
    await pumpScreen(tester, repository);

    expect(find.text('Salary'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('income-source-name-field')),
      'Freelance',
    );
    await tester.tap(find.byKey(const Key('income-source-add-button')));
    await tester.pumpAndSettle();

    expect(repository.created, ['Freelance']);
    expect(find.text('Freelance'), findsOneWidget);
  });

  testWidgets('requires confirmation before deleting', (tester) async {
    final repository = ScreenFakeRepository();
    await pumpScreen(tester, repository);

    await tester.tap(find.byKey(const Key('income-source-delete-1')));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar fuente de ingreso'), findsOneWidget);

    await tester.tap(find.byKey(const Key('income-source-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repository.deleted, [1]);
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets('renames a value through the dialog', (tester) async {
    final repository = ScreenFakeRepository();
    await pumpScreen(tester, repository);

    await tester.tap(find.byKey(const Key('income-source-rename-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('income-source-rename-field')),
      'Freelance',
    );
    await tester.tap(find.byKey(const Key('income-source-rename-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Freelance'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
  });

  testWidgets(
    'lays out the add button and dialogs under the app theme at desktop size',
    (tester) async {
      final repository = ScreenFakeRepository();
      await pumpScreen(tester, repository, surfaceSize: const Size(2000, 1220));

      // Regression: the theme forces a full-width FilledButton, which used to
      // explode inside the Row with "BoxConstraints forces an infinite width".
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('income-source-name-field')), findsOneWidget);
      expect(find.byKey(const Key('income-source-add-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('income-source-delete-1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('income-source-delete-confirm')),
        findsOneWidget,
      );
    },
  );
}
