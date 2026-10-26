import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../../../core/time/clock_provider.dart';
import '../../accounts/application/accounts_controller.dart';
import '../../auth/session/application/auth_session_controller.dart';
import '../../auth/session/domain/session_models.dart';
import '../../budgets/application/budgets_controller.dart';
import '../../expenses/application/expenses_controller.dart';
import '../../expenses/application/history_controller.dart';
import '../../incomes/data/incomes_repository.dart';
import '../data/text_capture_repository.dart';
import '../domain/text_capture_models.dart';
import 'text_capture_state.dart';

final textCaptureControllerProvider =
    NotifierProvider<TextCaptureController, TextCaptureChatState>(
      TextCaptureController.new,
    );

const welcomeMessage =
    'Cuéntame qué pasó con tu dinero y lo preparo para que lo revises. '
    'Por ejemplo: «Almorcé en Subway 15.900 con efectivo» o '
    '«Pasé 200 mil de Nequi a Bancolombia».';

class _Turn {
  const _Turn({this.text, this.proposalId, this.choice});

  final String? text;
  final String? proposalId;
  final ({String field, String value})? choice;
}

/// State of the Gastos chat.
///
/// A message becomes a proposal; nothing is saved until the user accepts it.
/// Typed corrections and tapped answers reuse the same proposal, so the server
/// keeps the original text. Accept goes through the same validated operation
/// as the manual forms.
class TextCaptureController extends Notifier<TextCaptureChatState> {
  int _nextId = 0;
  _Turn? _lastTurn;

  @override
  TextCaptureChatState build() {
    // A different user (or logging out) must never inherit this conversation.
    ref.watch(authSessionControllerProvider.select((s) => s.user?.id));
    _nextId = 0;
    _lastTurn = null;
    return TextCaptureChatState(
      entries: [AssistantMessage(_id(), welcomeMessage)],
    );
  }

  int _id() => _nextId++;

  TextCaptureRepository get _repository =>
      ref.read(textCaptureRepositoryProvider);

  /// Sends what the user typed: a new operation, or a correction of the open
  /// proposal.
  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isBusy) {
      return;
    }
    state = state.copyWith(
      entries: [...state.entries, UserMessage(_id(), text)],
    );
    await _run(_Turn(text: text, proposalId: state.activeProposalId));
  }

  /// Answers the clarification with one of its tapped options.
  Future<void> choose(ProposalEntry entry, ClarificationOption option) async {
    final clarification = entry.proposal.clarification;
    if (clarification == null || state.isBusy) {
      return;
    }
    state = state.copyWith(
      entries: [...state.entries, UserMessage(_id(), option.label)],
    );
    await _run(
      _Turn(
        proposalId: entry.proposal.proposalId,
        choice: (field: clarification.field, value: option.value),
      ),
    );
  }

  /// Sends the last failed turn again.
  Future<void> retry() async {
    final turn = _lastTurn;
    if (turn == null || state.isBusy) {
      return;
    }
    await _run(turn);
  }

  Future<void> _run(_Turn turn) async {
    _lastTurn = turn;
    state = state.copyWith(
      isBusy: true,
      entries: [
        ...state.entries.where((entry) => entry is! FailureEntry),
        ThinkingEntry(_id()),
      ],
    );
    try {
      final proposal = await _repository.propose(
        clientNow: ref.read(clockProvider)(),
        text: turn.text,
        proposalId: turn.proposalId,
        choice: turn.choice,
      );
      _lastTurn = null;
      _showProposal(proposal);
    } on TextCaptureFailure catch (failure) {
      _showFailure(
        failure.code,
        failure.userMessage,
        failure.correlationId,
        failure.technicalReason,
        operation: 'text_capture_propose',
        canRetry: failure.isRetryable,
      );
    } on AuthSessionFailure catch (failure) {
      _showFailure(
        failure.code,
        failure.userMessage,
        failure.correlationId,
        failure.technicalReason,
        operation: 'text_capture_propose',
        canRetry: false,
      );
    } catch (_) {
      _showFailure(
        'unexpected_client_error',
        'No pude procesar tu mensaje. Inténtalo de nuevo.',
        'unavailable',
        'unclassified_failure',
        operation: 'text_capture_propose',
        canRetry: true,
      );
    }
  }

  void _showProposal(TextProposal proposal) {
    final kept = state.entries.where(
      (entry) =>
          entry is! ThinkingEntry &&
          !(entry is ProposalEntry &&
              entry.proposal.proposalId == proposal.proposalId),
    );
    if (proposal.status == ProposalStatus.unrecognized) {
      state = state.copyWith(
        isBusy: false,
        clearActiveProposal: true,
        entries: [
          ...kept,
          AssistantMessage(
            _id(),
            proposal.message ??
                'No encontré un gasto, ingreso o transferencia en tu mensaje.',
          ),
        ],
      );
      return;
    }
    state = state.copyWith(
      isBusy: false,
      activeProposalId: proposal.proposalId,
      entries: [...kept, ProposalEntry(_id(), proposal)],
    );
  }

  void _showFailure(
    String code,
    String message,
    String correlationId,
    String technicalReason, {
    required String operation,
    required bool canRetry,
  }) {
    state = state.copyWith(
      isBusy: false,
      entries: [
        ...state.entries.where((entry) => entry is! ThinkingEntry),
        FailureEntry(
          _id(),
          ErrorDiagnostic.capture(
            code: code,
            operation: operation,
            userMessage: message,
            correlationId: correlationId,
            technicalReason: technicalReason,
          ),
          canRetry: canRetry,
        ),
      ],
    );
  }

  /// Records the proposal with the values the user is looking at (possibly
  /// edited in place).
  Future<void> confirm(
    ProposalEntry entry,
    TextProposalConfirmCommand command,
  ) async {
    if (entry.isConfirming) {
      return;
    }
    _replace(entry.id, (current) {
      return current is ProposalEntry
          ? current.copyWith(isConfirming: true, clearFailure: true)
          : current;
    });
    try {
      final confirmation = await _repository.confirm(
        entry.proposal.proposalId,
        command,
      );
      state = state.copyWith(
        clearActiveProposal: true,
        entries: [
          for (final item in state.entries)
            if (item.id == entry.id)
              ConfirmedEntry(entry.id, confirmation)
            else
              item,
        ],
      );
      _refreshMovements(
        refreshBudget: confirmation.intent == CaptureIntent.expense,
      );
    } on TextCaptureFailure catch (failure) {
      _failConfirm(
        entry.id,
        failure.code,
        failure.userMessage,
        failure.correlationId,
        failure.technicalReason,
      );
    } on AuthSessionFailure catch (failure) {
      _failConfirm(
        entry.id,
        failure.code,
        failure.userMessage,
        failure.correlationId,
        failure.technicalReason,
      );
    } catch (_) {
      _failConfirm(
        entry.id,
        'unexpected_client_error',
        'No se pudo guardar. Inténtalo de nuevo.',
        'unavailable',
        'unclassified_failure',
      );
    }
  }

  void _failConfirm(
    int entryId,
    String code,
    String message,
    String correlationId,
    String technicalReason,
  ) {
    final diagnostic = ErrorDiagnostic.capture(
      code: code,
      operation: 'text_capture_confirm',
      userMessage: message,
      correlationId: correlationId,
      technicalReason: technicalReason,
    );
    _replace(entryId, (current) {
      return current is ProposalEntry
          ? current.copyWith(isConfirming: false, failure: diagnostic)
          : current;
    });
  }

  /// Drops the proposal and tells the server to forget the draft.
  Future<void> discard(ProposalEntry entry) async {
    if (entry.isConfirming) {
      return;
    }
    state = state.copyWith(
      clearActiveProposal: true,
      entries: [
        for (final item in state.entries)
          if (item.id == entry.id)
            AssistantMessage(
              entry.id,
              'Listo, descarté ese borrador. No se guardó nada.',
            )
          else
            item,
      ],
    );
    try {
      await _repository.discard(entry.proposal.proposalId);
    } catch (_) {
      // The draft expires by itself; the user already moved on.
    }
  }

  /// Dismisses a failed turn without retrying it.
  void dismissFailure() {
    _lastTurn = null;
    state = state.copyWith(
      entries: state.entries
          .where((entry) => entry is! FailureEntry)
          .toList(growable: false),
    );
  }

  void _replace(int id, ChatEntry Function(ChatEntry entry) change) {
    state = state.copyWith(
      entries: [
        for (final item in state.entries)
          if (item.id == id) change(item) else item,
      ],
    );
  }

  /// Every list that shows balances or movements reads the new record.
  void _refreshMovements({bool refreshBudget = false}) {
    try {
      ref.read(expensesControllerProvider.notifier).load();
      ref.read(historyControllerProvider.notifier).load();
      if (refreshBudget) {
        ref.read(budgetsControllerProvider.notifier).load();
      }
      ref.read(accountsControllerProvider.notifier).load();
      ref.read(incomeRevisionProvider.notifier).changed();
    } catch (_) {
      // They reload on their own the next time they are opened.
    }
  }
}
