import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/diagnostics/error_diagnostic_panel.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/movements_empty_state.dart';
import '../application/expenses_controller.dart';
import '../application/expenses_state.dart';
import '../domain/expense_models.dart';
import '../../receipt_capture/presentation/receipt_capture_flow.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  bool _isWheelOpen = false;
  AnimationController? _wheelAnimation;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final state = ref.read(expensesControllerProvider);
      if (state.listStatus == ExpensesLoadStatus.initial) {
        ref.read(expensesControllerProvider.notifier).load();
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

  // ignore: unused_element
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
    final state = ref.watch(expensesControllerProvider);
    final controller = ref.read(expensesControllerProvider.notifier);
    final result = state.result;
    final isBusy =
        state.listStatus == ExpensesLoadStatus.loading ||
        state.listStatus == ExpensesLoadStatus.loadingMore;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver al inicio',
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
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
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: RefreshIndicator(
                  onRefresh: controller.load,
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
                      if (state.listDiagnostic case final diagnostic?) ...[
                        ErrorDiagnosticPanel(diagnostic: diagnostic),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: controller.load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Banner resumen rápido (Estilo Mockup)
                      if (result != null) _HubSummaryCard(items: result.items),

                      if (result == null &&
                          state.listStatus != ExpensesLoadStatus.loading &&
                          state.listDiagnostic == null)
                        const _ExpensesLoadingPlaceholder(),
                      if (result != null && result.items.isEmpty)
                        MovementsEmptyState(
                          onRegister: () => context.go('/expenses/new'),
                        ),
                      if (result != null && result.items.isNotEmpty) ...[
                        Builder(
                          builder: (context) {
                            final seenReceiptIds = <int>{};
                            final groupedExpenses = <Expense>[];
                            for (final exp in result.items) {
                              if (exp.captureSource == CaptureSource.ai) {
                                if (seenReceiptIds.contains(exp.receiptId)) {
                                  continue;
                                }
                                seenReceiptIds.add(exp.receiptId);
                              }
                              groupedExpenses.add(exp);
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Historial reciente',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: palette.text,
                                        ),
                                      ),
                                      Text(
                                        '${groupedExpenses.length} ${groupedExpenses.length == 1 ? 'movimiento' : 'movimientos'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: palette.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                for (final expense in groupedExpenses) ...[
                                  _ExpenseCard(expense: expense),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                      if (result != null && result.hasNext) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('expenses-load-more-button'),
                          onPressed: isBusy ? null : controller.loadMore,
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
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),

          // Radial options when open
          if (_isWheelOpen) ...[
            _WheelBubble(
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
    );
  }
}

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

class _HubSummaryCard extends StatelessWidget {
  const _HubSummaryCard({required this.items});

  final List<Expense> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    var totalAmount = 0.0;
    for (final exp in items) {
      totalAmount += double.tryParse(exp.amount.toApiString()) ?? 0.0;
    }
    final currency = items.firstOrNull?.currencyCode ?? 'COP';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total de gastos',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '- \$ ${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} $currency',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${items.length} ${items.length == 1 ? 'registro' : 'registros'}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpensesLoadingPlaceholder extends StatelessWidget {
  const _ExpensesLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense});

  final Expense expense;

  String _sourceLabel(CaptureSource source, int itemCount) {
    switch (source) {
      case CaptureSource.ai:
        if (itemCount > 1) {
          return '✨ IA · $itemCount productos';
        }
        return '✨ IA';
      case CaptureSource.manual:
        return '✎ Manual';
      case CaptureSource.import:
        return '📥 Import';
    }
  }

  String _categoryEmoji(String? categoryName) {
    if (categoryName == null) return '🛒';
    final lower = categoryName.toLowerCase();
    if (lower.contains('comida') ||
        lower.contains('restaurante') ||
        lower.contains('almuerzo')) {
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
    return '💳';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final displayAmount = expense.receiptTotal ?? expense.amount;
    final amount = displayAmount.formatWithCurrency(expense.currencyCode);
    final meaning = displayAmount.isNegative
        ? 'Monto negativo $amount'
        : 'Monto $amount';
    final statusLabel = expense.isEditable ? 'editable' : 'no editable';

    return Semantics(
      container: true,
      button: true,
      label: '${expense.name}, $meaning, ${expense.store}, $statusLabel',
      child: ExcludeSemantics(
        child: Container(
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        _categoryEmoji(expense.category?.name),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.store.isNotEmpty
                              ? expense.store
                              : expense.name,
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
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: palette.soft,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _sourceLabel(expense.captureSource, expense.items.length),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: displayAmount.isNegative
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
        ),
      ),
    );
  }
}
