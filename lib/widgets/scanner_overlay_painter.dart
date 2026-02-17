import 'package:flutter/material.dart';

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final double scannerSize = size.width * 0.7;
    final double left = (size.width - scannerSize) / 2;
    final double top = (size.height - scannerSize) / 2;

    final cutoutPath = Path()
      ..addRect(Rect.fromLTWH(left, top, scannerSize, scannerSize));

    final overlayPath = Path.combine(
      PathOperation.difference,
      path,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, paint);

    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, scannerSize, scannerSize),
        const Radius.circular(16),
      ),
      outlinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}