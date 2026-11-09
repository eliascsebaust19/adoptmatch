import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../bloc/auth_bloc.dart';

/// Lands here from a Supabase password-recovery email.
///
/// The recovery link already established a short-lived session (PKCE code
/// exchanged by [SupabaseService.completeWebRedirect]), so the new password is
/// set with `auth.updateUser` and the user is signed out and sent to login.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _isSaving = false;
  bool _linkReady = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _prepareRecoverySession();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _prepareRecoverySession() async {
    if (!SupabaseService.isInitialized) {
      setState(() => _error =
          'Authentication is not configured on this build. Set SUPABASE_URL and SUPABASE_ANON_KEY.');
      return;
    }
    try {
      if (SupabaseService.auth.currentSession == null) {
        await SupabaseService.completeWebRedirect();
      }
    } on AuthException catch (e) {
      setState(() => _error = 'This recovery link is invalid or has expired '
          '(${e.message}). Request a new one from the sign-in screen.');
      return;
    } catch (_) {
      setState(() => _error =
          'This recovery link is invalid or has expired. Request a new one from the sign-in screen.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _linkReady = SupabaseService.auth.currentSession != null;
      if (!_linkReady) {
        _error =
            'This recovery link is invalid or has expired. Request a new one from the sign-in screen.';
      }
    });
  }

  Future<void> _savePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await SupabaseService.auth.updateUser(
        sb.UserAttributes(password: password),
      );
      await SupabaseService.auth.signOut();
      // The recovery session is gone; stop routing future logins here.
      SupabaseService.markRecoveryHandled();
      if (!mounted) return;
      setState(() {
        _successMessage = 'Password updated. Sign in with your new password.';
        _isSaving = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        context.read<AuthBloc>().add(const CheckSessionEvent());
        context.go('/login');
      }
    } on AuthException catch (e) {
      setState(() {
        _isSaving = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _isSaving = false;
        _error = 'Could not update the password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFE05626);
    const slateDark = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: slateDark,
        title: const Text('Set a new password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_successMessage != null)
                    AppCard(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else ...[
                    const Text(
                      'Choose a new password',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: slateDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your recovery link signs you in for a few minutes only. '
                      'Set the new password now and sign in again afterwards.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'New password',
                      controller: _passwordController,
                      obscureText: _obscure,
                      hintText: 'At least 8 characters',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: Colors.grey, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Confirm password',
                      controller: _confirmController,
                      obscureText: _obscure,
                      hintText: 'Repeat the new password',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: Colors.grey, size: 20),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFE11D48),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    AppPrimaryButton(
                      text: 'Update password',
                      isLoading: _isSaving,
                      height: 52,
                      borderRadius: 14,
                      onPressed: _linkReady && !_isSaving
                          ? _savePassword
                          : null,
                    ),
                    if (!_linkReady) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'Back to sign in',
                          style: TextStyle(
                            color: brandOrange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
