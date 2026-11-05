import 'package:flutter/material.dart';

class SignatureCanvas extends StatefulWidget {
  final ValueChanged<bool> onSignatureChanged;

  const SignatureCanvas({super.key, required this.onSignatureChanged});

  @override
  State<SignatureCanvas> createState() => _SignatureCanvasState();
}

class _SignatureCanvasState extends State<SignatureCanvas> {
  final List<Offset?> _points = [];

  void _clear() {
    setState(() {
      _points.clear();
    });
    widget.onSignatureChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Digital Signature Canvas',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
            ),
            if (_points.isNotEmpty)
              GestureDetector(
                onTap: _clear,
                child: const Text('Clear Signature', style: TextStyle(color: Color(0xFFE11D48), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 130,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _points.isNotEmpty ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
              width: _points.isNotEmpty ? 1.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                if (_points.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.draw_outlined, size: 28, color: Color(0xFF94A3B8)),
                        SizedBox(height: 6),
                        Text(
                          'Sign with touch or mouse here',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onPanUpdate: (DragUpdateDetails details) {
                    final renderBox = context.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final localPosition = renderBox.globalToLocal(details.globalPosition);
                      setState(() {
                        _points.add(localPosition);
                      });
                      widget.onSignatureChanged(true);
                    }
                  },
                  onPanEnd: (DragEndDetails details) {
                    _points.add(null);
                  },
                  child: CustomPaint(
                    painter: _SignaturePainter(points: _points),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

typedef SignatureCanvasWidget = SignatureCanvas;

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
