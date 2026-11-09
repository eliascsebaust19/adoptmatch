import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../../../core/network/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    // The API host sleeps when idle. Waking it while the user types keeps the
    // first sign-in from waiting on a container that has not started yet.
    unawaited(ApiClient.warmUp());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

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

      context.read<AuthBloc>().add(
        SignUpWithEmailEvent(
          fullName: name,
          email: email,
          password: password,
        ),
      );
    } else {
      if (email.isEmpty || password.isEmpty) {
        _showToast('Please enter your email and password');
        return;
      }

      context.read<AuthBloc>().add(
        LoginWithEmailEvent(email, password),
      );
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
            const Icon(Icons.mark_email_read_rounded, color: Color(0xFFE05626), size: 26),
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
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, color: Color(0xFFE05626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE05626)),
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
                  color: Color(0xFFE05626),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE05626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _isSignUp = false; // Switch to Sign In mode
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
                style: TextStyle(color: Color(0xFFE05626), fontWeight: FontWeight.bold),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE05626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFE05626);
    const slateDark = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            if (state.user.role.hasAdminAccess) {
              context.go('/admin/dashboard');
            } else {
              context.go('/home');
            }
          } else if (state is AuthSignUpConfirmationPending) {
            _showEmailConfirmationDialog(state.email, state.message);
          } else if (state is AuthEmailDispatched) {
            // Password recovery: resending the confirmation mail would be the
            // wrong action, so only the acknowledge button is offered.
            _showEmailConfirmationDialog(
              state.email,
              state.message,
              title: 'Email Sent',
              showResend: false,
            );
          } else if (state is AuthFailure) {
            _showErrorDialog(state.errorMessage);
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  const PawLogo(size: 80),
                  const SizedBox(height: 24),

                  // Heading Card
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
                        Text(
                          _isSignUp ? 'Create Account' : 'Welcome Back!',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: slateDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSignUp
                              ? 'Join AdoptMatch to adopt & support rescues'
                              : 'Sign in to access your adoption profile',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Registration Full Name field
                        if (_isSignUp) ...[
                          AppTextField(
                            label: 'Full Name',
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            hintText: 'e.g. Full Name',
                            prefixIcon: const Icon(Icons.person_outline, color: Colors.grey, size: 20),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email Field
                        AppTextField(
                          label: 'Email Address',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          hintText: 'Enter your email',
                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey, size: 20),
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
                            if (!_isSignUp)
                              GestureDetector(
                                onTap: () {
                                  final email = _emailController.text.trim();
                                  if (email.isEmpty || !email.contains('@')) {
                                    _showToast(
                                      'Enter your email address, then tap Forgot Password.',
                                    );
                                    return;
                                  }
                                  context
                                      .read<AuthBloc>()
                                      .add(RequestPasswordResetEvent(email));
                                },
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: brandOrange,
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
                          hintText: _isSignUp ? 'Create password (min 6 chars)' : 'Enter your password',
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
                        const SizedBox(height: 24),

                        // Primary Action Button (Sign In / Create Account)
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;

                            return AppPrimaryButton(
                              text: _isSignUp ? 'Create Account' : 'Sign In',
                              onPressed: _handleSubmit,
                              isLoading: isLoading,
                              height: 52,
                              borderRadius: 14,
                              icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                            );
                          },
                        ),
                        const SizedBox(height: 18),

                        // Create Account / Sign In Toggle
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
                                      color: brandOrange,
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
                  const SizedBox(height: 24),

                  // Social Login Section
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
                  const SizedBox(height: 18),

                  // Prominent & Centered "Continue with Google"
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      final isLoading = authState is AuthLoading;

                      return Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            onTap: isLoading
                                ? null
                                : () {
                                    context.read<AuthBloc>().add(const SocialLoginEvent('google'));
                                  },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isLoading) ...[
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFE05626),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Signing in with Google...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ] else ...[
                                  const GoogleOfficialLogo(size: 20),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
