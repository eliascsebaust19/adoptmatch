import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show AuthState;

import '../bloc/auth_bloc.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/paw_logo.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  String _statusMessage = 'Confirming your email and activating account...';
  bool _hasError = false;
  StreamSubscription<sb.AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _handleAuthCallback();
  }

  Future<void> _handleAuthCallback() async {
    if (!SupabaseService.isInitialized) {
      setState(() {
        _hasError = true;
        _statusMessage =
            'Authentication is not configured on this build. Set SUPABASE_URL '
            'and SUPABASE_ANON_KEY.';
      });
      return;
    }

    // Web OAuth and email links land here with `?code=` (PKCE). The exchange has
    // to happen while the URL still carries the code, i.e. before any
    // navigation, and it also covers recovery links.
    if (SupabaseService.auth.currentSession == null) {
      try {
        await SupabaseService.completeWebRedirect();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _statusMessage = e is AuthException
              ? 'This link is invalid or has expired: ${e.message}'
              : 'We could not finish signing you in. Please try again.';
        });
        return;
      }
    }

    // Recovery links must not log the user in: they choose a new password
    // first, then sign in again.
    if (SupabaseService.pendingRecoveryRoute != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/auth/reset-password');
      });
      return;
    }

    final session = SupabaseService.auth.currentSession;
    if (session != null) {
      _onConfirmed(session);
      return;
    }

    // Magic link / implicit flow: listen for the session exchange.
    _authSubscription = SupabaseService.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final currentSession = data.session;
      if ((event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.userUpdated) &&
          currentSession != null) {
        _onConfirmed(currentSession);
      }
    });

    // Timeout fallback after 6 seconds if no session is captured
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _authSubscription != null && !_hasError) {
        final session = SupabaseService.auth.currentSession;
        if (session == null) {
          setState(() {
            _hasError = true;
            _statusMessage =
                'Unable to auto-detect confirmation session. Please try logging in with your email.';
          });
        }
      }
    });
  }

  void _onConfirmed(Session session) {
    if (!mounted) return;
    final user = session.user;
    final fullName =
        user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String? ??
        user.email?.split('@').first ??
        'Adopter';
    final avatar = (user.userMetadata?['avatar_url'] ??
            user.userMetadata?['picture'] ??
            '')
        .toString();

    context.read<AuthBloc>().add(
      UserConfirmedSessionEvent(
        UserProfile(
          id: user.id,
          name: fullName,
          email: user.email ?? '',
          phone: user.phone ?? '',
          role: UserRole.adopter,
          isVerified: true,
          avatarUrl: avatar,
          googlePhotoUrl: avatar,
        ),
        accessToken: session.accessToken,
      ),
    );

    setState(() {
      _statusMessage =
          'Account verified successfully! Welcome to AdoptMatch 🎉';
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFE05626);
    const slateDark = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PawLogo(size: 80),
              const SizedBox(height: 28),
              if (!_hasError) ...[
                const CircularProgressIndicator(color: brandOrange),
                const SizedBox(height: 24),
              ] else ...[
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFE11D48),
                  size: 48,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                _hasError ? 'Verification Notice' : 'Activating Account',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: slateDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              if (_hasError) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => context.go('/auth/login'),
                  child: const Text('Back to Sign In'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
