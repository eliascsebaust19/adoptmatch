import 'package:flutter/material.dart';
import 'paw_logo.dart';

/// A dedicated, smooth pulsing loading overlay animation for all auth actions.
/// Adheres to motion design standards with gentle scale and fade transitions.
class AuthLoadingOverlay extends StatefulWidget {
  final String actionType; // 'google', 'admin', 'signup', 'signin', 'otp'
  final String? customTitle;
  final String? customSubtitle;

  const AuthLoadingOverlay({
    super.key,
    required this.actionType,
    this.customTitle,
    this.customSubtitle,
  });

  @override
  State<AuthLoadingOverlay> createState() => _AuthLoadingOverlayState();
}

class _AuthLoadingOverlayState extends State<AuthLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );

    _glowAnimation = Tween<double>(begin: 0.20, end: 0.45).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.customTitle != null) return widget.customTitle!;
    switch (widget.actionType) {
      case 'google':
        return 'Connecting with Google...';
      case 'admin':
        return 'Authenticating Admin Portal...';
      case 'signup':
        return 'Creating Rescue Account...';
      case 'otp':
        return 'Sending Verification Code...';
      case 'signin':
      default:
        return 'Signing in to AdoptMatch...';
    }
  }

  String get _subtitle {
    if (widget.customSubtitle != null) return widget.customSubtitle!;
    switch (widget.actionType) {
      case 'google':
        return 'Authenticating your Google identity securely';
      case 'admin':
        return 'Verifying administrative privileges & security tokens';
      case 'signup':
        return 'Setting up your profile & ethical adoption preferences';
      case 'otp':
        return 'Dispatching 6-digit code to your email';
      case 'signin':
      default:
        return 'Securing session & loading pet recommendations';
    }
  }

  Color get _accentColor {
    switch (widget.actionType) {
      case 'admin':
        return const Color(0xFF6366F1); // Indigo for admin
      case 'google':
        return const Color(0xFF0D9488); // Teal
      case 'signup':
        return const Color(0xFFE11D48); // Rose
      case 'signin':
      default:
        return const Color(0xFF0D9488); // Teal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: Center(
          child: Container(
            width: 310,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing Logo Animation with dynamic glow
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(_glowAnimation.value),
                              blurRadius: 22,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: widget.actionType == 'admin'
                            ? Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _accentColor, width: 2),
                                ),
                                child: const Icon(
                                  Icons.shield_rounded,
                                  color: Color(0xFF6366F1),
                                  size: 36,
                                ),
                              )
                            : const PawLogo(size: 68, showShadow: false),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Smooth Circular Progress Indicator
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: _accentColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Title Text
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle Text
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
