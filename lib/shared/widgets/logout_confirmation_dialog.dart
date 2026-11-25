import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_locale.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../features/auth/bloc/auth_bloc.dart';

/// Shows the modern, brand-aligned AdoptMatch Logout Confirmation Dialog.
///
/// Complies with Material 3 dialog specifications, providing smooth contrast,
/// soft rose badge accents, explicit cancel/confirm choices, and safe asynchronous logout.
Future<bool?> showAdoptMatchLogoutDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) => const AdoptMatchLogoutDialog(),
  );
}

class AdoptMatchLogoutDialog extends StatefulWidget {
  const AdoptMatchLogoutDialog({super.key});

  @override
  State<AdoptMatchLogoutDialog> createState() => _AdoptMatchLogoutDialogState();
}

class _AdoptMatchLogoutDialogState extends State<AdoptMatchLogoutDialog> {
  bool _isLoading = false;

  Future<void> _handleLogout() async {
    if (_isLoading) return;

    final authBloc = context.read<AuthBloc>();
    final router = GoRouter.of(context);
    final nav = Navigator.of(context);

    setState(() => _isLoading = true);

    try {
      // 1. Dispatch AuthLogoutRequested and wait for Unauthenticated state so
      //    GoRouter.redirect does not bounce back before state updates.
      authBloc.add(const AuthLogoutRequested());
      if (authBloc.state is Authenticated) {
        await authBloc.stream
            .firstWhere((s) => s is! Authenticated)
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => const AuthUnauthenticated(),
            );
      }

      // 2. Clear credentials from FlutterSecureStorage and application session
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(resetOnError: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
      await storage.deleteAll();
      await SecureStorageService.instance.clearSession();
    } catch (e) {
      debugPrint('[LogoutDialog] Notice during session purge: $e');
    }

    if (!mounted) return;

    // 3. Dismiss dialog safely
    nav.pop(true);

    // 4. Navigate safely to /login
    router.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Detect Bengali locale safely
    final isBn = context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()?.language == AppLanguage.bn;

    final titleText = isBn ? 'AdoptMatch থেকে লগআউট করতে চান?' : 'Log Out of AdoptMatch?';
    final subtitleText = isBn
        ? 'আপনি কি নিশ্চিত যে লগআউট করতে চান? পোষ্য খুঁজতে, শেল্টারের সাথে চ্যাট করতে এবং হেলথ পাসপোর্ট দেখতে পুনরায় সাইন ইন করতে হবে।'
        : 'Are you sure you want to log out? You will need to sign in again to swipe, chat with shelters, and access health passports.';
    final cancelText = isBn ? 'বাতিল' : 'Cancel';
    final logoutText = isBn ? 'হ্যাঁ, লগআউট' : 'Yes, Log Out';

    return Dialog(
      backgroundColor: const Color(0xFFFFFFFF),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.18),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Centered Header Icon / Badge (64x64 Soft Rose)
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE4E6), // Soft Rose
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFE11D48), // AdoptMatch Crimson/Rose
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Title Typography
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // 3. Subtitle / Description Typography
              Text(
                subtitleText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // 4. Action Buttons (Horizontal Row with 12dp spacing)
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Confirm Log Out Button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48), // AdoptMatch Crimson
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFFE11D48).withOpacity(0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isLoading ? null : _handleLogout,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              logoutText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
