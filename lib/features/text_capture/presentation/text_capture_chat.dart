import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_palette.dart';
import '../../receipt_capture/presentation/receipt_capture_flow.dart';
import '../../voice_capture/application/voice_capture_controller.dart';
import '../../voice_capture/data/native_speech_service.dart';
import '../../voice_capture/presentation/voice_controls.dart';
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

class _TextCaptureChatState extends ConsumerState<TextCaptureChat>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _voiceTarget = GlobalKey();
  late final VoiceCaptureController _voice;
  bool _voiceExpanded = false, _gestureActive = false;
  bool _nearVoiceTarget = false, _occupiedVoiceTarget = false;
  double _gestureKeyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = VoiceCaptureController(
      service: ref.read(speechServiceProvider),
      onTranscript: (text) {
        if (!mounted) return;
        _input.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
      canSubmit: () =>
          mounted && !ref.read(textCaptureControllerProvider).isBusy,
      onAccepted: (_) => _send(requestFocus: false),
    )..addListener(_voiceChanged);
    Future<void>.microtask(() {
      if (mounted) _voice.prepare();
    });
  }

  void _voiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == false) {
      Future<void>.microtask(() {
        if (mounted) _voice.interrupt();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _voice.interrupt();
    } else if (_voiceExpanded) {
      _voice.refreshAfterResume();
    }
  }

  @override
  void didChangeMetrics() {
    if (mounted && _gestureActive) setState(() {});
  }

  void _beginVoice() {
    _focus.unfocus();
    setState(() => _voiceExpanded = true);
    _voice.begin(_input.text);
  }

  void _closeVoice() {
    _voice.closeSetup();
    setState(() => _voiceExpanded = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_voiceChanged);
    _voice.dispose();
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send({bool requestFocus = true}) {
    if (ref.read(textCaptureControllerProvider).isBusy) return;
    if (_voice.capturing) {
      _voice.finishForSend();
      return;
    }
    if (_voice.active) return;
    final text = _input.text.trim();
    if (text.isEmpty || text.length > maxMessageLength) return;
    _voice.clearAfterSend();
    _input.clear();
    ref.read(textCaptureControllerProvider.notifier).send(text);
    if (requestFocus) _focus.requestFocus();
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
      if (next.isBusy && _voice.active) _voice.interrupt();
    });
    final state = ref.watch(textCaptureControllerProvider);
    final latestProposalId = state.entries
        .whereType<ProposalEntry>()
        .lastOrNull
        ?.id;
    final onlyWelcome = state.entries.length == 1;
    final view = View.of(context);
    final keyboardInset = view.viewInsets.bottom / view.devicePixelRatio;
    // Scaffolds consume MediaQuery.viewInsets. Actual view metrics keep the
    // composer under the finger while the keyboard closes during a hold.
    final compensation = _gestureActive
        ? (_gestureKeyboardInset - keyboardInset).clamp(
            0.0,
            _gestureKeyboardInset,
          )
        : 0.0;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: compensation),
      duration: _gestureActive || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
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
                          itemCount:
                              state.entries.length + (onlyWelcome ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == state.entries.length) {
                              return _Suggestions(
                                onPick: (text) {
                                  _voice.clearAfterSend();
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
                    onPhoto: () {
                      _voice.interrupt();
                      startReceiptCapture(context, source: ImageSource.camera);
                    },
                    onText: () {
                      _voice.interrupt();
                      _focus.requestFocus();
                    },
                    onManual: () {
                      _voice.interrupt();
                      context.push('/expenses/new');
                    },
                  ),
                ],
              ),
            ),
            if (_voiceExpanded)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.45,
                ),
                child: SingleChildScrollView(
                  child: VoiceControls(
                    controller: _voice,
                    targetKey: _voiceTarget,
                    nearTarget: _nearVoiceTarget,
                    occupied: _occupiedVoiceTarget,
                    keepTarget: _gestureActive,
                    onClose: _closeVoice,
                  ),
                ),
              ),
            _Composer(
              controller: _input,
              focusNode: _focus,
              isBusy: state.isBusy || _voice.phase == VoicePhase.finalizing,
              hint: _hintFor(state),
              onSend: _send,
              isDictating: _voice.active,
              voiceButton: VoiceMicButton(
                controller: _voice,
                targetKey: _voiceTarget,
                isBusy: state.isBusy,
                onBegin: _beginVoice,
                onGesture: (active, near, occupied) => setState(() {
                  if (active && !_gestureActive) {
                    final view = View.of(context);
                    _gestureKeyboardInset =
                        view.viewInsets.bottom / view.devicePixelRatio;
                  }
                  _gestureActive = active;
                  _nearVoiceTarget = near;
                  _occupiedVoiceTarget = occupied;
                }),
              ),
            ),
          ],
        ),
      ),
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
    required this.isDictating,
    required this.voiceButton,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isBusy;
  final String hint;
  final VoidCallback onSend;
  final bool isDictating;
  final Widget voiceButton;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _dictationScroll = ScrollController();
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
    _dictationScroll.dispose();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    setState(() {});
    if (widget.isDictating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dictationScroll.hasClients) {
          _dictationScroll.jumpTo(_dictationScroll.position.maxScrollExtent);
        }
      });
    }
  }

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
      !widget.isBusy &&
      widget.controller.text.trim().isNotEmpty &&
      widget.controller.text.trim().length <= maxMessageLength;

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
                    scrollController: _dictationScroll,
                    focusNode: widget.focusNode,
                    readOnly: widget.isDictating,
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
                child: widget.voiceButton,
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
