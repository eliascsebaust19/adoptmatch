import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../auth/bloc/auth_bloc.dart';

/// Shows a secure dialog requesting the Administrator password.
/// Users CANNOT enter the admin dashboard without providing the correct password.
void showAdminAccessDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => BlocProvider.value(
      value: context.read<AuthBloc>(), child: const _AdminAccessDialog()),
  );
}

class _AdminAccessDialog extends StatefulWidget {
  const _AdminAccessDialog();

  @override
  State<_AdminAccessDialog> createState() => _AdminAccessDialogState();
}

class _AdminAccessDialogState extends State<_AdminAccessDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _verifyAndProceed() {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(AdminLoginWithEmailEvent(
      _emailController.text.trim(), _passwordController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated && state.user.role.hasAdminAccess) {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.go('/admin/dashboard');
        } else if (state is AuthFailure) {
          setState(() { _isLoading = false; _errorMessage = state.errorMessage; });
        } else if (state is AuthLoading) {
          setState(() => _isLoading = true);
        }
      },
      child: Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon & Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Color(0xFF0D9488),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Portal Access',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'পাসওয়ার্ড দিয়ে অ্যাডমিন পোর্টালে ঢুকুন',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 18),

                // Error message banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFBE123C),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Email field
                const Text(
                  'Admin Email / অ্যাডমিন ইমেইল',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18, color: Color(0xFF64748B)),
                    hintText: 'admin@adoptmatch.com',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter admin email';
                    if (!v.contains('@')) return 'Invalid email format';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password field
                const Text(
                  'Admin Password / পাসওয়ার্ড',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    hintText: 'Enter Admin Password',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'পাসওয়ার্ড দিন (Password is required)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Helper info hint
                Row(
                  children: const [
                    Icon(Icons.shield_outlined, size: 13, color: Color(0xFF94A3B8)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'পাসওয়ার্ড ছাড়া অ্যাডমিন প্যানেলে প্রবেশ সংরক্ষিত।',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Cancel / বাতিল', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.login_rounded, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Verify & Enter',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
