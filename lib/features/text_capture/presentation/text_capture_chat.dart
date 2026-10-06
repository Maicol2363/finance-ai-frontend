import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_palette.dart';
import '../../receipt_capture/presentation/receipt_capture_flow.dart';
import '../application/text_capture_controller.dart';
import '../application/text_capture_state.dart';
import 'widgets/chat_bubbles.dart';
import 'widgets/capture_wheel.dart';
import 'widgets/chat_cards.dart';
import 'widgets/proposal_card.dart';

const maxMessageLength = 1000;

const _suggestions = <String>[
  'Almorcé en Subway 15.900 con efectivo',
  'Me pagaron el sueldo, 2 millones',
  'Pasé 50 mil de Nequi a efectivo',
];

/// The Gastos chat: the user writes what happened, the assistant proposes the
/// operation, and the user confirms, edits or discards it.
class TextCaptureChat extends ConsumerStatefulWidget {
  const TextCaptureChat({super.key});

  @override
  ConsumerState<TextCaptureChat> createState() => _TextCaptureChatState();
}

class _TextCaptureChatState extends ConsumerState<TextCaptureChat> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    ref.read(textCaptureControllerProvider.notifier).send(text);
    _focus.requestFocus();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TextCaptureChatState>(textCaptureControllerProvider, (
      previous,
      next,
    ) {
      // Any change of the conversation (a new message, or an error opening
      // inside a card) keeps the newest content in view.
      if (!identical(previous?.entries, next.entries) ||
          previous?.isBusy != next.isBusy) {
        _scrollToEnd();
      }
    });
    final state = ref.watch(textCaptureControllerProvider);
    final latestProposalId = state.entries
        .whereType<ProposalEntry>()
        .lastOrNull
        ?.id;
    final onlyWelcome = state.entries.length == 1;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView.separated(
                      key: const Key('chat-messages'),
                      controller: _scroll,
                      // Room at the bottom so the newest message is never hidden
                      // behind the floating button.
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: state.entries.length + (onlyWelcome ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == state.entries.length) {
                          return _Suggestions(
                            onPick: (text) {
                              _input
                                ..text = text
                                ..selection = TextSelection.collapsed(
                                  offset: text.length,
                                );
                              _focus.requestFocus();
                            },
                          );
                        }
                        return _EntryView(
                          key: ValueKey(state.entries[index].id),
                          entry: state.entries[index],
                          isLatestProposal:
                              state.entries[index].id == latestProposalId,
                        );
                      },
                    ),
                  ),
                ),
              ),
              CaptureWheel(
                onPhoto: () =>
                    startReceiptCapture(context, source: ImageSource.camera),
                onVoice: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Captura por nota de voz próximamente'),
                  ),
                ),
                onText: _focus.requestFocus,
                onManual: () => context.push('/expenses/new'),
              ),
            ],
          ),
        ),
        _Composer(
          controller: _input,
          focusNode: _focus,
          isBusy: state.isBusy,
          hint: _hintFor(state),
          onSend: _send,
        ),
      ],
    );
  }

  String _hintFor(TextCaptureChatState state) {
    final latest = state.entries.whereType<ProposalEntry>().lastOrNull;
    if (state.activeProposalId != null && latest != null) {
      final clarification = latest.proposal.clarification;
      if (latest.proposal.needsClarification &&
          clarification != null &&
          !clarification.isChoice) {
        return 'Escribe tu respuesta…';
      }
      return 'Corrige o completa el borrador…';
    }
    return 'Cuéntame qué pasó…';
  }
}

class _EntryView extends StatelessWidget {
  const _EntryView({
    super.key,
    required this.entry,
    required this.isLatestProposal,
  });

  final ChatEntry entry;
  final bool isLatestProposal;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      UserMessage(:final text) => UserBubble(text: text),
      AssistantMessage(:final text) => AssistantBubble(text: text),
      ThinkingEntry() => const ThinkingBubble(),
      ProposalEntry(:final proposal) when proposal.needsClarification =>
        ClarificationCard(
          entry: entry as ProposalEntry,
          isLatest: isLatestProposal,
        ),
      ProposalEntry() => ProposalCard(
        key: ValueKey(
          'proposal-${(entry as ProposalEntry).proposal.proposalId}-'
          '${(entry as ProposalEntry).proposal.revision}',
        ),
        entry: entry as ProposalEntry,
      ),
      ConfirmedEntry() => ConfirmedCard(entry: entry as ConfirmedEntry),
      FailureEntry() => FailureCard(entry: entry as FailureEntry),
    };
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prueba con un ejemplo:',
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < _suggestions.length; index++)
                Semantics(
                  button: true,
                  label: 'Usar ejemplo: ${_suggestions[index]}',
                  excludeSemantics: true,
                  child: Material(
                    color: palette.card,
                    shape: StadiumBorder(side: BorderSide(color: palette.line)),
                    child: InkWell(
                      key: Key('chat-suggestion-$index'),
                      customBorder: const StadiumBorder(),
                      onTap: () => onPick(_suggestions[index]),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            _suggestions[index],
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isBusy,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isBusy;
  final String hint;
  final VoidCallback onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(_Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    // Desktop: Enter sends, Shift+Enter writes a new line.
    if (event is KeyDownEvent &&
        isEnter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      if (_canSend) widget.onSend();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _canSend =>
      !widget.isBusy && widget.controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canSend = _canSend;
    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    key: const Key('chat-composer-field'),
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: maxMessageLength,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) {
                      if (_canSend) widget.onSend();
                    },
                    style: TextStyle(fontSize: 14.5, color: palette.text),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      counterText: '',
                      filled: true,
                      fillColor: palette.card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: palette.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: palette.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: palette.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: IconButton.filled(
                  key: const Key('chat-send-button'),
                  tooltip: 'Enviar mensaje',
                  style: IconButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    disabledBackgroundColor: palette.soft,
                    disabledForegroundColor: palette.placeholder,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: canSend ? widget.onSend : null,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
