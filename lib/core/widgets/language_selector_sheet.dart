import 'package:flutter/material.dart';
import '../localization/app_locale.dart';

/// Displays a professional bottom sheet modal for switching application language
void showProfessionalLanguageSelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (modalContext) {
      return ValueListenableBuilder<Locale>(
        valueListenable: appLocaleNotifier,
        builder: (ctx, currentLocale, _) {
          // Check locale from AppLocaleScope if available, fallback to appLocaleNotifier
          bool isEnglish = true;
          try {
            final scope = AppLocaleScope.of(context);
            isEnglish = scope.language == AppLanguage.en;
          } catch (_) {
            isEnglish = currentLocale.languageCode == 'en';
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Language / ভাষা নির্বাচন করুন',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                // English Option
                _LanguageTile(
                  title: 'English (US)',
                  subtitle: 'Default app language',
                  flagEmoji: '🇺🇸',
                  isSelected: isEnglish,
                  onTap: () {
                    try {
                      AppLocaleScope.of(context).onLanguageChanged(AppLanguage.en);
                    } catch (_) {}
                    appLocaleNotifier.value = AppLocale.english;
                    Navigator.pop(modalContext);
                  },
                ),
                const SizedBox(height: 12),
                // Bangla Option
                _LanguageTile(
                  title: 'বাংলা (Bangladesh)',
                  subtitle: 'অ্যাপের মূল ভাষা',
                  flagEmoji: '🇧🇩',
                  isSelected: !isEnglish,
                  onTap: () {
                    try {
                      AppLocaleScope.of(context).onLanguageChanged(AppLanguage.bn);
                    } catch (_) {}
                    appLocaleNotifier.value = AppLocale.bengali;
                    Navigator.pop(modalContext);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    },
  );
}

class _LanguageTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String flagEmoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.flagEmoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6FFFA) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(flagEmoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF0D9488),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

