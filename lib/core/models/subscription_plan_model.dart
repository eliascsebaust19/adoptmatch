import 'package:equatable/equatable.dart';

class SubscriptionPlan extends Equatable {
  final String id;
  final String name;
  final String nameBn;
  final double price;
  final String currency;
  final int durationDays;
  final String tag;
  final bool isBestValue;
  final bool isActive;
  final List<String> features;
  final List<String> featuresBn;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.nameBn,
    required this.price,
    this.currency = 'BDT',
    required this.durationDays,
    required this.tag,
    this.isBestValue = false,
    this.isActive = true,
    required this.features,
    required this.featuresBn,
  });

  String get formattedPrice => '৳${price.toInt()}';

  String get durationString {
    if (durationDays >= 365) return '1 Year';
    if (durationDays >= 90) return '3 Months';
    if (durationDays >= 30) return '1 Month';
    return '$durationDays Days';
  }

  String get durationStringBn {
    if (durationDays >= 365) return '১ বছর';
    if (durationDays >= 90) return '৩ মাস';
    if (durationDays >= 30) return '১ মাস';
    return '$durationDays দিন';
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String? ?? 'plan-monthly',
      name: json['name'] as String? ?? 'Supporter Plan',
      nameBn: json['nameBn'] as String? ?? 'সাপোর্টার প্ল্যান',
      price: (json['price'] as num?)?.toDouble() ?? 90.0,
      currency: json['currency'] as String? ?? 'BDT',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      tag: json['tag'] as String? ?? 'Starter',
      isBestValue: json['isBestValue'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      featuresBn: (json['featuresBn'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameBn': nameBn,
      'price': price,
      'currency': currency,
      'durationDays': durationDays,
      'tag': tag,
      'isBestValue': isBestValue,
      'isActive': isActive,
      'features': features,
      'featuresBn': featuresBn,
    };
  }

  /// Default fallback plans stored locally (ensures 100% offline & demo resilience)
  static const List<SubscriptionPlan> defaultPlans = [
    SubscriptionPlan(
      id: 'plan-monthly',
      name: '1 Month Supporter',
      nameBn: '১ মাস সাপোর্টার',
      price: 90.0,
      currency: 'BDT',
      durationDays: 30,
      tag: 'Starter',
      isBestValue: false,
      features: [
        'Unlimited adoption inquiries & fast reviews',
        'Priority listing badge for all your posts',
        '100% Ad-free and distraction-free experience',
        '5 extra high-definition photos per pet listing',
        'Verified Supporter golden badge on profile',
      ],
      featuresBn: [
        'সীমাহীন অ্যাডপশন রিকোয়েস্ট এবং দ্রুত অ্যাপ্লিকেশন রিভিউ',
        'রেসকিউ ও ফস্টার পোস্টের জন্য প্রায়োরিটি লিস্টিং ব্যাজ',
        '১০০% অ্যাড-মুক্ত ও পরিচ্ছন্ন অ্যাপ এক্সপেরিয়েন্স',
        'প্রতিটি পেট পোস্টে ৫টি অতিরিক্ত এইচডি ছবি',
        'প্রোফাইলে গোল্ডেন ভেরিফাইড সাপোর্টার ব্যাজ',
      ],
    ),
    SubscriptionPlan(
      id: 'plan-quarterly',
      name: '3 Months Saver',
      nameBn: '৩ মাস সেভার',
      price: 200.0,
      currency: 'BDT',
      durationDays: 90,
      tag: 'Most Popular',
      isBestValue: true,
      features: [
        'All 1-Month Supporter benefits included',
        'Profile Visitor Analytics ("Who viewed my pet post")',
        'Top search ranking for urgent foster & rescue posts',
        'Direct priority shelter and coordinator hotline',
        '10 extra high-definition photos per pet listing',
        'Save ৳70 compared to monthly plan',
      ],
      featuresBn: [
        '১ মাসের সমস্ত সুবিধাসমূহ অন্তর্ভুক্ত',
        'ভিজিটর অ্যানালিটিক্স ("কে আমার পেট পোস্ট দেখেছে")',
        'সার্চ রেজাল্টে সবার উপরে প্রায়োরিটি লিস্টিং',
        'শেল্টার ও কোঅর্ডিনেটরের সাথে সরাসরি প্রায়োরিটি চ্যাট',
        'প্রতিটি পোস্টের জন্য ১০টি অতিরিক্ত এইচডি ছবি',
        'মাসিক প্ল্যানের চেয়ে ৳৭০ সাশ্রয়ী',
      ],
    ),
    SubscriptionPlan(
      id: 'plan-annual',
      name: '1 Year VIP Rescuer',
      nameBn: '১ বছর ভিআইপি রেসকিউয়ার',
      price: 499.0,
      currency: 'BDT',
      durationDays: 365,
      tag: 'Best Value',
      isBestValue: false,
      features: [
        'All 3-Month Saver benefits included',
        'VIP Rescuer Golden Crown badge across app',
        'Unlimited pet listings with unlimited HD photo uploads',
        'Lifetime pet health & vaccination passport PDF export',
        '24/7 dedicated online veterinary advice chat channel',
        'Save ৳580+ (Massive yearly discount)',
      ],
      featuresBn: [
        '৩ মাসের সমস্ত সুবিধাসমূহ অন্তর্ভুক্ত',
        'প্রোফাইলে ও সমস্ত পোস্টে ভিআইপি গোল্ডেন ক্রাউন ব্যাজ',
        'সীমাহীন পেট লিস্টিং এবং আনলিমিটেড এইচডি ছবি',
        'লাইফটাইম মেডিকেল ও ভ্যাকসিন হিস্ট্রি পিডিএফ এক্সপোর্ট',
        '২৪/৭ ডেডিকেটেড অনলাইন ভেটেরিনারি চ্যাট সাপোর্ট',
        '৳৫৮০+ এর বিশাল বাৎসরিক ছাড়',
      ],
    ),
  ];

  @override
  List<Object?> get props => [id, name, price, durationDays, isBestValue];
}

