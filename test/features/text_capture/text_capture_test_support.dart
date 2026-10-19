import 'dart:async';

import 'package:finance_ai/core/time/clock_provider.dart';
import 'package:finance_ai/features/accounts/data/accounts_repository.dart';
import 'package:finance_ai/features/accounts/domain/account_models.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/budgets/application/budgets_controller.dart';
import 'package:finance_ai/features/budgets/application/budgets_state.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:finance_ai/features/expenses/data/expenses_repository.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/expenses/domain/history_models.dart';
import 'package:finance_ai/features/income_sources/data/income_sources_repository.dart';
import 'package:finance_ai/features/income_sources/domain/income_source_models.dart';
import 'package:finance_ai/features/text_capture/data/text_capture_repository.dart';
import 'package:finance_ai/features/text_capture/domain/text_capture_models.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

const cop = CurrencySummary(
  id: 1,
  code: 'COP',
  name: 'Colombian Peso',
  decimals: 2,
);
const usd = CurrencySummary(id: 2, code: 'USD', name: 'US Dollar', decimals: 2);

Account account(
  int id,
  String name, {
  CurrencySummary currency = cop,
  String balance = '100000.00',
}) => Account(
  id: id,
  name: name,
  type: AccountType.cash,
  currency: currency,
  balance: MoneyAmount.parseApi(balance),
  openingBalance: MoneyAmount.parseApi(balance),
  currencyIsLocked: false,
  isActive: true,
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

final accounts = [
  account(1, 'Efectivo'),
  account(2, 'Nequi'),
  account(4, 'Dólares', currency: usd),
];

Map<String, Object?> proposalJson({
  String id = '11111111-1111-4111-8111-111111111111',
  int revision = 1,
  String status = 'ready',
  String? intent = 'expense',
  double confidence = 0.95,
  bool oneTap = true,
  String originalText = 'Almorcé en Subway 15900 con efectivo',
  List<String> followUps = const [],
  String? message,
  String? amount = '15900.00',
  String? currencyCode = 'COP',
  String? destinationAmount,
  String date = '2026-10-02',
  String? description = 'Almuerzo en Subway',
  Map<String, Object?>? account = const {
    'id': 1,
    'name': 'Efectivo',
    'currency_code': 'COP',
  },
  Map<String, Object?>? destinationAccount,
  Map<String, Object?>? category = const {'id': 10, 'name': 'Comida'},
  Map<String, Object?>? incomeSource,
  Map<String, Object?>? clarification,
  List<String> notes = const [],
}) => {
  'proposal_id': id,
  'revision': revision,
  'status': status,
  'intent': intent,
  'confidence': confidence,
  'one_tap': oneTap,
  'original_text': originalText,
  'follow_ups': followUps,
  'message': message,
  'amount': amount,
  'currency_code': currencyCode,
  'destination_amount': destinationAmount,
  'date': date,
  'description': description,
  'account': account,
  'destination_account': destinationAccount,
  'category': category,
  'income_source': incomeSource,
  'clarification': clarification,
  'notes': notes,
  'created_at': '2026-10-02T20:00:00Z',
  'expires_at': '2026-10-03T20:00:00Z',
};

TextProposal proposal({
  String status = 'ready',
  String? intent = 'expense',
  bool oneTap = true,
  double confidence = 0.95,
  String? amount = '15900.00',
  String? description = 'Almuerzo en Subway',
  Map<String, Object?>? account = const {
    'id': 1,
    'name': 'Efectivo',
    'currency_code': 'COP',
  },
  Map<String, Object?>? destinationAccount,
  Map<String, Object?>? category = const {'id': 10, 'name': 'Comida'},
  Map<String, Object?>? clarification,
  Map<String, Object?>? incomeSource,
  String? destinationAmount,
  String? message,
  List<String> notes = const [],
  int revision = 1,
}) => TextProposal.fromJson(
  proposalJson(
    status: status,
    intent: intent,
    oneTap: oneTap,
    confidence: confidence,
    amount: amount,
    description: description,
    account: account,
    destinationAccount: destinationAccount,
    category: category,
    clarification: clarification,
    incomeSource: incomeSource,
    destinationAmount: destinationAmount,
    message: message,
    notes: notes,
    revision: revision,
  ),
);

TextProposal accountQuestion() => proposal(
  status: 'needs_clarification',
  oneTap: false,
  confidence: 0.9,
  account: null,
  category: null,
  clarification: {
    'field': 'account',
    'question': '¿Con qué cuenta pagaste?',
    'options': [
      {'value': '1', 'label': 'Efectivo', 'detail': 'COP'},
      {'value': '2', 'label': 'Nequi', 'detail': 'COP'},
    ],
  },
);

TextCaptureConfirmation confirmation({
  CaptureIntent intent = CaptureIntent.expense,
  int recordId = 701,
  bool replayed = false,
}) => TextCaptureConfirmation(
  intent: intent,
  recordId: recordId,
  amount: '15900.00',
  currencyCode: 'COP',
  accountName: 'Efectivo',
  description: 'Almuerzo en Subway',
  replayed: replayed,
);

class ProposeCall {
  const ProposeCall({
    required this.text,
    required this.proposalId,
    required this.choice,
    required this.clientNow,
  });

  final String? text;
  final String? proposalId;
  final ({String field, String value})? choice;
  final DateTime clientNow;
}

/// Scripted repository: queue answers (a proposal or an exception), optionally
/// holding a call open with [gate] to observe the "thinking" state.
class FakeTextCaptureRepository implements TextCaptureRepository {
  FakeTextCaptureRepository({List<Object> proposals = const []})
    : proposeQueue = [...proposals];

  final List<Object> proposeQueue;
  final List<Object> confirmQueue = [];
  final List<ProposeCall> proposeCalls = [];
  final List<(String, TextProposalConfirmCommand)> confirmCalls = [];
  final List<String> discardCalls = [];
  Completer<void>? gate;

  @override
  Future<TextProposal> propose({
    required DateTime clientNow,
    String? text,
    String? proposalId,
    ({String field, String value})? choice,
  }) async {
    proposeCalls.add(
      ProposeCall(
        text: text,
        proposalId: proposalId,
        choice: choice,
        clientNow: clientNow,
      ),
    );
    final hold = gate;
    if (hold != null) await hold.future;
    final next = proposeQueue.removeAt(0);
    if (next is Exception) throw next;
    return next as TextProposal;
  }

  @override
  Future<TextCaptureConfirmation> confirm(
    String proposalId,
    TextProposalConfirmCommand command,
  ) async {
    confirmCalls.add((proposalId, command));
    final hold = gate;
    if (hold != null) await hold.future;
    final next = confirmQueue.isEmpty
        ? confirmation()
        : confirmQueue.removeAt(0);
    if (next is Exception) throw next;
    return next as TextCaptureConfirmation;
  }

  @override
  Future<void> discard(String proposalId) async => discardCalls.add(proposalId);
}

class FakeSession extends AuthSessionController {
  FakeSession({this.userId = 1});

  final int userId;

  @override
  AuthSessionState build() => AuthSessionState(
    status: AuthSessionStatus.authenticated,
    user: AuthenticatedUser(
      id: userId,
      email: 'person@example.com',
      preferredCurrency: 'COP',
    ),
    accessCredential: 'access',
  );

  @override
  Future<T> runProtected<T>(
    Future<T> Function(String accessCredential) request,
  ) => request('access');
}

class FakeAccountsRepository implements AccountsRepository {
  int listCalls = 0;

  @override
  Future<AccountListResult> list({bool includeInactive = false}) async {
    listCalls += 1;
    return AccountListResult(
      accounts: accounts,
      suggestedCurrencyCode: 'COP',
      supportedCurrencies: const [cop, usd],
      accountTypes: AccountType.values,
    );
  }

  @override
  Future<Account> get(int accountId) async => accounts.first;

  @override
  Future<Account> create(AccountCreateCommand command) async => accounts.first;

  @override
  Future<Account> update(int accountId, AccountUpdateCommand command) async =>
      accounts.first;

  @override
  Future<Account> setActive(int accountId, {required bool isActive}) async =>
      accounts.first;

  @override
  Future<void> deleteAccount(int accountId) async {}
}

class FakeCategoriesRepository implements CategoriesRepository {
  CategoryListResult get _result => CategoryListResult(
    categories: [
      Category(
        id: 10,
        name: 'Comida',
        color: CategoryColor.red,
        icon: CategoryIcon.food,
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
      Category(
        id: 11,
        name: 'Transporte',
        color: CategoryColor.blue,
        icon: CategoryIcon.transport,
        sortOrder: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    ],
    supportedColors: const [CategoryColor.red, CategoryColor.blue],
    supportedIcons: const [CategoryIcon.food, CategoryIcon.transport],
  );

  @override
  Future<CategoryListResult> list() async => _result;

  @override
  Future<Category> get(int categoryId) async => _result.categories.first;

  @override
  Future<Category> create(CategoryCreateCommand command) async =>
      _result.categories.first;

  @override
  Future<Category> update(
    int categoryId,
    CategoryUpdateCommand command,
  ) async => _result.categories.first;

  @override
  Future<CategoryListResult> reorder(List<int> categoryIds) async => _result;

  @override
  Future<void> deleteCategory(int categoryId) async {}
}

class FakeIncomeSourcesRepository implements IncomeSourcesRepository {
  @override
  Future<List<IncomeSource>> list({required String accessCredential}) async =>
      const [IncomeSource(id: 20, name: 'Salario')];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Counts reloads so a test can see that Accept refreshes the movements.
class FakeExpensesRepository implements ExpensesRepository {
  int listCalls = 0;
  int historyCalls = 0;

  @override
  Future<ExpenseListResult> list({int page = 1, int pageSize = 50}) async {
    listCalls += 1;
    return const ExpenseListResult(
      items: [],
      total: 0,
      page: 1,
      pageSize: 50,
      hasNext: false,
    );
  }

  @override
  Future<HistoryResult> history(HistoryFilters filters) async {
    historyCalls += 1;
    return const HistoryResult(
      items: [],
      total: 0,
      page: 1,
      pageSize: 50,
      hasNext: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeBudgetsController extends BudgetsController {
  int loadCalls = 0;

  @override
  BudgetsState build() => const BudgetsState();

  @override
  Future<void> load() async {
    loadCalls += 1;
  }
}

/// Overrides shared by the controller and widget tests.
List<Override> baseOverrides({
  required FakeTextCaptureRepository repository,
  FakeAccountsRepository? accountsRepository,
  FakeBudgetsController? budgetsController,
  FakeExpensesRepository? expensesRepository,
  DateTime Function()? clock,
  int userId = 1,
}) => [
  textCaptureRepositoryProvider.overrideWithValue(repository),
  authSessionControllerProvider.overrideWith(() => FakeSession(userId: userId)),
  accountsRepositoryProvider.overrideWithValue(
    accountsRepository ?? FakeAccountsRepository(),
  ),
  categoriesRepositoryProvider.overrideWithValue(FakeCategoriesRepository()),
  incomeSourcesRepositoryProvider.overrideWithValue(
    FakeIncomeSourcesRepository(),
  ),
  budgetsControllerProvider.overrideWith(
    () => budgetsController ?? FakeBudgetsController(),
  ),
  expensesRepositoryProvider.overrideWithValue(
    expensesRepository ?? FakeExpensesRepository(),
  ),
  clockProvider.overrideWithValue(clock ?? () => DateTime(2026, 10, 2, 15, 30)),
];
