import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/supabase/adoptmatch_supabase.dart';
import '../../../config/demo_config.dart';
import '../../../shared/widgets/shared_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSignUp = false;
  bool _isAdminMode = false;
  bool _isSubmitting = false;

  /// Active action identifier for custom loading overlay: 'signin', 'signup', 'admin', 'google', 'otp'
  String _activeAction = 'signin';

  @override
  void initState() {
    super.initState();
    // Warm up API host when idle to prevent cold start delays
    unawaited(ApiClient.warmUp());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // ----------------------------------------------------
    // Mode A: Admin / Shelter Staff Authentication
    // ----------------------------------------------------
    if (_isAdminMode) {
      if (email.isEmpty || password.isEmpty) {
        _showToast('Please enter your shelter admin email and password');
        return;
      }
      if (!email.contains('@')) {
        _showToast('Please enter a valid administrator email');
        return;
      }

      setState(() {
        _activeAction = 'admin';
        _isSubmitting = true;
      });

      context.read<AuthBloc>().add(
        AdminLoginWithEmailEvent(email, password),
      );
      return;
    }

    // ----------------------------------------------------
    // Mode B: Adopter Sign Up
    // ----------------------------------------------------
    if (_isSignUp) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _showToast('Please enter your full name');
        return;
      }
      if (email.isEmpty || !email.contains('@')) {
        _showToast('Please enter a valid email address');
        return;
      }
      if (password.length < 6) {
        _showToast('Password must be at least 6 characters');
        return;
      }

      setState(() {
        _activeAction = 'signup';
        _isSubmitting = true;
      });

      context.read<AuthBloc>().add(
        SignUpWithEmailEvent(
          fullName: name,
          email: email,
          password: password,
        ),
      );
      return;
    }

    // ----------------------------------------------------
    // Mode C: Adopter Sign In (Direct or 6-digit OTP Guard)
    // ----------------------------------------------------
    if (email.isEmpty || password.isEmpty) {
      _showToast('Please enter your email and password');
      return;
    }
    if (!email.contains('@')) {
      _showToast('Please enter a valid email address');
      return;
    }

    // Fallback or demo bypass when strict OTP verification is toggled off
    if (!AdoptMatchBackend.isInitialized || !DemoConfig.enableStrictOTPVerification) {
      setState(() {
        _activeAction = 'signin';
        _isSubmitting = true;
      });

      context.read<AuthBloc>().add(
        LoginWithEmailEvent(email, password),
      );
      return;
    }

    // Dual Flow: Email + Password with 6-digit Email OTP Guard
    setState(() {
      _activeAction = 'otp';
      _isSubmitting = true;
    });

    try {
      await SupabaseAuthService.instance.loginWithPasswordAndSendOtp(
        email: email,
        password: password,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Redirect to OTP verification screen
      context.push('/verify-otp?email=${Uri.encodeComponent(email)}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showEmailConfirmationDialog(
    String email,
    String message, {
    String title = 'Verify Your Email',
    bool showResend = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_rounded, color: Color(0xFF0D9488), size: 26),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, color: Color(0xFF0D9488), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
            ),
          ],
        ),
        actions: [
          if (showResend)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<AuthBloc>().add(ResendConfirmationEvent(email));
              },
              child: const Text(
                'Resend email',
                style: TextStyle(
                  color: Color(0xFF0D9488),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _isSignUp = false;
              });
            },
            child: const Text('I will check my inbox'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    final isUnverified = error.toLowerCase().contains('verify your email') ||
        error.toLowerCase().contains('email not confirmed');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isUnverified ? Icons.verified_user_outlined : Icons.error_outline_rounded,
              color: isUnverified ? const Color(0xFFF59E0B) : const Color(0xFFE11D48),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isUnverified ? 'Verification Required' : 'Authentication Notice',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        content: Text(
          error,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          if (isUnverified)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                final email = _emailController.text.trim();
                if (email.isNotEmpty) {
                  context.read<AuthBloc>().add(ResendConfirmationEvent(email));
                }
              },
              child: const Text(
                'Resend link',
                style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealPrimary = Color(0xFF0D9488);
    const slateDark = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            setState(() => _isSubmitting = false);
            if (state.user.role.hasAdminAccess) {
              context.go('/admin/dashboard');
            } else {
              context.go('/home');
            }
          } else if (state is AuthSignUpConfirmationPending) {
            setState(() => _isSubmitting = false);
            _showEmailConfirmationDialog(state.email, state.message);
          } else if (state is AuthEmailDispatched) {
            setState(() => _isSubmitting = false);
            _showEmailConfirmationDialog(
              state.email,
              state.message,
              title: 'Email Sent',
              showResend: false,
            );
          } else if (state is AuthFailure) {
            setState(() => _isSubmitting = false);
            _showErrorDialog(state.errorMessage);
          }
        },
        builder: (context, state) {
          final isGlobalLoading = (state is AuthLoading) || _isSubmitting;

          return Stack(
            children: [
              // Main Scrollable Content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        const PawLogo(size: 80),
                        const SizedBox(height: 20),

                        // Main Auth Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ------------------------------------------
                              // 1. Role Segmented Switcher (Adopter vs Admin)
                              // ------------------------------------------
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: isGlobalLoading
                                            ? null
                                            : () {
                                                setState(() {
                                                  _isAdminMode = false;
                                                  _isSignUp = false;
                                                });
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: !_isAdminMode ? Colors.white : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: !_isAdminMode
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.06),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.person_outline_rounded,
                                                size: 16,
                                                color: !_isAdminMode ? tealPrimary : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Adopter / ইউজার',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: !_isAdminMode ? FontWeight.bold : FontWeight.w600,
                                                  color: !_isAdminMode ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: isGlobalLoading
                                            ? null
                                            : () {
                                                setState(() {
                                                  _isAdminMode = true;
                                                  _isSignUp = false;
                                                });
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _isAdminMode ? Colors.white : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: _isAdminMode
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.06),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.shield_outlined,
                                                size: 16,
                                                color: _isAdminMode ? tealPrimary : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Admin / অ্যাডমিন',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: _isAdminMode ? FontWeight.bold : FontWeight.w600,
                                                  color: _isAdminMode ? const Color(0xFF0F172A) : const Color(0xFF64748B),
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
                              const SizedBox(height: 18),

                              // Header Title
                              Text(
                                _isAdminMode
                                    ? 'Shelter & Admin Portal'
                                    : (_isSignUp ? 'Create Account' : 'Welcome Back!'),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: slateDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isAdminMode
                                    ? 'Sign in with shelter manager or admin credentials'
                                    : (_isSignUp
                                        ? 'Join AdoptMatch to adopt & support rescues'
                                        : 'Sign in to access your adoption profile'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),

                              // Quick Fill Demo Admin Chip (Viva / Defense only)
                              if (_isAdminMode && DemoConfig.enableVivaDemoPass) ...[
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _emailController.text = 'admin@adoptmatch.com';
                                      _passwordController.text = 'admin123';
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCCFBF1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF99F6E4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.key_rounded, size: 14, color: Color(0xFF0D9488)),
                                        SizedBox(width: 6),
                                        Text(
                                          'Quick Fill Demo Admin (Viva / Defense)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              // 1-Tap Free Access (2 Hours Demo Pass - Viva / Defense only)
                              if (!_isAdminMode && !_isSignUp && DemoConfig.enableVivaDemoPass) ...[
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: isGlobalLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _activeAction = 'signin';
                                            _isSubmitting = true;
                                          });
                                          context.read<AuthBloc>().add(const VivaDemoPassEvent());
                                        },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDFA),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF0D9488), width: 1.2),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.lock_open_rounded, size: 18, color: Color(0xFF0D9488)),
                                        SizedBox(width: 8),
                                        Text(
                                          '⚡ 1-Tap Free Access (2 Hours Viva Pass)',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Registration Full Name field
                              if (_isSignUp && !_isAdminMode) ...[
                                AppTextField(
                                  label: 'Full Name',
                                  controller: _nameController,
                                  keyboardType: TextInputType.name,
                                  hintText: 'e.g. Shakil Ahmed',
                                  prefixIcon: const Icon(Icons.person_outline, color: Colors.grey, size: 20),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Email Field
                              AppTextField(
                                label: _isAdminMode ? 'Administrator Email' : 'Email Address',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                hintText: _isAdminMode ? 'admin@adoptmatch.com' : 'Enter your email',
                                prefixIcon: Icon(
                                  _isAdminMode ? Icons.admin_panel_settings_outlined : Icons.email_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password Field
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Password',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: slateDark),
                                  ),
                                  if (!_isSignUp && !_isAdminMode)
                                    GestureDetector(
                                      onTap: () {
                                        final email = _emailController.text.trim();
                                        if (email.isEmpty || !email.contains('@')) {
                                          _showToast('Enter your email address, then tap Forgot Password.');
                                          return;
                                        }
                                        context.read<AuthBloc>().add(RequestPasswordResetEvent(email));
                                      },
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: tealPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              AppTextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                hintText: _isSignUp ? 'Create password (min 6 chars)' : 'Enter password',
                                prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              const SizedBox(height: 22),

                              // Primary Action Button
                              AppPrimaryButton(
                                text: _isAdminMode
                                    ? 'Sign In to Admin Portal'
                                    : (_isSignUp ? 'Create Account' : 'Sign In'),
                                onPressed: isGlobalLoading ? null : _handleSubmit,
                                isLoading: isGlobalLoading,
                                height: 50,
                                borderRadius: 14,
                                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(height: 16),

                              // Create Account / Sign In Toggle (Adopter mode only)
                              if (!_isAdminMode)
                                Center(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _isSignUp = !_isSignUp),
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                        children: [
                                          TextSpan(text: _isSignUp ? 'Already have an account? ' : "Don't have an account? "),
                                          TextSpan(
                                            text: _isSignUp ? 'Sign In' : 'Create One',
                                            style: const TextStyle(
                                              color: tealPrimary,
                                              fontWeight: FontWeight.w700,
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
                        const SizedBox(height: 22),

                        // Social Login Section (Google - Adopter mode only)
                        if (!_isAdminMode) ...[
                          Row(
                            children: const [
                              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Or Continue with',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Prominent "Continue with Google"
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: isGlobalLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _activeAction = 'google';
                                          _isSubmitting = true;
                                        });
                                        context.read<AuthBloc>().add(const SocialLoginEvent('google'));
                                      },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    GoogleOfficialLogo(size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // ==========================================
              // POLISHED AUTH LOADING ANIMATION OVERLAY
              // ==========================================
              if (isGlobalLoading)
                AuthLoadingOverlay(actionType: _activeAction),
            ],
          );
        },
      ),
    );
  }
}
