import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_palette.dart';

/// The floating `+` of the Gastos chat: it fans out the ways to add a movement
/// (AI-assisted entry, photo and the manual form).
///
/// It is a [Stack] child: it fills the chat area, dims it while open and keeps
/// the button in the bottom right corner, above the message box.
class CaptureWheel extends StatefulWidget {
  const CaptureWheel({
    super.key,
    required this.onPhoto,
    required this.onAi,
    required this.onManual,
    this.onOpenChanged,
  });

  final VoidCallback onPhoto;
  final VoidCallback onAi;
  final VoidCallback onManual;
  final ValueChanged<bool>? onOpenChanged;

  @override
  CaptureWheelState createState() => CaptureWheelState();
}

class CaptureWheelState extends State<CaptureWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  bool _isOpen = false;
  late final FocusNode _fabNode = FocusNode(debugLabel: 'capture-wheel-fab');
  late final FocusNode _firstBubbleNode = FocusNode(
    debugLabel: 'capture-wheel-first',
  );

  bool get isOpen => _isOpen;

  @override
  void dispose() {
    _fabNode.dispose();
    _firstBubbleNode.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _toggle() {
    final wasOpen = _isOpen;
    setState(() => _isOpen = !_isOpen);
    widget.onOpenChanged?.call(_isOpen);
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = _isOpen ? 1 : 0;
    } else if (_isOpen) {
      _animation.forward();
    } else {
      _animation.reverse();
    }
    // Move focus on open/close without touching animation behavior.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isOpen && !wasOpen) {
        FocusScope.of(context).requestFocus(_firstBubbleNode);
      } else if (!_isOpen && wasOpen) {
        FocusScope.of(context).requestFocus(_fabNode);
      }
    });
  }

  void _close() {
    if (_isOpen) _toggle();
  }

  void close() => _close();

  void _choose(VoidCallback action) {
    // Close without stealing focus back to the FAB: the chosen action owns
    // focus (e.g. the message option moves it to the chat editor).
    if (_isOpen) {
      setState(() => _isOpen = false);
      widget.onOpenChanged?.call(false);
      if (MediaQuery.disableAnimationsOf(context)) {
        _animation.value = 0;
      } else {
        _animation.reverse();
      }
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Stack(
        children: [
          if (_isOpen)
            Positioned.fill(
              child: Semantics(
                button: true,
                label: 'Cerrar opciones',
                onTap: _close,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: const Key('expenses-wheel-scrim'),
                    onTap: _close,
                    focusColor: palette.primarySoft.withValues(alpha: 0.6),
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          if (_isOpen) ...[
            _WheelBubble(
              key: const Key('expenses-wheel-photo'),
              right: 19,
              bottom: 125,
              icon: FinanceIcons.cameraAltOutlined,
              label: 'Foto',
              description: 'Foto de un recibo',
              animation: _animation,
              delayRatio: 0.0,
              autofocus: true,
              focusNode: _firstBubbleNode,
              onTap: () => _choose(widget.onPhoto),
            ),
            _WheelBubble(
              key: const Key('expenses-wheel-ai'),
              right: 94,
              bottom: 94,
              icon: FinanceIcons.chatBubbleOutline,
              label: 'Mensaje',
              description: 'Escribir o dictar',
              animation: _animation,
              delayRatio: 0.1,
              onTap: () => _choose(widget.onAi),
            ),
            _WheelBubble(
              key: const Key('expenses-wheel-manual'),
              right: 125,
              bottom: 19,
              icon: FinanceIcons.editOutlined,
              label: 'Manual',
              description: 'Formulario manual',
              animation: _animation,
              delayRatio: 0.3,
              onTap: () => _choose(widget.onManual),
            ),
          ],
          Positioned(
            right: 16,
            bottom: 16,
            child: SizedBox(
              width: 58,
              height: 58,
              child: FloatingActionButton(
                key: const Key('expenses-create-fab'),
                focusNode: _fabNode,
                tooltip: _isOpen ? 'Cerrar opciones' : 'Añadir un movimiento',
                elevation: 4,
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                shape: const CircleBorder(),
                onPressed: _toggle,
                child: AnimatedRotation(
                  turns: _isOpen ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(FinanceIcons.add, size: 30),
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
    required this.description,
    required this.animation,
    required this.delayRatio,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  final double right;
  final double bottom;
  final IconData icon;
  final String label;
  final String description;
  final Animation<double> animation;
  final double delayRatio;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(delayRatio, 1.0, curve: Curves.easeOutBack),
    );
    return Positioned(
      right: right,
      bottom: bottom,
      child: ScaleTransition(
        scale: curved,
        child: FadeTransition(
          opacity: _ClampedAnimation(curved),
          child: Semantics(
            button: true,
            label: description,
            onTap: onTap,
            excludeSemantics: true,
            child: Material(
              shape: CircleBorder(side: BorderSide(color: palette.line)),
              color: palette.card,
              elevation: 4,
              shadowColor: const Color(0x1A0F172A),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                focusColor: palette.primarySoft.withValues(alpha: 0.8),
                autofocus: autofocus,
                focusNode: focusNode,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  key: ValueKey('$label-surface'),
                  // Keep the Material icon and label inside the 52 px circle.
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 18, color: palette.text),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1.1,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0).toDouble();
}
