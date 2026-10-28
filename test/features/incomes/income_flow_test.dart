import 'dart:async';

import 'package:finance_ai/core/router/app_router.dart';
import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:finance_ai/core/widgets/app_header.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/incomes/data/incomes_repository.dart';
import 'package:finance_ai/features/incomes/domain/income_models.dart';
import 'package:finance_ai/features/incomes/presentation/income_form_screen.dart';
import 'package:finance_ai/features/income_sources/domain/income_source_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Income sampleIncome() => Income(
  id: 7,
  accountId: 3,
  accountName: 'Efectivo',
  currencyCode: 'COP',
  amount: MoneyAmount.parseApi('25.50'),
  date: DateTime.utc(2026, 9, 18),
  description: null,
  incomeSourceId: null,
  incomeSourceName: null,
);

class FakeIncomesRepository implements IncomesRepository {
  final items = <Income>[sampleIncome()];
  int deletes = 0;
  Completer<void>? deleteCompletion;
  IncomeWriteCommand? savedCommand;
  IncomeFailure? saveFailure;

  @override
  Future<List<Income>> list({int? accountId}) async => [
    for (final item in items)
      if (accountId == null || item.accountId == accountId) item,
  ];

  @override
  Future<Income> get(int incomeId) async =>
      items.singleWhere((item) => item.id == incomeId);

  @override
  Future<Income> create(IncomeWriteCommand command) async {
    if (saveFailure case final failure?) throw failure;
    savedCommand = command;
    items.add(sampleIncome());
    return sampleIncome();
  }

  @override
  Future<Income> update(int incomeId, IncomeWriteCommand command) async {
    if (saveFailure case final failure?) throw failure;
    savedCommand = command;
    return sampleIncome();
  }

  @override
  Future<void> delete(int incomeId) async {
    deletes++;
    await deleteCompletion?.future;
    items.removeWhere((item) => item.id == incomeId);
  }
}

Account sampleAccount() => Account.fromJson({
  'id': 3,
  'name': 'Efectivo',
  'type': 'cash',
  'currency': {
    'id': 1,
    'code': 'COP',
    'name': 'Peso colombiano',
    'decimals': 2,
  },
  'opening_balance': '0.00',
  'balance': '25.50',
  'currency_is_locked': true,
  'is_active': true,
  'created_at': '2026-09-17T00:00:00Z',
  'updated_at': '2026-09-17T00:00:00Z',
});

void main() {
  test(
    'income wire model accepts optional fields and exact positive money',
    () {
      final income = Income.fromJson({
        'id': 7,
        'account_id': 3,
        'account_name': 'Efectivo',
        'currency_code': 'COP',
        'amount': '25.50',
        'date': '2026-09-18',
        'description': null,
        'income_source_id': null,
        'income_source_name': null,
      });
      expect(income.amount.minorUnits, 2550);
      expect(incomeDateWire(income.date), '2026-09-18');
      expect(() => parseIncomeDate('2026-02-30'), throwsFormatException);
      expect(
        () => Income.fromJson({
          'id': 7,
          'account_id': 3,
          'account_name': 'Efectivo',
          'currency_code': 'COP',
          'amount': '-1.00',
          'date': '2026-09-18',
        }),
        throwsFormatException,
      );
    },
  );

  testWidgets('income list, detail, and confirmed deletion', (tester) async {
    final repository = FakeIncomesRepository();
    final router = createAppRouter(initialLocation: '/incomes');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [incomesRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('income-row-7')), findsOneWidget);
    expect(find.text(r'$ 25,50 COP'), findsOneWidget);
    await tester.tap(find.byKey(const Key('income-row-7')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('income-delete-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('income-delete-button')));
    await tester.pumpAndSettle();
    expect(repository.deletes, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.deletes, 0);
    await tester.tap(find.byKey(const Key('income-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('income-confirm-delete-button')));
    await tester.pumpAndSettle();
    expect(repository.deletes, 1);
    expect(find.text('Aún no tienes ingresos registrados.'), findsOneWidget);
  });

  testWidgets('income detail actions use accessible header icon buttons', (
    tester,
  ) async {
    final repository = FakeIncomesRepository();
    final router = createAppRouter(initialLocation: '/incomes/7');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incomesRepositoryProvider.overrideWithValue(repository),
          incomeFormOptionsProvider.overrideWithValue(
            () async => IncomeFormOptions(
              accounts: [sampleAccount()],
              sources: const [],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final edit = find.byKey(const Key('income-edit-button'));
    final delete = find.byKey(const Key('income-delete-button'));
    expect(edit, findsOneWidget);
    expect(delete, findsOneWidget);
    expect(find.byTooltip('Editar ingreso'), findsOneWidget);
    expect(find.byTooltip('Eliminar ingreso'), findsOneWidget);
    expect(find.bySemanticsLabel('Editar ingreso'), findsOneWidget);
    expect(find.bySemanticsLabel('Eliminar ingreso'), findsOneWidget);
    expect(tester.getSize(edit), const Size(48, 48));
    expect(tester.getSize(delete), tester.getSize(edit));
    expect(tester.getTopLeft(edit).dy, tester.getTopLeft(delete).dy);
    expect(tester.getTopRight(edit).dx, tester.getTopLeft(delete).dx);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: delete,
              matching: find.byIcon(FinanceIcons.deleteOutline),
            ),
          )
          .color,
      Theme.of(tester.element(delete)).colorScheme.error,
    );
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.text('Editar ingreso'), findsOneWidget);
    expect(find.byKey(const Key('income-description-field')), findsOneWidget);
  });

  testWidgets('income detail disables actions while deletion is in progress', (
    tester,
  ) async {
    final repository = FakeIncomesRepository()
      ..deleteCompletion = Completer<void>();
    final router = createAppRouter(initialLocation: '/incomes/7');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [incomesRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('income-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('income-confirm-delete-button')));
    await tester.pump();

    for (final key in [
      const Key('income-edit-button'),
      const Key('income-delete-button'),
    ]) {
      expect(
        tester.widget<HeaderIconButton>(find.byKey(key)).onPressed,
        isNull,
      );
    }
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    repository.deleteCompletion!.complete();
    await tester.pumpAndSettle();
    expect(repository.deletes, 1);
  });

  testWidgets('create form validates locally and saves exact amount', (
    tester,
  ) async {
    final repository = FakeIncomesRepository();
    repository.items.clear();
    final router = createAppRouter(initialLocation: '/incomes/new');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incomesRepositoryProvider.overrideWithValue(repository),
          incomeFormOptionsProvider.overrideWithValue(
            () async => IncomeFormOptions(
              accounts: [sampleAccount()],
              sources: const [IncomeSource(id: 4, name: 'Salary')],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('income-account-field')), findsOneWidget);
    await tester.tap(find.byKey(const Key('income-source-field')));
    await tester.pumpAndSettle();
    expect(find.text('Salario').last, findsOneWidget);
    await tester.tap(find.text('Salario').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('income-amount-field')), '-1');
    await tester.tap(find.byKey(const Key('income-save-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error-diagnostic-code')), findsNothing);
    expect(repository.savedCommand, isNull);
    await tester.enterText(
      find.byKey(const Key('income-amount-field')),
      '25,50',
    );
    await tester.enterText(
      find.byKey(const Key('income-date-field')),
      '2026-09-18',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('income-description-field')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('income-description-field')),
      '  Pago  ',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('income-save-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('income-save-button')));
    await tester.pumpAndSettle();
    expect(repository.savedCommand?.amount.toApiString(), '25.50');
    expect(repository.savedCommand?.description, '  Pago  ');
    expect(repository.savedCommand?.incomeSourceId, 4);
    expect(find.byKey(const Key('income-delete-button')), findsOneWidget);
  });

  testWidgets('edit form loads income and shows safe save failure', (
    tester,
  ) async {
    final repository = FakeIncomesRepository();
    repository.saveFailure = const IncomeFailure(
      code: 'income_account_unavailable',
      userMessage: 'Selecciona una cuenta activa propia.',
      fieldErrors: {
        'account_id': ['Selecciona una cuenta activa.'],
      },
    );
    final router = createAppRouter(initialLocation: '/incomes/7/edit');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incomesRepositoryProvider.overrideWithValue(repository),
          incomeFormOptionsProvider.overrideWithValue(
            () async => IncomeFormOptions(
              accounts: [sampleAccount()],
              sources: const [],
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Editar ingreso'), findsOneWidget);
    expect(find.text('25,50'), findsOneWidget);
    await tester.tap(find.byKey(const Key('income-save-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error-diagnostic-code')), findsNothing);
  });
}
