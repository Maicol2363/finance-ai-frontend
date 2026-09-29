import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/formatters/date_labels.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/money/currency_totals.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/time/clock_provider.dart';
import '../../../core/widgets/movements_empty_state.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../accounts/application/account_balances.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../accounts/domain/account_models.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/application/auth_session_state.dart';
import '../../expenses/application/expenses_controller.dart';
import '../../expenses/application/expenses_state.dart';
import '../../expenses/application/monthly_totals.dart';
import '../../expenses/domain/expense_models.dart';
import '../../expenses/presentation/transaction_visuals.dart';
import '../../incomes/data/incomes_repository.dart';
import '../../incomes/domain/income_models.dart';
import '../../receipt_capture/presentation/receipt_capture_flow.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isWheelOpen = false;
  AnimationController? _wheelAnimation;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) return;
      final expensesState = ref.read(expensesControllerProvider);
      if (expensesState.listStatus == ExpensesLoadStatus.initial) {
        ref.read(expensesControllerProvider.notifier).load();
      }
      final accountsState = ref.read(accountsControllerProvider);
      if (accountsState.listStatus == AccountsLoadStatus.initial) {
        ref.read(accountsControllerProvider.notifier).load();
      }
      ref.read(incomesListProvider);
    });
  }

  AnimationController get _animationController {
    return _wheelAnimation ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _wheelAnimation?.dispose();
    super.dispose();
  }

  void _toggleWheel() {
    setState(() {
      _isWheelOpen = !_isWheelOpen;
      if (_isWheelOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _closeWheel() {
    if (_isWheelOpen) {
      setState(() {
        _isWheelOpen = false;
        _animationController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sessionState = ref.watch(authSessionControllerProvider);
    final sessionController = ref.read(authSessionControllerProvider.notifier);
    final user = sessionState.user;

    final expensesState = ref.watch(expensesControllerProvider);
    final expensesController = ref.read(expensesControllerProvider.notifier);
    final result = expensesState.result;
    final isBusy =
        expensesState.listStatus == ExpensesLoadStatus.loading ||
        expensesState.listStatus == ExpensesLoadStatus.loadingMore;

    final accountsState = ref.watch(accountsControllerProvider);
    final accounts = accountsState.result?.accounts ?? const [];

    if (sessionState.isAuthenticated) {
      if (expensesState.listStatus == ExpensesLoadStatus.initial) {
        Future.microtask(() {
          if (mounted &&
              ref.read(authSessionControllerProvider).isAuthenticated) {
            ref.read(expensesControllerProvider.notifier).load();
          }
        });
      }
      if (accountsState.listStatus == AccountsLoadStatus.initial) {
        Future.microtask(() {
          if (mounted &&
              ref.read(authSessionControllerProvider).isAuthenticated) {
            ref.read(accountsControllerProvider.notifier).load();
          }
        });
      }
    }

    final incomesAsync = ref.watch(incomesListProvider);
    final incomes = incomesAsync.value ?? const [];

    final now = ref.watch(clockProvider)();
    // Balance (stock) and the month chips (flow) share the same definitions as
    // the Dashboard: `activeAccountBalances` and `monthlyTotalsProvider`.
    final stock = activeAccountBalances(accounts);
    final monthTotalsAsync = ref.watch(monthlyTotalsProvider);

    final rawExpenses = result?.items ?? const <Expense>[];
    final seenReceiptIds = <int>{};
    final expenses = <Expense>[];
    for (final exp in rawExpenses) {
      if (exp.captureSource == CaptureSource.ai) {
        if (seenReceiptIds.contains(exp.receiptId)) {
          continue;
        }
        seenReceiptIds.add(exp.receiptId);
      }
      expenses.add(exp);
    }
    final allMovements =
        <_HomeMovement>[
          ...expenses.map(_ExpenseMovement.new),
          ...incomes.map(_IncomeMovement.new),
        ]..sort((a, b) {
          final cmp = b.date.compareTo(a.date);
          if (cmp != 0) return cmp;
          final idA = switch (a) {
            _ExpenseMovement(:final expense) => expense.id,
            _IncomeMovement(:final income) => income.id,
          };
          final idB = switch (b) {
            _ExpenseMovement(:final expense) => expense.id,
            _IncomeMovement(:final income) => income.id,
          };
          return idB.compareTo(idA);
        });
    final recentMovements = allMovements.take(10).toList();

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gastos', key: Key('home-title')),
              Text(
                'registra gastos e ingresos — la IA te ayuda',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('home-search-button'),
              tooltip: 'Buscar en historial',
              onPressed: () => context.push('/history'),
              icon: const Icon(Icons.search),
            ),
            const ThemeToggleButton(),
            IconButton(
              key: const Key('logout-button'),
              tooltip: 'Cerrar sesión',
              onPressed: sessionState.status == AuthSessionStatus.loggingOut
                  ? null
                  : sessionController.logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Future.wait([
                        expensesController.load(),
                        ref.read(accountsControllerProvider.notifier).load(),
                        ref.refresh(incomesListProvider.future),
                      ]);
                    },
                    child: ListView(
                      key: const Key('expenses-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      children: [
                        if (isBusy) ...[
                          Semantics(
                            liveRegion: true,
                            label: 'Cargando gastos',
                            child: const LinearProgressIndicator(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (expensesState.listDiagnostic
                            case final diagnostic?) ...[
                          ErrorDiagnosticPanel(diagnostic: diagnostic),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: expensesController.load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // =================== HUB BALANCE CARD ===================
                        _HubBalanceCard(
                          monthName: DateLabels.monthName(now),
                          userEmail: user?.email,
                          preferredCurrency: user?.preferredCurrency ?? 'COP',
                          stock: stock,
                          monthTotals:
                              monthTotalsAsync.value?.byCurrency ?? const {},
                          monthTotalsAvailable: monthTotalsAsync.hasValue,
                          accounts: accounts,
                          onOpenAccounts: () => context.push('/accounts'),
                        ),

                        // =================== RECENT MOVEMENTS ===================
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Historial reciente',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: palette.text,
                                ),
                              ),
                              if (result != null && recentMovements.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.soft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${recentMovements.length} ${recentMovements.length == 1 ? 'movimiento' : 'movimientos'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: palette.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        if (result == null &&
                            expensesState.listStatus !=
                                ExpensesLoadStatus.loading &&
                            expensesState.listDiagnostic == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          ),

                        if (result != null && recentMovements.isEmpty)
                          MovementsEmptyState(
                            onRegister: () => context.push('/expenses/new'),
                          ),

                        if (result != null && recentMovements.isNotEmpty)
                          for (final movement in recentMovements) ...[
                            switch (movement) {
                              _ExpenseMovement(:final expense) =>
                                _HubExpenseCard(expense: expense),
                              _IncomeMovement(:final income) => _HubIncomeCard(
                                income: income,
                              ),
                            },
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Scrim backdrop when wheel is open
            if (_isWheelOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeWheel,
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),

            // Radial options when open
            if (_isWheelOpen) ...[
              _WheelBubble(
                key: const Key('expenses-wheel-photo'),
                right: 20,
                bottom: 160,
                icon: '📷',
                label: 'Foto',
                animation: _animationController,
                delayRatio: 0.0,
                onTap: () {
                  _closeWheel();
                  // Foto goes straight to the camera, like Instagram: the
                  // gallery is available as a button inside the pre-check.
                  startReceiptCapture(context, source: ImageSource.camera);
                },
              ),
              _WheelBubble(
                key: const Key('expenses-wheel-voice'),
                right: 80,
                bottom: 140,
                icon: '🎤',
                label: 'Voz',
                animation: _animationController,
                delayRatio: 0.1,
                onTap: () {
                  _closeWheel();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Captura por nota de voz próximamente'),
                    ),
                  );
                },
              ),
              _WheelBubble(
                key: const Key('expenses-wheel-text'),
                right: 140,
                bottom: 95,
                icon: 'T',
                label: 'Texto',
                animation: _animationController,
                delayRatio: 0.2,
                onTap: () {
                  _closeWheel();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Captura por texto libre próximamente'),
                    ),
                  );
                },
              ),
              _WheelBubble(
                key: const Key('expenses-wheel-manual'),
                right: 160,
                bottom: 25,
                icon: '✎',
                label: 'Manual',
                animation: _animationController,
                delayRatio: 0.3,
                onTap: () {
                  _closeWheel();
                  context.push('/expenses/new');
                },
              ),
            ],

            // Floating Action Button (Wheel FAB)
            Positioned(
              right: 20,
              bottom: 20,
              child: SizedBox(
                width: 58,
                height: 58,
                child: FloatingActionButton(
                  key: const Key('expenses-create-fab'),
                  elevation: 4,
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  onPressed: _toggleWheel,
                  child: AnimatedRotation(
                    turns: _isWheelOpen ? 0.125 : 0.0, // 45 degrees
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.add, size: 30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== HUB BALANCE CARD ===================
/// Hub card: the app's single "Balance" definition (stock: the sum of the live
/// balances of the active accounts) plus the current-month flow chips.
///
/// Both figures come from the same sources the Dashboard uses
/// (`activeAccountBalances` and `monthlyTotalsProvider`), so the two screens
/// can never disagree.
class _HubBalanceCard extends StatelessWidget {
  const _HubBalanceCard({
    required this.monthName,
    required this.userEmail,
    required this.preferredCurrency,
    required this.stock,
    required this.monthTotals,
    required this.monthTotalsAvailable,
    required this.accounts,
    required this.onOpenAccounts,
  });

  final String monthName;
  final String? userEmail;
  final String preferredCurrency;
  final Map<String, CurrencyTotals> stock;
  final Map<String, CurrencyTotals> monthTotals;

  /// False while the month totals are loading or failed: the chips then show
  /// `—` instead of a made-up zero.
  final bool monthTotalsAvailable;
  final List<Account> accounts;
  final VoidCallback onOpenAccounts;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Money is grouped by currency in integer minor units: amounts in different
    // currencies are never added together.
    final orderedCodes = orderedCurrencyCodes({
      ...stock,
      ...monthTotals,
    }, preferred: preferredCurrency);
    final currency = orderedCodes.isEmpty
        ? preferredCurrency
        : orderedCodes.first;
    final otherCodes = orderedCodes.where((code) => code != currency).toList();

    // Headline: stock of the primary currency (all-time, includes opening
    // balances). The chips below are the month's flow, a different figure.
    final netBalance = stock[currency]?.balance ?? 0;
    final totalIncomes = monthTotals[currency]?.incomes ?? 0;
    final totalExpenses = monthTotals[currency]?.expenses ?? 0;

    final isNegative = netBalance < 0;
    final absBalance = netBalance.abs();
    final balanceSign = isNegative ? '-' : '';
    final formattedBalance = MoneyFormatter.formatWhole(absBalance ~/ 100);
    final activeAccounts = accounts.where((a) => a.isActive).toList();
    final activeCount = activeAccounts.length;
    String balanceLine(int minorUnits, String code) =>
        '${MoneyFormatter.formatMinorUnits(minorUnits)} $code';

    final otherBalanceLines = otherCodes
        .map((code) => balanceLine(stock[code]?.balance ?? 0, code))
        .toList();
    final perCurrencyBalances = orderedCodes
        .map((code) => balanceLine(stock[code]?.balance ?? 0, code))
        .join(' · ');
    final incomesLabel = monthTotalsAvailable
        ? MoneyFormatter.formatSignedMinorUnits(totalIncomes)
        : '—';
    final expensesLabel = monthTotalsAvailable
        ? '-${MoneyFormatter.formatMinorUnits(totalExpenses)}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo en cuentas',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.muted,
                ),
              ),
              if (userEmail != null)
                Text(
                  userEmail!,
                  key: const Key('home-user-context'),
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$balanceSign\$ $formattedBalance $currency',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: palette.text,
              letterSpacing: -0.5,
            ),
          ),
          for (final line in otherBalanceLines) ...[
            const SizedBox(height: 2),
            Text(
              line,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Movimientos de $monthName',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: palette.income,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ingresos',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        incomesLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.income,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: palette.discard,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Gastos',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        expensesLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.discard,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.line),
          const SizedBox(height: 10),
          InkWell(
            key: const Key('home-accounts-button'),
            onTap: onOpenAccounts,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: palette.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeCount > 0
                          ? '$activeCount ${activeCount == 1 ? 'cuenta activa' : 'cuentas activas'} · $perCurrencyBalances · Ver saldos'
                          : 'Gestionar cuentas y saldos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 16, color: palette.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

sealed class _HomeMovement {
  const _HomeMovement();
  DateTime get date;
}

class _ExpenseMovement extends _HomeMovement {
  const _ExpenseMovement(this.expense);
  final Expense expense;

  @override
  DateTime get date => expense.occurredAt;
}

class _IncomeMovement extends _HomeMovement {
  const _IncomeMovement(this.income);
  final Income income;

  @override
  DateTime get date => income.date;
}

// =================== HUB EXPENSE CARD ===================
class _HubExpenseCard extends StatelessWidget {
  const _HubExpenseCard({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final displayAmount = expense.receiptTotal ?? expense.amount;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        key: Key('expense-card-${expense.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/expenses/${expense.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    categoryEmoji(expense.category?.name),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.store.isNotEmpty ? expense.store : expense.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.soft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            captureSourceLabel(
                              expense.captureSource,
                              expense.items.length,
                            ),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: palette.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${expense.accountName}${expense.category == null ? '' : ' · ${expense.category!.name}'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.muted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    MoneyFormatter.formatMinorUnits(displayAmount.minorUnits),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: displayAmount.isNegative
                          ? palette.discard
                          : palette.text,
                    ),
                    textAlign: TextAlign.end,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expense.currencyCode,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== HUB INCOME CARD ===================
class _HubIncomeCard extends ConsumerWidget {
  const _HubIncomeCard({required this.income});

  final Income income;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final title = income.description != null && income.description!.isNotEmpty
        ? income.description!
        : (income.incomeSourceName ?? 'Ingreso');

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        key: Key('income-card-${income.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await context.push('/incomes/${income.id}');
          if (context.mounted) {
            ref.read(incomeRevisionProvider.notifier).changed();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.incomeSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(
                  child: Text('💰', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.incomeSoft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'ingreso',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: palette.income,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${income.accountName}${income.incomeSourceName != null ? ' · ${income.incomeSourceName}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.muted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${MoneyFormatter.formatMinorUnits(income.amount.minorUnits)}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: palette.income,
                    ),
                    textAlign: TextAlign.end,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    income.currencyCode,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== WHEEL BUBBLE ===================
class _WheelBubble extends StatelessWidget {
  const _WheelBubble({
    super.key,
    required this.right,
    required this.bottom,
    required this.icon,
    required this.label,
    required this.animation,
    required this.delayRatio,
    required this.onTap,
  });

  final double right;
  final double bottom;
  final String icon;
  final String label;
  final Animation<double> animation;
  final double delayRatio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Interval(delayRatio, 1.0, curve: Curves.easeOutBack),
        );
        return Positioned(
          right: right,
          bottom: bottom,
          child: Transform.scale(
            scale: curved.value,
            child: Opacity(
              opacity: curved.value.clamp(0.0, 1.0),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.line),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A0F172A),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        icon,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
