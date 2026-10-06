import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/error_diagnostic.dart';
import '../domain/text_capture_models.dart';

/// One item of the capture chat.
@immutable
sealed class ChatEntry {
  const ChatEntry(this.id);

  final int id;
}

class UserMessage extends ChatEntry {
  const UserMessage(super.id, this.text);

  final String text;
}

class AssistantMessage extends ChatEntry {
  const AssistantMessage(super.id, this.text);

  final String text;
}

/// The assistant is reading the last message.
class ThinkingEntry extends ChatEntry {
  const ThinkingEntry(super.id);
}

/// A proposal waiting for the user: a review card, or the one question.
class ProposalEntry extends ChatEntry {
  const ProposalEntry(
    super.id,
    this.proposal, {
    this.isConfirming = false,
    this.failure,
  });

  final TextProposal proposal;
  final bool isConfirming;

  /// Why Accept failed; the card stays open so the user can retry or edit.
  final ErrorDiagnostic? failure;

  ProposalEntry copyWith({
    bool? isConfirming,
    ErrorDiagnostic? failure,
    bool clearFailure = false,
  }) {
    return ProposalEntry(
      id,
      proposal,
      isConfirming: isConfirming ?? this.isConfirming,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

/// The operation was recorded.
class ConfirmedEntry extends ChatEntry {
  const ConfirmedEntry(super.id, this.confirmation);

  final TextCaptureConfirmation confirmation;
}

/// A chat turn could not be completed.
class FailureEntry extends ChatEntry {
  const FailureEntry(super.id, this.diagnostic, {this.canRetry = true});

  final ErrorDiagnostic diagnostic;
  final bool canRetry;
}

@immutable
class TextCaptureChatState {
  const TextCaptureChatState({
    this.entries = const [],
    this.isBusy = false,
    this.activeProposalId,
  });

  final List<ChatEntry> entries;

  /// A message is being read or a proposal is being recorded.
  final bool isBusy;

  /// The open proposal the next typed message corrects or completes.
  final String? activeProposalId;

  TextCaptureChatState copyWith({
    List<ChatEntry>? entries,
    bool? isBusy,
    String? activeProposalId,
    bool clearActiveProposal = false,
  }) {
    return TextCaptureChatState(
      entries: entries ?? this.entries,
      isBusy: isBusy ?? this.isBusy,
      activeProposalId: clearActiveProposal
          ? null
          : activeProposalId ?? this.activeProposalId,
    );
  }
}
