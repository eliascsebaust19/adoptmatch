import 'package:flutter/material.dart';

enum AppLanguage { en, bn }

class AppLocale {
  static const Locale english = Locale('en', 'US');
  static const Locale bengali = Locale('bn', 'BD');
}

final ValueNotifier<Locale> appLocaleNotifier = ValueNotifier<Locale>(AppLocale.english);

class AppLocaleScope extends InheritedWidget {
  final AppLanguage language;
  final Function(AppLanguage) onLanguageChanged;

  const AppLocaleScope({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required super.child,
  });

  static AppLocaleScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()!;
  }

  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) => language != oldWidget.language;
}

class AppStrings {
  static const Map<String, Map<AppLanguage, String>> _localizedValues = {
    // App Bar & Welcome
    'app_title': {
      AppLanguage.en: 'AdoptMatch',
      AppLanguage.bn: 'অ্যাডপ্টম্যাচ',
    },
    'greeting_elias': {
      AppLanguage.en: 'Good Morning, Elias 👋',
      AppLanguage.bn: 'শুভ সকাল, ইলিয়াস 👋',
    },
    'hero_title': {
      AppLanguage.en: 'Find your new best friend.',
      AppLanguage.bn: 'খুঁজে নিন আপনার নতুন প্রিয় সঙ্গী।',
    },
    'search_hint': {
      AppLanguage.en: 'Search pets...',
      AppLanguage.bn: 'পোষা প্রাণী খুঁজুন...',
    },
    // Tabs & Categories
    'all_pets': {
      AppLanguage.en: 'All Pets',
      AppLanguage.bn: 'সব প্রাণী',
    },
    'dogs': {
      AppLanguage.en: 'Dogs',
      AppLanguage.bn: 'কুকুর',
    },
    'cats': {
      AppLanguage.en: 'Cats',
      AppLanguage.bn: 'বিড়াল',
    },
    'birds': {
      AppLanguage.en: 'Birds',
      AppLanguage.bn: 'পাখি',
    },
    'small': {
      AppLanguage.en: 'Small',
      AppLanguage.bn: 'ছোট প্রাণী',
    },
    'seniors': {
      AppLanguage.en: 'Seniors',
      AppLanguage.bn: 'সিনিয়র',
    },
    // Sections
    'recommended_for_you': {
      AppLanguage.en: 'Recommended for You',
      AppLanguage.bn: 'আপনার জন্য সুপারিশকৃত',
    },
    'nearby_pets': {
      AppLanguage.en: 'Nearby Pets',
      AppLanguage.bn: 'কাছাকাছি পোষা প্রাণী',
    },
    'view_all': {
      AppLanguage.en: 'View All',
      AppLanguage.bn: 'সব দেখুন',
    },
    'match_suffix': {
      AppLanguage.en: 'Match',
      AppLanguage.bn: 'ম্যাচ',
    },
    // Navigation
    'nav_home': {
      AppLanguage.en: 'Home',
      AppLanguage.bn: 'হোম',
    },
    'nav_find': {
      AppLanguage.en: 'Swipe Match',
      AppLanguage.bn: 'সোয়াইপ ম্যাচ',
    },
    'nav_favorites': {
      AppLanguage.en: 'Favorites',
      AppLanguage.bn: 'পছন্দের',
    },
    'nav_inbox': {
      AppLanguage.en: 'Inbox',
      AppLanguage.bn: 'মেসেজ',
    },
    'nav_profile': {
      AppLanguage.en: 'Profile',
      AppLanguage.bn: 'প্রোফাইল',
    },
    // Application
    'adoption_application': {
      AppLanguage.en: 'Adoption Application',
      AppLanguage.bn: 'দত্তক নেওয়ার আবেদন',
    },
    'your_information': {
      AppLanguage.en: 'Your Information',
      AppLanguage.bn: 'আপনার তথ্য',
    },
    'full_name': {
      AppLanguage.en: 'Full Name',
      AppLanguage.bn: 'পুরো নাম',
    },
    'phone_number': {
      AppLanguage.en: 'Phone Number',
      AppLanguage.bn: 'মোবাইল নম্বর',
    },
    'address': {
      AppLanguage.en: 'Address',
      AppLanguage.bn: 'ঠিকানা',
    },
    'enter_address': {
      AppLanguage.en: 'Enter your address',
      AppLanguage.bn: 'আপনার ঠিকানা লিখুন',
    },
    'why_adopt': {
      AppLanguage.en: 'Why do you want to adopt?',
      AppLanguage.bn: 'কেন আপনি দত্তক নিতে চান?',
    },
    'why_adopt_hint': {
      AppLanguage.en: 'Tell us about your reason...',
      AppLanguage.bn: 'আপনার উদ্দেশ্য সম্পর্কে বিস্তারিত লিখুন...',
    },
    'submit_application': {
      AppLanguage.en: 'Submit Application',
      AppLanguage.bn: 'আবেদন জমা দিন',
    },
    // Health Passport
    'health_passport': {
      AppLanguage.en: 'Pet Health Passport',
      AppLanguage.bn: 'পোষা স্বাস্থ্য পাসপোর্ট',
    },
    'qr_tag_title': {
      AppLanguage.en: 'Scan for Emergency Vet & Owner ID',
      AppLanguage.bn: 'জরুরি পশুচিকিৎসক ও মালিকের আইডির জন্য স্ক্যান করুন',
    },
    'qr_tag_subtitle': {
      AppLanguage.en: 'Official AdoptMatch Verified Record',
      AppLanguage.bn: 'অফিসিয়াল অ্যাডপ্টম্যাচ যাচাইকৃত রেকর্ড',
    },
    // Emergency SOS
    'emergency_sos': {
      AppLanguage.en: '24/7 Emergency & Lost SOS',
      AppLanguage.bn: '২৪/৭ জরুরি ও নিখোঁজ এসওএস',
    },
    'broadcast_alert': {
      AppLanguage.en: 'Broadcast 5km SOS Alert',
      AppLanguage.bn: '৫ কিমি এসওএস ব্রডকাস্ট করুন',
    },
    // Quiz
    'compatibility_quiz': {
      AppLanguage.en: 'Lifestyle & Compatibility Quiz',
      AppLanguage.bn: 'জীবনযাত্রা ও মিল নির্ধারণ কুইজ',
    },
  };

  static String tr(BuildContext context, String key) {
    final language = AppLocaleScope.of(context).language;
    return _localizedValues[key]?[language] ?? key;
  }
}

