import 'package:flutter/material.dart';

/// Framing overlay painted over the live camera preview.
///
/// Darkens everything outside a centered receipt rectangle (portrait 3:4
/// ratio) and draws white corner marks so the user knows where to place
/// the receipt. Purely visual — it does not crop the captured photo.
class ReceiptPhotoFrameOverlay extends StatelessWidget {
  const ReceiptPhotoFrameOverlay({super.key, this.hint = 'Coloca el recibo aquí'});

  /// Hint rendered just below the frame.
  final String hint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Receipt-like portrait box: 74% of width, 1.38 ratio, centered
        // slightly above center to leave room for the shutter bar.
        // Fully guarded so tiny/test viewports never hit an inverted clamp.
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
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          );
        }

        var frameWidth = maxW * 0.74;
        // Keep side margins.
        if (frameWidth > maxW - 32) frameWidth = maxW - 32;
        var frameHeight = frameWidth * 1.38;
        // Keep vertical room for top bar + shutter + hint.
        final maxFrameHeight = maxH - 180;
        if (maxFrameHeight > 120 && frameHeight > maxFrameHeight) {
          frameHeight = maxFrameHeight;
          frameWidth = frameHeight / 1.38;
        }

        var frameLeft = (maxW - frameWidth) / 2;
        if (frameLeft < 8) frameLeft = 8;
        var frameTop = (maxH - frameHeight) / 2 - 30;
        if (frameTop < 8) frameTop = 8;
        final maxTop = maxH - frameHeight - 34;
        if (maxTop >= 8 && frameTop > maxTop) frameTop = maxTop;

        final frameRect = Rect.fromLTWH(
          frameLeft,
          frameTop,
          frameWidth,
          frameHeight,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _FramePainter(frameRect),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: frameRect.bottom + 10,
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.frame);

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    // Dim everything outside the frame.
    final dim = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(frame, const Radius.circular(14)),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = const Color(0x99000000));

    // Thin white border.
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(14)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Accent corner marks (L-shaped, primary green).
    const cornerLen = 28.0;
    const cornerWidth = 4.5;
    final cornerPaint = Paint()
      ..color = const Color(0xFF8FB42C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerWidth
      ..strokeCap = StrokeCap.round;

    final corners = <Offset, List<Offset>>{
      frame.topLeft: [
        frame.topLeft + const Offset(cornerLen, 0),
        frame.topLeft + const Offset(0, cornerLen),
      ],
      frame.topRight: [
        frame.topRight + const Offset(-cornerLen, 0),
        frame.topRight + const Offset(0, cornerLen),
      ],
      frame.bottomLeft: [
        frame.bottomLeft + const Offset(cornerLen, 0),
        frame.bottomLeft + const Offset(0, -cornerLen),
      ],
      frame.bottomRight: [
        frame.bottomRight + const Offset(-cornerLen, 0),
        frame.bottomRight + const Offset(0, -cornerLen),
      ],
    };

    for (final entry in corners.entries) {
      for (final end in entry.value) {
        canvas.drawLine(entry.key, end, cornerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.frame != frame;
}
