import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A production-grade [PopScope] wrapper implementing:
/// 1. Tab-switching to the root Home tab if the user is on any secondary tab.
/// 2. Double-tap back to exit with a localized, styled SnackBar confirmation when on Home.
///
/// Designed to replace deprecated `WillPopScope` in Flutter 3.16+ / Material 3.
class RootBackScope extends StatefulWidget {
  /// The child widget (typically the main shell scaffold containing bottom navigation).
  final Widget child;

  /// The active bottom navigation tab index.
  final int currentTabIndex;

  /// Callback to switch back to the primary Home tab (index 0).
  final VoidCallback onSwitchToHomeTab;

  /// Confirmation message shown when the back button is pressed on Home tab.
  final String exitWarningMessage;

  /// Maximum duration (in milliseconds) between two back taps to confirm exit.
  final int exitTimeoutMs;

  const RootBackScope({
    super.key,
    required this.child,
    required this.currentTabIndex,
    required this.onSwitchToHomeTab,
    this.exitWarningMessage = 'Press back again to exit AdoptMatch / অ্যাপ থেকে বের হতে আবার ব্যাক চাপুন',
    this.exitTimeoutMs = 2000,
  });

  @override
  State<RootBackScope> createState() => _RootBackScopeState();
}

class _RootBackScopeState extends State<RootBackScope> {
  DateTime? _lastBackPressTime;

  void _handlePopInvoked(bool didPop, dynamic result) {
    if (didPop) return;

    // 1. If currently on a secondary tab (Find, Chat, Feed, Profile), switch to Home (Tab 0) first.
    if (widget.currentTabIndex > 0) {
      widget.onSwitchToHomeTab();
      return;
    }

    // 2. We are on the root Home tab: implement Double-Tap Back to Exit
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > Duration(milliseconds: widget.exitTimeoutMs)) {
      _lastBackPressTime = now;

      // Show floating snackbar alert
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.exitWarningMessage,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 90), // Sits comfortably above bottom bar
          duration: Duration(milliseconds: widget.exitTimeoutMs),
        ),
      );
    } else {
      // User tapped back twice within the timeout: dismiss snackbar and exit application
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvoked,
      child: widget.child,
    );
  }
}

