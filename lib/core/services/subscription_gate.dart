import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../shared/widgets/premium_upgrade_dialog.dart';

enum PremiumFeature {
  unlimitedAdoptions,
  priorityListing,
  visitorAnalytics,
  extraPhotos,
  veterinaryChat,
  adFree;

  String get titleEn {
    switch (this) {
      case PremiumFeature.unlimitedAdoptions:
        return 'Unlimited Adoption Requests';
      case PremiumFeature.priorityListing:
        return 'Priority Search & Listing Boost';
      case PremiumFeature.visitorAnalytics:
        return 'Profile & Post Visitor Analytics';
      case PremiumFeature.extraPhotos:
        return 'Extra High-Resolution Photos';
      case PremiumFeature.veterinaryChat:
        return '24/7 Veterinary Advice Channel';
      case PremiumFeature.adFree:
        return '100% Ad-Free Experience';
    }
  }

  String get titleBn {
    switch (this) {
      case PremiumFeature.unlimitedAdoptions:
        return 'সীমাহীন অ্যাডপশন আবেদন';
      case PremiumFeature.priorityListing:
        return 'সার্চে সবার উপরে প্রায়োরিটি লিস্টিং';
      case PremiumFeature.visitorAnalytics:
        return 'কে আমার পেট পোস্ট দেখেছে (ভিজিটর অ্যানালিটিক্স)';
      case PremiumFeature.extraPhotos:
        return '১০টি অতিরিক্ত হাই-রেজ্যুলেশন ছবি';
      case PremiumFeature.veterinaryChat:
        return '২৪/৭ ভেটেরিনারি পরামর্শ সাপোর্ট';
      case PremiumFeature.adFree:
        return 'সম্পূর্ণ অ্যাড-মুক্ত এক্সপেরিয়েন্স';
    }
  }

  String get descriptionEn {
    switch (this) {
      case PremiumFeature.unlimitedAdoptions:
        return 'Submit unlimited adoption and foster applications with fast-track shelter coordinator reviews.';
      case PremiumFeature.priorityListing:
        return 'Boost your rescue or foster posts to the top of swipe decks and search results for faster adoption.';
      case PremiumFeature.visitorAnalytics:
        return 'See who viewed your rescue profiles and track engagement stats in real-time.';
      case PremiumFeature.extraPhotos:
        return 'Upload up to 10-15 high-definition photos per pet listing to showcase your rescues beautifully.';
      case PremiumFeature.veterinaryChat:
        return 'Direct channel to verified animal welfare veterinarians for emergency first-aid advice.';
      case PremiumFeature.adFree:
        return 'Enjoy an uncluttered, distraction-free environment dedicated to animal welfare.';
    }
  }
}

class SubscriptionGate {
  /// Central check if current user is active Premium
  static bool isPremium(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated) {
      return state.user.hasActivePremium;
    }
    return false;
  }

  /// Returns remaining days of active subscription
  static int remainingDays(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated) {
      return state.user.remainingDays;
    }
    return 0;
  }

  /// Checks feature access. If user is free, pops the upgrade prompt and returns false.
  static bool checkFeature(BuildContext context, PremiumFeature feature) {
    if (isPremium(context)) {
      return true;
    }

    PremiumUpgradeDialog.show(context, feature: feature);
    return false;
  }
}

