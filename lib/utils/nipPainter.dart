import 'package:flutter/material.dart';

class NipPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;

  NipPainter({
    this.borderColor = Colors.white, // Default border color
    this.borderWidth = 2.0, // Default border width
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(120) // Match container color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();
    path.moveTo(0, size.height); // Start at bottom-left of nip
    path.lineTo(size.width / 2, 0); // Tip of the nip
    path.lineTo(size.width, size.height); // Bottom-right of nip
    path.close();

    // Draw the fill color of the nip
    canvas.drawPath(path, paint);

    // Draw the border around the nip
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
