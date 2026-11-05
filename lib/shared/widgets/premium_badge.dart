import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PremiumBadge extends StatelessWidget {
  final String title;
  final bool isCrown;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const PremiumBadge({
    super.key,
    this.title = 'Premium Supporter',
    this.isCrown = true,
    this.fontSize = 11.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCrown ? Icons.workspace_premium : Icons.stars_rounded,
            size: fontSize + 2,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

