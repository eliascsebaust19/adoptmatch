import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Extension on [BuildContext] to provide safe, crash-proof back navigation.
///
/// When a user enters the app via deep links, external push notifications,
/// or universal links, the local navigation stack might only contain the active
/// screen. Calling standard `context.pop()` in such situations can result in a
/// blank/black screen or unexpected app closure.
///
/// [safePop] guarantees that if the route cannot be popped, it will fallback
/// smoothly to [fallbackPath] (defaulting to '/home').
extension SafeNavigationExtension on BuildContext {
  void safePop({String fallbackPath = '/home'}) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackPath);
    }
  }
}

/// A production-grade, design-system-compliant leading Back Button for AdoptMatch.
///
/// Features:
/// - Rounded rectangular container with `#E2E8F0` border and soft elevation.
/// - Adaptive Material 3 ripple effect and hit testing.
/// - Modern chevron icon: [Icons.arrow_back_ios_new_rounded] sized at 18dp.
/// - Safe back navigation: automatically falls back to [fallbackPath] (default: `'/home'`)
///   if `context.canPop()` is false (e.g. launched from push notifications or deep links).
/// - Fully customizable: allows overriding [onPressed], [backgroundColor], [iconColor],
///   [borderColor], and [tooltip].
class AdoptMatchBackButton extends StatelessWidget {
  /// The route to navigate to if `context.canPop()` returns false.
  final String fallbackPath;

  /// Optional custom callback. If provided, default pop/go logic is bypassed.
  final VoidCallback? onPressed;

  /// Custom background color. Defaults to semi-translucent white.
  final Color? backgroundColor;

  /// Custom icon color. Defaults to dark slate (`#1E293B`).
  final Color? iconColor;

  /// Custom border color. Defaults to `#E2E8F0`.
  final Color? borderColor;

  /// Custom padding around the button. Defaults to `EdgeInsets.all(8.0)`.
  final EdgeInsetsGeometry padding;

  /// Accessibility tooltip.
  final String tooltip;

  /// Size of the inner chevron icon. Defaults to 18dp.
  final double iconSize;

  const AdoptMatchBackButton({
    super.key,
    this.fallbackPath = '/home',
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(8.0),
    this.tooltip = 'Back',
    this.iconSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? Colors.white.withOpacity(0.92);
    final effectiveIconColor = iconColor ?? const Color(0xFF1E293B);
    final effectiveBorderColor = borderColor ?? const Color(0xFFE2E8F0);

    return Padding(
      padding: padding,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: effectiveBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: effectiveBorderColor, width: 1.2),
          ),
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.04),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (onPressed != null) {
                onPressed!();
              } else {
                context.safePop(fallbackPath: fallbackPath);
              }
            },
            child: Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: iconSize,
                color: effectiveIconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

