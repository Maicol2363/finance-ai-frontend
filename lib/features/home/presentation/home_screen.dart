import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../accounts/application/accounts_state.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/application/auth_session_state.dart';
import '../../expenses/application/expenses_controller.dart';
import '../../expenses/application/expenses_state.dart';
import '../../expenses/domain/expense_models.dart';

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

  String _currentMonthName() {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final now = DateTime.now();
    return months[now.month - 1];
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
                    onRefresh: expensesController.load,
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
                        if (expensesState.listDiagnostic case final diagnostic?) ...[
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
                          monthName: _currentMonthName(),
                          userEmail: user?.email,
                          preferredCurrency: user?.preferredCurrency ?? 'COP',
                          items: result?.items ?? const [],
                          accountCount: accounts.length,
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
                              if (result != null && result.items.isNotEmpty)
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
                                    '${result.items.length} ${result.items.length == 1 ? 'movimiento' : 'movimientos'}',
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

                        if (result != null && result.items.isEmpty)
                          _HubEmptyState(
                            onAddFirst: () => context.go('/expenses/new'),
                          ),

                        if (result != null && result.items.isNotEmpty)
                          for (final expense in result.items) ...[
                            _HubExpenseCard(expense: expense),
                            const SizedBox(height: 10),
                          ],

                        if (result != null && result.hasNext) ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const Key('expenses-load-more-button'),
                            onPressed: isBusy ? null : expensesController.loadMore,
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Cargar más gastos'),
                          ),
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
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Captura con foto de recibos próximamente'),
                    ),
                  );
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
                  context.go('/expenses/new');
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
class _HubBalanceCard extends StatelessWidget {
  const _HubBalanceCard({
    required this.monthName,
    required this.userEmail,
    required this.preferredCurrency,
    required this.items,
    required this.accountCount,
    required this.onOpenAccounts,
  });

  final String monthName;
  final String? userEmail;
  final String preferredCurrency;
  final List<Expense> items;
  final int accountCount;
  final VoidCallback onOpenAccounts;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    var totalExpenses = 0.0;
    for (final exp in items) {
      totalExpenses += double.tryParse(exp.amount.toApiString()) ?? 0.0;
    }
    final currency = items.firstOrNull?.currencyCode ?? preferredCurrency;

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
                'Balance de $monthName',
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
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '- \$ ${totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} $currency',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: palette.text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
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
                        '+ \$ 0',
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
                        '- \$ ${totalExpenses.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
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
                  Text(
                    accountCount > 0
                        ? '$accountCount ${accountCount == 1 ? 'cuenta activa' : 'cuentas activas'} · Ver saldos'
                        : 'Gestionar cuentas y saldos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: palette.muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== HUB EXPENSE CARD ===================
class _HubExpenseCard extends StatelessWidget {
  const _HubExpenseCard({required this.expense});

  final Expense expense;

  String _categoryEmoji(String? categoryName) {
    final lower = (categoryName ?? '').toLowerCase();
    if (lower.contains('comida') ||
        lower.contains('restaurante') ||
        lower.contains('almuerzo') ||
        lower.contains('cafe')) {
      return '🍔';
    }
    if (lower.contains('transporte') ||
        lower.contains('bus') ||
        lower.contains('taxi') ||
        lower.contains('metro')) {
      return '🚌';
    }
    if (lower.contains('suscrip') ||
        lower.contains('stream') ||
        lower.contains('netflix')) {
      return '📺';
    }
    if (lower.contains('mercado') || lower.contains('super')) {
      return '🛒';
    }
    if (lower.contains('salario') ||
        lower.contains('ingreso') ||
        lower.contains('nomina')) {
      return '💰';
    }
    return '💳';
  }

  String _sourceLabel(CaptureSource source) {
    switch (source) {
      case CaptureSource.ai:
        return '✨ IA';
      case CaptureSource.manual:
        return '✎ manual';
      case CaptureSource.import:
        return '📥 import';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final amount = expense.amount.formatWithCurrency(expense.currencyCode);

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
        onTap: () => context.go('/expenses/${expense.id}'),
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
                    _categoryEmoji(expense.category?.name),
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
                            _sourceLabel(expense.captureSource),
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
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: expense.amount.isNegative
                      ? palette.discard
                      : palette.text,
                ),
                textAlign: TextAlign.end,
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

// =================== EMPTY STATE ===================
class _HubEmptyState extends StatelessWidget {
  const _HubEmptyState({required this.onAddFirst});

  final VoidCallback onAddFirst;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Center(
        child: Column(
          children: [
            const Text('🧾', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 12),
            Text(
              'Aún no tienes movimientos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Toca ＋ y elige cómo capturar: 📷 foto · 🎤 voz · T texto · ✎ manual — la IA prepara la vista previa y tú confirmas.',
              style: TextStyle(
                fontSize: 12,
                color: palette.muted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddFirst,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar gasto'),
            ),
          ],
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
