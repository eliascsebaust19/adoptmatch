import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: context.read<AuthBloc>(),
        child: const ChangePasswordDialog(),
      ),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final newPassword = _newPasswordController.text.trim();
    if (newPassword != _confirmPasswordController.text.trim()) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    // The server is the only authority: no offline/mock success path.
    context.read<AuthBloc>().add(ChangePasswordEvent(
      currentPassword: _currentPasswordController.text.trim(),
      newPassword: newPassword,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthPasswordChanged) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Color(0xFF059669),
            content: Text('Password updated on the server.'),
          ));
        } else if (state is AuthFailure) {
          setState(() { _isLoading = false; _errorMessage = state.errorMessage; });
        } else if (state is AuthLoading) {
          setState(() => _isLoading = true);
        }
      },
      child: Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.modal),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slateDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Update your account security credentials',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              if (_errorMessage != null) ...[
                AppErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              AppTextField(
                controller: _currentPasswordController,
                label: 'Current Password',
                hint: 'Enter your current password',
                obscureText: true,
                prefixIconData: Icons.lock_open_rounded,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter your current password'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // New Password
              AppTextField(
                controller: _newPasswordController,
                label: 'New Password',
                hint: 'At least 8 characters',
                obscureText: _obscureNew,
                prefixIconData: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (val.trim().length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Confirm New Password
              AppTextField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                hint: 'Re-enter your new password',
                obscureText: _obscureConfirm,
                prefixIconData: Icons.lock_clock_outlined,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (val != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              // Password requirement note
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Use numbers, letters & symbols for stronger security.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: AppPrimaryButton(
                      text: 'Update Password',
                      isLoading: _isLoading,
                      onPressed: _handleSubmit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
