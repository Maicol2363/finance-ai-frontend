import 'package:finance_ai/core/icons/finance_icon_catalog.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

const _bubbleRadius = Radius.circular(16);
const _tailRadius = Radius.circular(4);

double _maxBubbleWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width * 0.82).clamp(220.0, 560.0);
}

/// What the user wrote (mockup `.msg.user`: soft green, tail at the bottom right).
class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxBubbleWidth(context)),
        child: Semantics(
          label: 'Tú: $text',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: const BorderRadius.only(
                topLeft: _bubbleRadius,
                topRight: _bubbleRadius,
                bottomLeft: _bubbleRadius,
                bottomRight: _tailRadius,
              ),
            ),
            child: SelectableText(
              text,
              style: TextStyle(fontSize: 14, height: 1.45, color: palette.text),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small round mark that tells who is speaking on the assistant side.
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: palette.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Icon(FinanceIcons.autoAwesome, size: 15, color: palette.primary),
      ),
    );
  }
}

/// A row on the assistant side: avatar + whatever [child] shows.
class AssistantRow extends StatelessWidget {
  const AssistantRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: AssistantAvatar(),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _maxBubbleWidth(context)),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// A plain assistant message (white card with a tail at the bottom left).
class AssistantBubble extends StatelessWidget {
  const AssistantBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AssistantRow(
      child: Semantics(
        label: 'Asistente: $text',
        liveRegion: true,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border.all(color: palette.line),
            borderRadius: const BorderRadius.only(
              topLeft: _bubbleRadius,
              topRight: _bubbleRadius,
              bottomRight: _bubbleRadius,
              bottomLeft: _tailRadius,
            ),
          ),
          child: SelectableText(
            text,
            style: TextStyle(fontSize: 14, height: 1.45, color: palette.text),
          ),
        ),
      ),
    );
  }
}

/// The assistant is reading the message. After a few seconds it says so, so a
/// slow AI answer never looks like a frozen app.
class ThinkingBubble extends StatefulWidget {
  const ThinkingBubble({
    super.key,
    this.slowAfter = const Duration(seconds: 7),
  });

  final Duration slowAfter;

  @override
  State<ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(widget.slowAfter, () {
      if (mounted) {
        setState(() => _slow = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "remove animations": keep the dots still.
    if (MediaQuery.disableAnimationsOf(context)) {
      _dots.stop();
    } else if (!_dots.isAnimating) {
      _dots.repeat();
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = _slow
        ? 'Sigo leyendo tu mensaje… a veces tarda unos segundos.'
        : 'Leyendo tu mensaje…';
    return AssistantRow(
      child: Semantics(
        key: const Key('chat-thinking'),
        liveRegion: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border.all(color: palette.line),
            borderRadius: const BorderRadius.only(
              topLeft: _bubbleRadius,
              topRight: _bubbleRadius,
              bottomRight: _bubbleRadius,
              bottomLeft: _tailRadius,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _dots,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < 3; index++)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Opacity(
                          opacity: _opacityFor(index),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _opacityFor(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return 0.8;
    }
    final phase = (_dots.value + index * 0.2) % 1.0;
    return 0.35 + 0.65 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
  }
}
