import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Mockup `.auth-brand` / `.auth-orbit`: compact orbit mark + product name.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, this.mark = r'$', this.showTitle = true});

  final String mark;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        SizedBox(
          width: 142,
          height: 112,
          child: CustomPaint(
            painter: _OrbitPainter(color: palette.primary),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  mark,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showTitle) ...[
          Text(
            'Finance AI',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: palette.text,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Tu dinero, más claro.',
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = size.center(Offset.zero);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-25 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width + 20,
        height: size.height - 36,
      ),
      paint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(35 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width - 40,
        height: size.height - 4,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.color != color;
}
