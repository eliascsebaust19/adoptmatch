import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_locale.dart';
import '../../core/services/subscription_gate.dart';
import '../../core/theme/app_theme.dart';
import 'app_primary_button.dart';

class PremiumUpgradeDialog extends StatelessWidget {
  final PremiumFeature feature;

  const PremiumUpgradeDialog({super.key, required this.feature});

  static Future<void> show(
    BuildContext context, {
    required PremiumFeature feature,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => PremiumUpgradeDialog(feature: feature),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBn = AppLocaleScope.of(context).language == AppLanguage.bn;
    final title = isBn ? feature.titleBn : feature.titleEn;
    final description = feature.descriptionEn;

    return Dialog(
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
              color: Colors.black.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Crown Badge Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B), width: 2),
              ),
              child: const Icon(
                Icons.workspace_premium,
                size: 34,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              isBn ? 'প্রিমিয়াম ফিচার আনলক করুন' : 'Unlock Premium Feature',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.slateDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),

            // Feature Name Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB45309),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Price banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    isBn
                        ? 'প্ল্যান শুরু মাত্র ৳৯০ BDT থেকে'
                        : 'Plans starting from only ৳90 BDT',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slateDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Actions
            AppPrimaryButton(
              text: isBn
                  ? 'প্ল্যান দেখুন ও প্রিমিয়াম নিন'
                  : 'View Plans & Go Premium',
              icon: const Icon(Icons.stars, color: Colors.white, size: 18),
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/subscription/plans');
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                isBn ? 'পরে করব' : 'Maybe Later',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
