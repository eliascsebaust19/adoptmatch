import 'package:flutter/material.dart';

/// Official multi-color Google 'G' brand logo
class GoogleOfficialLogo extends StatelessWidget {
  final double size;
  const GoogleOfficialLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final fillPaint = Paint()..style = PaintingStyle.fill;

    // 1. Blue path
    final bluePath = Path()
      ..moveTo(22.56, 12.25)
      ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10.0)
      ..lineTo(12.0, 10.0)
      ..lineTo(12.0, 14.26)
      ..lineTo(17.92, 14.26)
      ..cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57)
      ..lineTo(15.71, 20.34)
      ..lineTo(19.28, 20.34)
      ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
      ..close();
    fillPaint.color = const Color(0xFF4285F4);
    canvas.drawPath(bluePath, fillPaint);

    // 2. Green path
    final greenPath = Path()
      ..moveTo(12.0, 23.0)
      ..cubicTo(14.97, 23.0, 17.46, 22.02, 19.28, 20.34)
      ..lineTo(15.71, 17.57)
      ..cubicTo(14.73, 18.23, 13.48, 18.63, 12.0, 18.63)
      ..cubicTo(9.14, 18.63, 6.71, 16.7, 5.84, 14.1)
      ..lineTo(2.18, 14.1)
      ..lineTo(2.18, 16.94)
      ..cubicTo(3.99, 20.53, 7.7, 23.0, 12.0, 23.0)
      ..close();
    fillPaint.color = const Color(0xFF34A853);
    canvas.drawPath(greenPath, fillPaint);

    // 3. Yellow path
    final yellowPath = Path()
      ..moveTo(5.84, 14.1)
      ..cubicTo(5.62, 13.44, 5.49, 12.74, 5.49, 12.0)
      ..cubicTo(5.49, 11.26, 5.62, 10.56, 5.84, 9.9)
      ..lineTo(5.84, 7.06)
      ..lineTo(2.18, 7.06)
      ..cubicTo(1.43, 8.55, 1.0, 10.22, 1.0, 12.0)
      ..cubicTo(1.0, 13.78, 1.43, 15.45, 2.18, 16.94)
      ..lineTo(5.84, 14.1)
      ..close();
    fillPaint.color = const Color(0xFFFBBC05);
    canvas.drawPath(yellowPath, fillPaint);

    // 4. Red path
    final redPath = Path()
      ..moveTo(12.0, 5.38)
      ..cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02)
      ..lineTo(19.36, 3.87)
      ..cubicTo(17.45, 2.09, 14.97, 1.0, 12.0, 1.0)
      ..cubicTo(7.7, 1.0, 3.99, 3.47, 2.18, 7.06)
      ..lineTo(5.84, 9.9)
      ..cubicTo(6.71, 7.3, 9.14, 5.38, 12.0, 5.38)
      ..close();
    fillPaint.color = const Color(0xFFEA4335);
    canvas.drawPath(redPath, fillPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official modern X (formerly Twitter) brand logo
class XOfficialLogo extends StatelessWidget {
  final double size;
  final Color color;
  const XOfficialLogo({super.key, this.size = 18, this.color = const Color(0xFF0F172A)});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _XLogoPainter(color: color),
    );
  }
}

class _XLogoPainter extends CustomPainter {
  final Color color;
  const _XLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final xPath = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(18.244, 2.25)
      ..lineTo(21.552, 2.25)
      ..lineTo(14.325, 10.51)
      ..lineTo(22.827, 21.75)
      ..lineTo(16.17, 21.75)
      ..lineTo(10.956, 14.933)
      ..lineTo(4.99, 21.75)
      ..lineTo(1.68, 21.75)
      ..lineTo(9.41, 12.915)
      ..lineTo(1.254, 2.25)
      ..lineTo(8.08, 2.25)
      ..lineTo(12.793, 8.481)
      ..close()
      ..moveTo(17.083, 19.77)
      ..lineTo(18.916, 19.77)
      ..lineTo(7.084, 4.126)
      ..lineTo(5.117, 4.126)
      ..close();

    canvas.drawPath(xPath, fillPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

