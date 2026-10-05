import 'package:flutter/material.dart';

/// Expensify-style free-framing hint painted over the live camera preview.
///
/// No fixed rectangle, no dimmed background: receipts vary too much
/// (tirilla larga del Exito vs factura corta del D1) for a single box.
/// Shows only subtle corner marks near the screen edges plus a hint pill
/// so the user fills the screen with the receipt. Purely visual.
class ReceiptPhotoFrameOverlay extends StatelessWidget {
  const ReceiptPhotoFrameOverlay({
    super.key,
    this.hint = 'Llena la pantalla con el recibo',
  });

  /// Hint rendered in a pill above the shutter area.
  final String hint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 640.0;
        if (maxW <= 10 || maxH <= 10) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: _HintPill(hint: hint),
              ),
            ],
          );
        }

        // Safe area: 20px margins, room for top bar (~90) and shutter (~140).
        const margin = 20.0;
        final guideRect = Rect.fromLTWH(
          margin,
          96,
          maxW - margin * 2,
          maxH - 96 - 150,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _CornersPainter(guideRect),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 128,
              child: Center(
                child: _HintPill(hint: hint),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Translucent dark pill with the hint text.
class _HintPill extends StatelessWidget {
  const _HintPill({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter(this.area);

  final Rect area;

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle L-shaped corner marks only — no border, no dim.
    const cornerLen = 34.0;
    const cornerWidth = 3.5;
    final cornerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerWidth
      ..strokeCap = StrokeCap.round;

    final corners = <Offset, List<Offset>>{
      area.topLeft: [
        area.topLeft + const Offset(cornerLen, 0),
        area.topLeft + const Offset(0, cornerLen),
      ],
      area.topRight: [
        area.topRight + const Offset(-cornerLen, 0),
        area.topRight + const Offset(0, cornerLen),
      ],
      area.bottomLeft: [
        area.bottomLeft + const Offset(cornerLen, 0),
        area.bottomLeft + const Offset(0, -cornerLen),
      ],
      area.bottomRight: [
        area.bottomRight + const Offset(-cornerLen, 0),
        area.bottomRight + const Offset(0, -cornerLen),
      ],
    };

    for (final entry in corners.entries) {
      for (final end in entry.value) {
        canvas.drawLine(entry.key, end, cornerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CornersPainter oldDelegate) =>
      oldDelegate.area != area;
}

