import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Empty state for the recent movements feed.
///
/// Shared by the Gastos hub and the expenses list so both screens render the
/// same card: outlined icon, short title, one-line explanation and a direct
/// primary action. Copy stays factual and free of capture hints, matching the
/// empty states used by the catalog screens.
class MovementsEmptyState extends StatelessWidget {
  const MovementsEmptyState({super.key, required this.onRegister});

  /// Opens the manual capture form (`/expenses/new`).
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const Key('movements-empty-state'),
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                FinanceIcons.receiptLongOutlined,
                size: 30,
                color: palette.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes movimientos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra tu primer gasto o ingreso y aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('movements-empty-register-button'),
              onPressed: onRegister,
              icon: const Icon(FinanceIcons.add, size: 18),
              label: const Text('Registrar movimiento'),
            ),
          ],
        ),
      ),
    );
  }
}
