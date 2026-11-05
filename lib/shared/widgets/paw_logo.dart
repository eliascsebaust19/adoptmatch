import 'package:flutter/material.dart';

class PawLogo extends StatelessWidget {
  final double size;
  final bool showShadow;
  final double? borderRadius;
  const PawLogo({
    super.key,
    this.size = 64,
    this.showShadow = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.22);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/app_logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: CustomPaint(
                size: Size(size * 0.65, size * 0.65),
                painter: _PawPainter(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PawPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final fillPaint = Paint()
      ..color =
          const Color(0xFFE26D45) // Warm Terra Cotta / Orange
      ..style = PaintingStyle.fill;

    // Main pad
    final mainPadRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.68),
      width: size.width * 0.58,
      height: size.height * 0.44,
    );
    final mainPadRRect = RRect.fromRectAndRadius(
      mainPadRect,
      Radius.circular(size.width * 0.22),
    );
    canvas.drawRRect(mainPadRRect, fillPaint);
    canvas.drawRRect(mainPadRRect, borderPaint);

    // 4 toe pads
    final toeRadii = [
      Offset(size.width * 0.20, size.height * 0.35),
      Offset(size.width * 0.40, size.height * 0.22),
      Offset(size.width * 0.60, size.height * 0.22),
      Offset(size.width * 0.80, size.height * 0.35),
    ];

    for (final center in toeRadii) {
      canvas.drawCircle(center, size.width * 0.11, fillPaint);
      canvas.drawCircle(center, size.width * 0.11, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
