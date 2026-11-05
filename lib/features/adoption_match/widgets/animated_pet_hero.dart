import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A 3D Interactive Hero Card with Perspective Matrix Transform,
/// Gyro/Touch Tilt Parallax, Floating Depth Layers, and Dynamic Lighting.
class AnimatedPetHeroCard extends StatefulWidget {
  final VoidCallback? onFindCompanion;

  const AnimatedPetHeroCard({super.key, this.onFindCompanion});

  @override
  State<AnimatedPetHeroCard> createState() => _AnimatedPetHeroCardState();
}

class _AnimatedPetHeroCardState extends State<AnimatedPetHeroCard>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _pettingBounceController;

  // Touch interactive tilt offsets
  double _touchTiltX = 0.0;
  double _touchTiltY = 0.0;
  bool _isHappyPetted = false;

  @override
  void initState() {
    super.initState();
    // Continuous floating breathing animation in 3D
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    // Petting squash & stretch reaction
    _pettingBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    _pettingBounceController.dispose();
    super.dispose();
  }

  void _triggerPettingHappiness() {
    if (_pettingBounceController.isAnimating) return;
    _pettingBounceController.forward(from: 0.0).then((_) {
      if (mounted) _pettingBounceController.reverse();
    });

    setState(() => _isHappyPetted = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _isHappyPetted = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0D9488);
    const deepTeal = Color(0xFF0F766E);
    const darkTeal = Color(0xFF115E59);
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: Listenable.merge([_idleController, _pettingBounceController]),
      builder: (context, child) {
        final t = disableAnimations ? 0.0 : _idleController.value;
        final bounceVal = _pettingBounceController.value;

        // Smooth sinusoidal floating oscillation
        final idlePitch = math.sin(t * 2 * math.pi) * 0.055;
        final idleYaw = math.cos(t * 2 * math.pi) * 0.065;
        final idleFloat = math.sin(t * 2 * math.pi) * 4.0;

        // Combined 3D angles (idle + user finger pan)
        final totalPitch = idlePitch + _touchTiltX;
        final totalYaw = idleYaw + _touchTiltY;

        // Dynamic 3D shadow shifting opposite to the tilt
        final shadowDx = -totalYaw * 30.0;
        final shadowDy = 10.0 - totalPitch * 24.0 + idleFloat;

        return GestureDetector(
          onPanUpdate: (details) {
            // Interactive 3D tilt response as user drags across card
            setState(() {
              _touchTiltY = (_touchTiltY + details.delta.dx * 0.0015).clamp(-0.16, 0.16);
              _touchTiltX = (_touchTiltX - details.delta.dy * 0.0015).clamp(-0.16, 0.16);
            });
          },
          onPanEnd: (_) {
            // Smoothly spring back to center when released
            setState(() {
              _touchTiltX = 0.0;
              _touchTiltY = 0.0;
            });
          },
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // Perspective depth
              ..translate(0.0, idleFloat, 0.0)
              ..rotateX(totalPitch)
              ..rotateY(totalYaw),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [primaryTeal, deepTeal, darkTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryTeal.withOpacity(0.32),
                    blurRadius: 22 + idleFloat.abs(),
                    offset: Offset(shadowDx, shadowDy),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Dynamic 3D Specular Light Sheen / Glass Sweep
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(totalYaw * 3.5 - 0.7, totalPitch * 3.5 - 0.7),
                              end: Alignment(totalYaw * 3.5 + 0.7, totalPitch * 3.5 + 0.7),
                              colors: [
                                Colors.white.withOpacity(0.14),
                                Colors.white.withOpacity(0.02),
                                Colors.transparent,
                                Colors.white.withOpacity(0.06),
                              ],
                              stops: const [0.0, 0.25, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2. Background 3D Parallax Ambient Icons
                    Positioned(
                      right: -15 - (totalYaw * 40),
                      bottom: -20 - (totalPitch * 30),
                      child: Transform.rotate(
                        angle: -totalYaw * 0.5,
                        child: Icon(
                          Icons.pets,
                          size: 145,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -15 + (totalYaw * 30),
                      top: -15 + (totalPitch * 25),
                      child: Icon(
                        Icons.favorite,
                        size: 90,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),

                    // 3. Main Content Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Row(
                        children: [
                          // Left Column: Text & CTA
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Ethical Tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.volunteer_activism, size: 12, color: Color(0xFF99F6E4)),
                                      SizedBox(width: 5),
                                      Text(
                                        '100% Ethical • Zero Breeding',
                                        style: TextStyle(
                                          color: Color(0xFFCCFBF1),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                const Text(
                                  'Find Your Perfect\nCompanion',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                Text(
                                  'Over 40+ rescued pets waiting for a loving home.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.88),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                ElevatedButton.icon(
                                  icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0F766E)),
                                  label: const Text(
                                    'Match Quiz',
                                    style: TextStyle(
                                      color: Color(0xFF0F766E),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF0F766E),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 3,
                                  ),
                                  onPressed: widget.onFindCompanion ?? () => context.push('/quiz'),
                                ),
                              ],
                            ),
                          ),

                          // Right Column: 3D Floating Diorama Mascot
                          Expanded(
                            flex: 5,
                            child: GestureDetector(
                              onTap: _triggerPettingHappiness,
                              child: Transform.translate(
                                // Parallax pop-out in front of the card plane!
                                offset: Offset(totalYaw * 32.0, totalPitch * 28.0),
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // 3D Floating Particles on Petting
                                    if (_isHappyPetted)
                                      Positioned(
                                        top: -24 - (bounceVal * 12),
                                        child: AnimatedOpacity(
                                          opacity: _isHappyPetted ? 1.0 : 0.0,
                                          duration: const Duration(milliseconds: 300),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Text('❤️', style: TextStyle(fontSize: 18)),
                                              SizedBox(width: 4),
                                              Text('✨', style: TextStyle(fontSize: 15)),
                                              SizedBox(width: 4),
                                              Text('🐾', style: TextStyle(fontSize: 17)),
                                              SizedBox(width: 4),
                                              Text('🥰', style: TextStyle(fontSize: 16)),
                                            ],
                                          ),
                                        ),
                                      ),

                                    // 3D Diorama Mascot Canvas
                                    Transform.scale(
                                      scale: 1.0 + (bounceVal * 0.12),
                                      child: CustomPaint(
                                        size: const Size(130, 130),
                                        painter: _Mascot3DPainter(
                                          animationProgress: t,
                                          isExcited: _isHappyPetted,
                                          tiltPitch: totalPitch,
                                          tiltYaw: totalYaw,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Advanced 3D Canvas Painter rendering a playful Puppy & Kitten
/// with multi-layer spherical depth, dynamic perspective shadows,
/// glossy highlights, ear bounce, blinking eyes, and wagging 3D tail.
class _Mascot3DPainter extends CustomPainter {
  final double animationProgress;
  final bool isExcited;
  final double tiltPitch;
  final double tiltYaw;

  _Mascot3DPainter({
    required this.animationProgress,
    required this.isExcited,
    required this.tiltPitch,
    required this.tiltYaw,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.52, size.height * 0.52);

    final wave = math.sin(animationProgress * 2 * math.pi);
    final fastWave = math.sin(animationProgress * 6 * math.pi);
    final tailAngle = isExcited ? (fastWave * 0.55) : (wave * 0.28);
    final earBounce = isExcited ? (fastWave * 3.5) : (wave * 2.2);
    final isBlinking = (animationProgress > 0.46 && animationProgress < 0.52);

    // Dynamic light direction based on 3D tilt
    final lightOffset = Offset(
      center.dx - 18 + (tiltYaw * 35),
      center.dy - 22 + (tiltPitch * 30),
    );

    // 1. Dynamic Contact Shadow on Ground
    final shadowWidth = 92.0 + (wave * 4.0);
    final shadowCenter = Offset(center.dx + (tiltYaw * 15), size.height - 10 + (tiltPitch * 8));
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withOpacity(0.35),
          Colors.black.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCenter(center: shadowCenter, width: shadowWidth, height: 20));
    canvas.drawOval(
      Rect.fromCenter(center: shadowCenter, width: shadowWidth, height: 18),
      shadowPaint,
    );

    // 2. Wagging 3D Puppy Tail
    final tailPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round;

    final tailPath = Path();
    tailPath.moveTo(center.dx + 26, center.dy + 20);
    final tailEnd = Offset(
      center.dx + 48 + (tailAngle * 26),
      center.dy + 8 + (tailAngle * 12),
    );
    tailPath.quadraticBezierTo(
      center.dx + 38 + (tailAngle * 10),
      center.dy + 12,
      tailEnd.dx,
      tailEnd.dy,
    );
    canvas.drawPath(tailPath, tailPaint);

    // 3. 3D Spherical Shaded Body
    final bodyCenter = Offset(center.dx, center.dy + 10);
    final bodyRect = Rect.fromCenter(center: bodyCenter, width: 72, height: 56);
    final bodyShader = RadialGradient(
      center: Alignment(
        ((lightOffset.dx - bodyCenter.dx) / 36).clamp(-0.8, 0.8),
        ((lightOffset.dy - bodyCenter.dy) / 28).clamp(-0.8, 0.8),
      ),
      radius: 0.85,
      colors: const [
        Color(0xFFFDE68A), // Light Golden
        Color(0xFFF59E0B), // Warm Amber
        Color(0xFFD97706), // Rich Amber
        Color(0xFFB45309), // Deep shadow edge
      ],
      stops: const [0.0, 0.45, 0.80, 1.0],
    ).createShader(bodyRect);

    canvas.drawOval(bodyRect, Paint()..shader = bodyShader);

    // 4. White Chest Fur Fluff
    final chestRect = Rect.fromCenter(center: Offset(bodyCenter.dx - 4, bodyCenter.dy + 8), width: 34, height: 28);
    final chestShader = RadialGradient(
      colors: [
        Colors.white.withOpacity(0.92),
        const Color(0xFFFEF3C7).withOpacity(0.85),
      ],
    ).createShader(chestRect);
    canvas.drawOval(chestRect, Paint()..shader = chestShader);

    // 5. 3D Spherical Shaded Head
    final headCenter = Offset(center.dx - 8 + (tiltYaw * 8), center.dy - 14 + (tiltPitch * 6));
    final headRect = Rect.fromCircle(center: headCenter, radius: 28);
    final headShader = RadialGradient(
      center: Alignment(
        ((lightOffset.dx - headCenter.dx) / 28).clamp(-0.8, 0.8),
        ((lightOffset.dy - headCenter.dy) / 28).clamp(-0.8, 0.8),
      ),
      radius: 0.9,
      colors: const [
        Color(0xFFFEF08A),
        Color(0xFFFBBF24),
        Color(0xFFD97706),
        Color(0xFF92400E),
      ],
      stops: const [0.0, 0.45, 0.82, 1.0],
    ).createShader(headRect);

    canvas.drawCircle(headCenter, 28, Paint()..shader = headShader);

    // 6. Floppy 3D Puppy Ears
    final leftEarPaint = Paint()..color = const Color(0xFFB45309);
    final leftEarPath = Path();
    leftEarPath.moveTo(headCenter.dx - 18, headCenter.dy - 12);
    leftEarPath.quadraticBezierTo(
      headCenter.dx - 32,
      headCenter.dy + earBounce,
      headCenter.dx - 22,
      headCenter.dy + 18 + earBounce,
    );
    leftEarPath.quadraticBezierTo(
      headCenter.dx - 14,
      headCenter.dy + 12,
      headCenter.dx - 8,
      headCenter.dy - 14,
    );
    canvas.drawPath(leftEarPath, leftEarPaint);

    final rightEarPaint = Paint()..color = const Color(0xFF92400E);
    final rightEarPath = Path();
    rightEarPath.moveTo(headCenter.dx + 12, headCenter.dy - 14);
    rightEarPath.quadraticBezierTo(
      headCenter.dx + 30,
      headCenter.dy - earBounce,
      headCenter.dx + 26,
      headCenter.dy + 14 - earBounce,
    );
    rightEarPath.quadraticBezierTo(
      headCenter.dx + 16,
      headCenter.dy + 10,
      headCenter.dx + 6,
      headCenter.dy - 12,
    );
    canvas.drawPath(rightEarPath, rightEarPaint);

    // 7. 3D Muzzle & Shiny Wet Nose
    final muzzleCenter = Offset(headCenter.dx, headCenter.dy + 8);
    final muzzleRect = Rect.fromCenter(center: muzzleCenter, width: 26, height: 18);
    canvas.drawOval(
      muzzleRect,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFFFFFBEB), Color(0xFFFDE68A)],
        ).createShader(muzzleRect),
    );

    // Black Nose with 3D Specular Highlight
    final noseCenter = Offset(muzzleCenter.dx, muzzleCenter.dy - 2);
    canvas.drawOval(
      Rect.fromCenter(center: noseCenter, width: 9, height: 6.5),
      Paint()..color = const Color(0xFF1E293B),
    );
    // White light reflection on nose tip
    canvas.drawCircle(
      Offset(noseCenter.dx - 1.5, noseCenter.dy - 1.2),
      1.3,
      Paint()..color = Colors.white,
    );

    // Happy smiling mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF451A03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();
    mouthPath.moveTo(noseCenter.dx - 4, noseCenter.dy + 4);
    mouthPath.quadraticBezierTo(noseCenter.dx, noseCenter.dy + 7, noseCenter.dx + 4, noseCenter.dy + 4);
    canvas.drawPath(mouthPath, mouthPaint);

    // 8. 3D Expressive Eyes
    final leftEyeCenter = Offset(headCenter.dx - 9, headCenter.dy - 2);
    final rightEyeCenter = Offset(headCenter.dx + 9, headCenter.dy - 2);

    if (isBlinking || isExcited) {
      // Happy squint curves ^ ^
      final eyeArcPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      final leftArc = Path()
        ..moveTo(leftEyeCenter.dx - 4, leftEyeCenter.dy + 1)
        ..quadraticBezierTo(leftEyeCenter.dx, leftEyeCenter.dy - 3, leftEyeCenter.dx + 4, leftEyeCenter.dy + 1);
      final rightArc = Path()
        ..moveTo(rightEyeCenter.dx - 4, rightEyeCenter.dy + 1)
        ..quadraticBezierTo(rightEyeCenter.dx, rightEyeCenter.dy - 3, rightEyeCenter.dx + 4, rightEyeCenter.dy + 1);

      canvas.drawPath(leftArc, eyeArcPaint);
      canvas.drawPath(rightArc, eyeArcPaint);
    } else {
      // Large glossy 3D anime eyes
      final eyePaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawCircle(leftEyeCenter, 4.5, eyePaint);
      canvas.drawCircle(rightEyeCenter, 4.5, eyePaint);

      // Primary & Secondary glossy catchlights
      final catchlight = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(leftEyeCenter.dx - 1.2, leftEyeCenter.dy - 1.2), 1.6, catchlight);
      canvas.drawCircle(Offset(leftEyeCenter.dx + 1.4, leftEyeCenter.dy + 1.2), 0.8, catchlight);

      canvas.drawCircle(Offset(rightEyeCenter.dx - 1.2, rightEyeCenter.dy - 1.2), 1.6, catchlight);
      canvas.drawCircle(Offset(rightEyeCenter.dx + 1.4, rightEyeCenter.dy + 1.2), 0.8, catchlight);
    }

    // 9. Floating 3D Gold Rescue Shield Badge
    final badgeCenter = Offset(center.dx + 36 + (tiltYaw * 12), center.dy - 26 + (tiltPitch * 10) + (wave * 3));
    final badgeRect = Rect.fromCircle(center: badgeCenter, radius: 14);
    final badgeShader = const SweepGradient(
      colors: [
        Color(0xFFFDE047),
        Color(0xFFF59E0B),
        Color(0xFFD97706),
        Color(0xFFFEF08A),
        Color(0xFFFDE047),
      ],
    ).createShader(badgeRect);

    canvas.drawCircle(badgeCenter, 13, Paint()..shader = badgeShader);
    canvas.drawCircle(
      badgeCenter,
      11,
      Paint()
        ..color = const Color(0xFF0D9488)
        ..style = PaintingStyle.fill,
    );

    // White heart in badge center
    final heartPaint = Paint()..color = Colors.white;
    final hp = Path();
    final hx = badgeCenter.dx;
    final hy = badgeCenter.dy - 2;
    hp.moveTo(hx, hy + 5);
    hp.cubicTo(hx - 6, hy + 2, hx - 6, hy - 3, hx, hy - 1);
    hp.cubicTo(hx + 6, hy - 3, hx + 6, hy + 2, hx, hy + 5);
    canvas.drawPath(hp, heartPaint);
  }

  @override
  bool shouldRepaint(covariant _Mascot3DPainter oldDelegate) => true;
}
