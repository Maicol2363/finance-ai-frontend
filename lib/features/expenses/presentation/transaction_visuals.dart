import 'package:flutter/material.dart';

import '../../../core/icons/finance_icon_catalog.dart';
import '../domain/expense_models.dart';
import '../domain/history_models.dart';

/// Icon shown on a movement tile, derived from the category name.
///
/// Single source of truth for the feed cards of the hub, the expenses list and
/// the history screen.
FinanceIconKey categoryIconKey(String? categoryName) {
  final lower = (categoryName ?? '').toLowerCase();
  if (lower.contains('comida') ||
      lower.contains('restaurante') ||
      lower.contains('almuerzo') ||
      lower.contains('cafe') ||
      lower.contains('café')) {
    return FinanceIconKey.food;
  }
  if (lower.contains('transporte') ||
      lower.contains('bus') ||
      lower.contains('taxi') ||
      lower.contains('metro')) {
    return FinanceIconKey.transport;
  }
  if (lower.contains('suscrip') ||
      lower.contains('stream') ||
      lower.contains('netflix')) {
    return FinanceIconKey.entertainment;
  }
  if (lower.contains('mercado') || lower.contains('super')) {
    return FinanceIconKey.shopping;
  }
  if (lower.contains('salario') ||
      lower.contains('ingreso') ||
      lower.contains('nomina') ||
      lower.contains('nómina')) {
    return FinanceIconKey.income;
  }
  if (lower.contains('salud') || lower.contains('farmacia')) {
    return FinanceIconKey.health;
  }
  if (lower.contains('hogar') || lower.contains('arriendo')) {
    return FinanceIconKey.home;
  }
  return FinanceIconKey.category;
}

IconData categoryIcon(String? categoryName) =>
    FinanceIconCatalog.dataFor(categoryIconKey(categoryName));

/// Icon used by a transaction kind when no category is available.
IconData transactionTypeIcon(TransactionType type) =>
    FinanceIconCatalog.dataFor(switch (type) {
      TransactionType.expense => FinanceIconKey.expense,
      TransactionType.income => FinanceIconKey.income,
      TransactionType.transfer => FinanceIconKey.transfer,
    });

IconData captureSourceIcon(CaptureSource source) =>
    FinanceIconCatalog.dataFor(switch (source) {
      CaptureSource.ai => FinanceIconKey.aiCapture,
      CaptureSource.manual => FinanceIconKey.manualCapture,
      CaptureSource.import => FinanceIconKey.import,
    });

/// Capture-source label shown on the movement cards.
String captureSourceLabel(CaptureSource source, int itemCount) {
  switch (source) {
    case CaptureSource.ai:
      return itemCount > 1 ? 'IA · $itemCount productos' : 'IA';
    case CaptureSource.manual:
      return 'Manual';
    case CaptureSource.import:
      return 'Importado';
  }
}

/// Chip label for a capture-source filter (history search).
String captureSourceFilterLabel(CaptureSource source) => switch (source) {
  CaptureSource.ai => 'IA',
  CaptureSource.manual => 'Manual',
  CaptureSource.import => 'Importado',
};

/// Spanish label for a history transaction kind.
String transactionTypeLabel(TransactionType type) => switch (type) {
  TransactionType.expense => 'Gasto',
  TransactionType.income => 'Ingreso',
  TransactionType.transfer => 'Transferencia',
};

/// Spanish label for the history period presets offered by the UI.
String historyPeriodLabel(HistoryPeriod period) => switch (period) {
  HistoryPeriod.week => 'Semana',
  HistoryPeriod.weekly => 'Semanal',
  HistoryPeriod.month => 'Mes',
  HistoryPeriod.monthly => 'Mensual',
  HistoryPeriod.custom => 'Personalizado',
};
