import '../domain/expense_models.dart';
import '../domain/history_models.dart';

/// Emoji shown on a movement tile, derived from the category name.
///
/// Single source of truth for the feed cards of the hub, the expenses list and
/// the history screen.
String categoryEmoji(String? categoryName) {
  final lower = (categoryName ?? '').toLowerCase();
  if (lower.contains('comida') ||
      lower.contains('restaurante') ||
      lower.contains('almuerzo') ||
      lower.contains('cafe') ||
      lower.contains('café')) {
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
      lower.contains('nomina') ||
      lower.contains('nómina')) {
    return '💰';
  }
  if (lower.contains('salud') || lower.contains('farmacia')) {
    return '💊';
  }
  if (lower.contains('hogar') || lower.contains('arriendo')) {
    return '🏠';
  }
  return '💳';
}

/// Emoji used by a transaction kind when no category is available.
String transactionTypeEmoji(TransactionType type) => switch (type) {
  TransactionType.expense => '🛒',
  TransactionType.income => '💰',
  TransactionType.transfer => '🔄',
};

/// Capture-source tag shown on the movement cards (`✨ IA · 3 productos`).
String captureSourceLabel(CaptureSource source, int itemCount) {
  switch (source) {
    case CaptureSource.ai:
      if (itemCount > 1) {
        return '✨ IA · $itemCount productos';
      }
      return '✨ IA';
    case CaptureSource.manual:
      return '✎ manual';
    case CaptureSource.import:
      return '📥 import';
  }
}

/// Chip label for a capture-source filter (history search).
String captureSourceFilterLabel(CaptureSource source) => switch (source) {
  CaptureSource.ai => '✨ IA',
  CaptureSource.manual => '✎ Manual',
  CaptureSource.import => '📥 Importado',
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
