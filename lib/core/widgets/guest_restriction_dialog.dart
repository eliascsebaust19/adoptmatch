import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/bloc/auth_bloc.dart';

/// Modal dialog presented when a guest (demo mode) user attempts to access
/// interactive, personal, or administrative features.
class GuestRestrictionDialog extends StatelessWidget {
  final String title;
  final String message;
  final String actionTitle;
  final IconData icon;

  const GuestRestrictionDialog({
    super.key,
    required this.title,
    required this.message,
    this.actionTitle = 'Sign In / Register',
    this.icon = Icons.lock_outline_rounded,
  });

  /// Static helper to check if current user is in Guest Demo mode.
  /// If guest, displays the restriction dialog and returns `true` (blocked).
  /// If regular authenticated user, returns `false` (allowed to proceed).
  static Future<bool> checkAndShow(
    BuildContext context, {
    required String featureName,
    String? customMessage,
  }) async {
    final authState = context.read<AuthBloc>().state;
    final isGuest = authState is Authenticated && authState.user.role.isGuest;

    if (isGuest) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => GuestRestrictionDialog(
          title: '$featureName Restricted',
          message: customMessage ??
              'You are currently exploring AdoptMatch in Guest Demo Mode.\n\nTo access "$featureName", please sign in or create an account with Google or Email.\n\n(এই ফিচারটি ব্যবহারের জন্য অনুগ্রহ করে সাইন ইন বা রেজিস্টার করুন। ডেমো মোডে শুধু প্রিভিউ দেখা যাবে।)',
          actionTitle: 'Sign In / লগইন',
        ),
      );
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFE11D48), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined, size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 6),
                Text(
                  'Demo / Guest Mode Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Continue Demo',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE05626),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/auth/login');
          },
          child: Text(
            actionTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

