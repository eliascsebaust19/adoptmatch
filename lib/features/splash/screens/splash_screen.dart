import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../shared/widgets/paw_logo.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/repositories/auth_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
    _checkSessionAndNavigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkSessionAndNavigate() async {
    // Minimum branding display duration for smooth UX
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // 1. Guard First-Time Installation Onboarding
    final hasSeenOnboarding = await LocalStorageService.instance.loadHasSeenOnboarding();
    if (!hasSeenOnboarding) {
      if (mounted) context.go('/onboarding');
      return;
    }

    // 2. Check for Persistent Authentication Session
    final hasToken = await SecureStorageService.instance.hasValidToken();
    if (!hasToken) {
      if (mounted) {
        context.read<AuthBloc>().add(CheckSessionEvent());
        context.go('/login');
      }
      return;
    }

    // 3. Verify Token with Backend API (GET /api/v1/auth/me)
    try {
      final authRepo = AuthRepository();
      // Bounded: a sleeping API must not hold the splash for a full minute.
      // A timeout takes the same cached-profile path as a failed session check.
      final user = await authRepo
          .verifyCurrentSession()
          .timeout(ApiClient.connectTimeout, onTimeout: () => null);

      if (!mounted) return;

      if (!mounted) return;
      if (user != null) {
        context.read<AuthBloc>().add(UserConfirmedSessionEvent(user));
        if (user.role.hasAdminAccess) {
          context.go('/admin/dashboard');
        } else {
          context.go('/home');
        }
      } else {
        final cachedUser = await SecureStorageService.instance.getUserProfile();
        if (!mounted) return;
        if (cachedUser != null) {
          context.read<AuthBloc>().add(UserConfirmedSessionEvent(cachedUser));
          if (cachedUser.role.hasAdminAccess) {
            context.go('/admin/dashboard');
          } else {
            context.go('/home');
          }
        } else {
          context.read<AuthBloc>().add(CheckSessionEvent());
          context.go('/login');
        }
      }
    } catch (_) {
      final cachedUser = await SecureStorageService.instance.getUserProfile();
      if (!mounted) return;
      if (cachedUser != null) {
        context.read<AuthBloc>().add(UserConfirmedSessionEvent(cachedUser));
        if (cachedUser.role.hasAdminAccess) {
          context.go('/admin/dashboard');
        } else {
          context.go('/home');
        }
      } else {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const PawLogo(size: 88),
                const SizedBox(height: 20),
                const Text(
                  'AdoptMatch',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connecting Hearts & Paws',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF0D9488),
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
