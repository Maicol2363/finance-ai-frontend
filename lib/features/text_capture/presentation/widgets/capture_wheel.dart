import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// The floating `+` of the Gastos chat: it fans out the ways to add a movement
/// (photo, text and the manual form). Voice uses the composer microphone.
///
/// It is a [Stack] child: it fills the chat area, dims it while open and keeps
/// the button in the bottom right corner, above the message box.
class CaptureWheel extends StatefulWidget {
  const CaptureWheel({
    super.key,
    required this.onPhoto,
    required this.onText,
    required this.onManual,
  });

  final VoidCallback onPhoto;
  final VoidCallback onText;
  final VoidCallback onManual;

  @override
  State<CaptureWheel> createState() => _CaptureWheelState();
}

class _CaptureWheelState extends State<CaptureWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  bool _isOpen = false;

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = _isOpen ? 1 : 0;
    } else if (_isOpen) {
      _animation.forward();
    } else {
      _animation.reverse();
    }
  }

  void _close() {
    if (_isOpen) _toggle();
  }

  void _choose(VoidCallback action) {
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        if (_isOpen)
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Cerrar opciones',
              child: GestureDetector(
                key: const Key('expenses-wheel-scrim'),
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
          ),
        if (_isOpen) ...[
          _WheelBubble(
            key: const Key('expenses-wheel-photo'),
            right: 16,
            bottom: 156,
            icon: Icons.camera_alt_outlined,
            label: 'Foto',
            description: 'Foto de un recibo',
            animation: _animation,
            delayRatio: 0.0,
            onTap: () => _choose(widget.onPhoto),
          ),
          _WheelBubble(
            key: const Key('expenses-wheel-text'),
            right: 76,
            bottom: 136,
            icon: Icons.text_fields,
            label: 'Texto',
            description: 'Escribir en el chat',
            animation: _animation,
            delayRatio: 0.1,
            onTap: () => _choose(widget.onText),
          ),
          _WheelBubble(
            key: const Key('expenses-wheel-manual'),
            right: 136,
            bottom: 91,
            icon: Icons.edit_outlined,
            label: 'Manual',
            description: 'Formulario manual',
            animation: _animation,
            delayRatio: 0.2,
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
              tooltip: _isOpen ? 'Cerrar opciones' : 'Añadir un movimiento',
              elevation: 4,
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              onPressed: _toggle,
              child: AnimatedRotation(
                turns: _isOpen ? 0.125 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.add, size: 30),
              ),
            ),
          ),
        ),
      ],
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
  });

  final double right;
  final double bottom;
  final IconData icon;
  final String label;
  final String description;
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
              child: Semantics(
                button: true,
                label: description,
                excludeSemantics: true,
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
        );
      },
    );
  }
}
