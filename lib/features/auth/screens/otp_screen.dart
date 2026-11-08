import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _pinControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() {
    final otp = _pinControllers.map((c) => c.text.trim()).join();
    if (otp.length != 6 || int.tryParse(otp) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter all 6 digits of the verification code.')),
      );
      return;
    }
    // Navigation is driven by the authenticated state, never by tapping verify.
    context.read<AuthBloc>().add(VerifyPhoneOtpEvent(widget.phoneNumber, otp));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isLoading = authState is AuthLoading;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent.')));
      },
      child: Scaffold(
      backgroundColor: AppColors.surfaceScaffold,
      appBar: AppBar(
        title: const Text('Phone Verification'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slateDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Enter the 6-digit code for ${widget.phoneNumber}',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              if (authState is AuthFailure) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  authState.errorMessage,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xxxl),

              // 6 PIN boxes in a clean card
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 44,
                      height: 54,
                      child: TextField(
                        controller: _pinControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slateDark),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                          ),
                        ),
                        onChanged: (val) {
                          if (val.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (val.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          if (index == 5 && val.isNotEmpty) {
                            _verifyOtp();
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              AppPrimaryButton(
                text: 'Verify & Continue',
                isLoading: isLoading,
                backgroundColor: AppColors.secondary,
                onPressed: _verifyOtp,
              ),
              const SizedBox(height: AppSpacing.lg),

              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16, color: AppColors.secondary),
                  label: const Text(
                    'Didn\'t receive code? Resend SMS',
                    style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () => context.read<AuthBloc>().add(RequestPhoneOtpEvent(widget.phoneNumber)),
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
