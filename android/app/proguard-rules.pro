# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Sign-In & Play Services
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Supabase & Http
-dontwarn okio.**
-dontwarn okhttp3.**

# QR & Camera / Image Picker
-dontwarn com.google.zxing.**
-dontwarn io.flutter.plugins.imagepicker.**


# Google Play Core (Flutter deferred components fallback)
-dontwarn com.google.android.play.core.**
