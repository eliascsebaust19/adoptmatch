# AdoptMatch: Academic Thesis Walkthrough & Viva Defense Cheatsheet

> **Project Title:** AdoptMatch — Intelligent Pet Adoption & Shelter Management System  
> **Academic Session:** 2026–2027  
> **Architectural Pattern:** Clean Architecture + BLoC (Business Logic Component) Pattern  
> **Primary Authority:** Supabase (PostgreSQL 15, RLS, GoTrue Auth, Realtime WebSockets, Edge Functions)  
> **Secondary / Fallback API:** Laravel 11 REST API (PHP 8.2+, Sanctum)  

---

## 🎯 ১. দ্রুত ফাইল নেভিগেটর (শিক্ষক প্রশ্ন করলে যে ফাইল খুলবেন)

| শিক্ষক যদি প্রশ্ন করেন | তাৎক্ষণিক যে ফাইলটি খুলবেন | ফাইলের মূল দায়িত্ব ও এক্সপ্ল্যানেশন |
| :--- | :--- | :--- |
| **Authentication & Email OTP** | [`lib/core/services/supabase_auth_service.dart`](file:///d:/AdoptMatch/lib/core/services/supabase_auth_service.dart)<br>[`lib/features/auth/screens/verify_otp_screen.dart`](file:///d:/AdoptMatch/lib/features/auth/screens/verify_otp_screen.dart) | **Two-Factor Flow:** গুগল লগইনে ওটিপি বাইপাস হয়। ইমেইল+পাসওয়ার্ডে প্রথমে ক্রেডেনশিয়াল টেস্ট হয়, সেশন পার্জ করে ৬ ডিজিটের জিমেইল ওটিপি পাঠানো হয় এবং `verifyOTP()` সফল হলে সেশন পারসিস্ট হয়। |
| **Tinder-Style Swipe Match** | [`lib/features/adoption_match/bloc/pet_match_bloc.dart`](file:///d:/AdoptMatch/lib/features/adoption_match/bloc/pet_match_bloc.dart)<br>[`lib/features/adoption_match/screens/swipe_match_screen.dart`](file:///d:/AdoptMatch/lib/features/adoption_match/screens/swipe_match_screen.dart) | **BLoC State Machine:** জেসচার ড্র্যাগ ডিশন (Right = Like, Left = Skip)। লাইফস্টাইল কুইজের স্কোরের সাথে মিলিয়ে ডায়নামিক ম্যাচ স্কোর পার্সেন্টেজ হিসাব করে। |
| **Distance & Location Filter** | [`lib/features/adoption_match/screens/discover_screen.dart`](file:///d:/AdoptMatch/lib/features/adoption_match/screens/discover_screen.dart)<br>[`lib/core/models/pet_model.dart`](file:///d:/AdoptMatch/lib/core/models/pet_model.dart) | **Geospatial Proximity:** ইউজারের লোকেশন কোঅর্ডিনেট এবং শেল্টারের অক্ষাংশ/দ্রাঘিমাংশের মধ্যে হ্যাভারসাইন ফর্মুলায় দূরত্ব (`distanceKm`) বের করে ফিল্টার করে। |
| **Emergency SOS 5km Broadcast** | [`lib/features/emergency_sos/screens/emergency_sos_screen.dart`](file:///d:/AdoptMatch/lib/features/emergency_sos/screens/emergency_sos_screen.dart)<br>[`lib/core/repositories/emergency_repository.dart`](file:///d:/AdoptMatch/lib/core/repositories/emergency_repository.dart) | **Realtime Alert:** হারানো বা আহত প্রাণীর জন্য ৫ কিমি ব্যাসার্ধে কমিউনিটি পুশ ও ব্রডকাস্ট পাঠানো হয়। সাথে সাথে ইমার্জেন্সি হটলাইনে কল দেওয়া যায়। |
| **Admin Panel & Moderation** | [`lib/features/admin/screens/admin_dashboard_screen.dart`](file:///d:/AdoptMatch/lib/features/admin/screens/admin_dashboard_screen.dart)<br>[`lib/core/repositories/admin_repository.dart`](file:///d:/AdoptMatch/lib/core/repositories/admin_repository.dart) | **RBAC Security:** শুধুমাত্র `role.hasAdminAccess` সম্পন্ন ইউজারের জন্য অ্যাডমিন প্যানেল সুরক্ষিত। `admin_dashboard_stats()` RPC দিয়ে কেপিআই লোড হয়। |
| **Pet Health Passport & QR** | [`lib/features/health_passport/screens/health_passport_screen.dart`](file:///d:/AdoptMatch/lib/features/health_passport/screens/health_passport_screen.dart) | **Cryptographic QR:** প্রতিটি পোষ্যের জন্য একটি ইউনিক মেডিকেল হ্যাশ তৈরি করে QR কোড ডিসপ্লে করা হয় যা ভেটেরিনারি হিস্ট্রি ও ভ্যাকসিনের প্রমাণপত্র। |

---

## 🎛️ ২. লাইভ ডিফেন্স কন্ট্রোল বোর্ড (`lib/config/demo_config.dart`)

ডিফেন্স চলাকালীন শিক্ষক যদি বলেন: *"আচ্ছা, এই ফিচারটা বন্ধ করে বা এই কালারটা বদলে দেখাও তো"*, তখন শুধুমাত্র [`lib/config/demo_config.dart`](file:///d:/AdoptMatch/lib/config/demo_config.dart) ফাইলে গিয়ে মান পরিবর্তন করে **Flutter Hot Reload (`r`)** চাপলেই পরিবর্তন লাইভ প্রদর্শিত হবে।

```dart
class DemoConfig {
  // ১. কালার থিম পরিবর্তন (Teal #0D9488 <--> Rose #E11D48)
  static bool useRoseAccentTheme = false;

  // ২. ইমার্জেন্সি এসওএস কার্ড দেখানো বা লুকানো
  static bool enableEmergencySOSBanner = true;

  // ৩. ওটিপি ভেরিফিকেশন অন/অফ (দ্রুত লগইন ডেমোর জন্য)
  static bool enableStrictOTPVerification = true;

  // ৪. এক্সোটিক পেট ক্যাটাগরি চিপস অন/অফ (কচ্ছপ, গিরগিটি ইত্যাদি)
  static bool showExoticPetCategories = true;

  // ৫. সার্চ রেডিয়াস ফিল্টার সংবেদনশীলতা
  static double defaultSearchRadiusKm = 10.0;
}
```

---

## 🏛️ ৩. সফটওয়্যার আর্কিটেকচার ওভারভিউ

```
lib/
├── config/                          # সেন্ট্রালাইজড ডেমো ফ্ল্যাগস ও থিম কনফিগ
│   ├── demo_config.dart             # লাইভ ডিফেন্স কন্ট্রোল বোর্ড
│   └── app_theme.dart               # ব্র্যান্ড কালার ও মেটেরিয়াল ৩ স্টাইলিং
├── core/                            # গ্লোবাল সার্ভিস, সিকিউরিটি ও রিপোজিটরি
│   ├── models/                      # ইমিউটেবল ডেটা মডেল (Pet, UserProfile, AdminKPI)
│   ├── navigation/app_router.dart   # ডিক্লেয়ারেটিভ GoRouter রাউটিং ও ডিপ-লিংকিং
│   ├── repositories/                # Single Source of Truth রিপোজিটরি লেয়ার
│   ├── services/                    # SupabaseAuthService, GoogleAuthService, LocalStorage
│   └── supabase/                    # সুপাবেস ক্লায়েন্ট, Edge Function ও আরপিসি কল
└── features/                        # ফিচার-ফার্স্ট প্রেজেন্টেশন ও স্টেট ম্যানেজমেন্ট
    ├── admin/                       # অ্যাডমিন ড্যাশবোর্ড, ড্রয়ার ও ফ্ল্যাগড পেট মডারেশন
    ├── adoption_match/              # সোয়াইপ ম্যাচ, লাইফস্টাইল কুইজ ও ডিসকভার স্ক্রিন
    ├── auth/                        # লগইন, রেজিস্ট্রেশন ও VerifyOtpScreen
    ├── chat/                        # সুপাবেস রিয়েল-টাইম ডিরেক্ট মেসেজিং ইনবক্স
    ├── emergency_sos/               # ৫ কিমি উদ্ধার ব্রডকাস্ট ও ভেটেরিনারি হটলাইন
    ├── health_passport/             # পোষ্যের ডিজিটাল স্বাস্থ্য পাসপোর্ট ও QR কোড
    └── subscription/                # SSLCommerz ও bKash প্রিমিয়াম সাবস্ক্রিপশন
```

---

## 💡 ৪. ডিফেন্সে কমন টেকনিক্যাল প্রশ্নের উত্তর

### প্রশ্ন ১: "তোমরা অথেনটিকেশনে সুপাবেস কেন ব্যবহার করেছ?"
> **উত্তর:** "সুপাবেস আমাদেরকে এন্টারপ্রাইজ-গ্রেড PostgreSQL Row-Level Security (RLS) দেয়, যা ক্লায়েন্ট সাইড থেকে ডেটা টেম্পারিং প্রতিরোধ করে। একইসাথে এটি গুগল সাইন-ইনের জন্য সিকিউর OAuth হ্যান্ডলিং এবং ইমেইল+পাসওয়ার্ডের জন্য ৬ ডিজিটের ক্রিপ্টোগ্রাফিক টাইম-বেসড ওটিপি সরবরাহ করে।"

### প্রশ্ন ২: "তোমাদের স্টেট ম্যানেজমেন্ট প্যাটার্ন কোনটি?"
> **উত্তর:** "আমরা BLoC (Business Logic Component) প্যাটার্ন ব্যবহার করেছি। এটি UI (Presentation) লেয়ারকে Business Logic এবং Data Repository লেয়ার থেকে সম্পূর্ণ আলাদা রাখে। এতে অ্যাপ আনপ্রেডিক্টেবল স্টেট ক্র্যাশমুক্ত এবং ইউনিট টেস্টাবিলিটি ১০০% নিশ্চিত হয়।"

### প্রশ্ন ৩: "ইন্টারনেট ড্রপ করলে কি অ্যাপ ক্র্যাশ করবে?"
> **উত্তর:** "না স্যার। আমরা Repository Pattern-এ Fail-Closed সিকিউরিটি এবং লোকাল ফলব্যাক আর্কিটেকচার রেখেছি। নেটওয়ার্ক ডাউন হলে অ্যাপ ব্ল্যাঙ্ক ক্র্যাশ না করে ক্যাশড ক্যাটালগ ও প্রফেশনাল রিকানেক্ট ব্যানার প্রদর্শন করে।"
