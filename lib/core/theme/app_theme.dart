import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Warm Orange primary accent, crisp white, soft borders #E2E8F0, muted dark text #1E293B
  static const Color primaryOrange = Color(0xFFE05626);
  static const Color primaryOrangeLight = Color(0xFFFFEDD5);
  static const Color primaryOrangeDark = Color(0xFFC2411A);
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryTealLight = Color(0xFF14B8A6);
  static const Color primaryTealDark = Color(0xFF0F766E);
  static const Color accentRose = Color(0xFFE11D48);
  static const Color accentRoseLight = Color(0xFFFB7185);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF10B981);
  static const Color slateDark = Color(0xFF1E293B);
  static const Color slateMedium = Color(0xFF334155);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);
  static const Color slateLight = Color(0xFFF8FAFC);
  static const Color purpleAccent = Color(0xFF6366F1);
  static const Color orangeAccent = Color(0xFFE05626);

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFFFEDD5),
        onPrimaryContainer: Color(0xFF7C2D12),
        secondary: accentRose,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFFFE4E6),
        onSecondaryContainer: Color(0xFF9F1239),
        surface: Colors.white,
        onSurface: slateDark,
        error: accentRose,
        onError: Colors.white,
        outline: slateBorder,
      ),
      scaffoldBackgroundColor: slateLight,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: slateBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: const IconThemeData(color: slateDark),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: slateDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: primaryTeal, width: 1.5),
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: slateMuted,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: slateBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: slateBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentRose),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        side: const BorderSide(color: slateBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: slateDark,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: slateBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    const bgDark = Color(0xFF0F172A);
    const surfaceDark = Color(0xFF1E293B);
    const borderDark = Color(0xFF334155);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryTealLight,
        onPrimary: bgDark,
        primaryContainer: Color(0xFF115E59),
        onPrimaryContainer: Colors.white,
        secondary: accentRoseLight,
        onSecondary: bgDark,
        surface: surfaceDark,
        onSurface: Colors.white,
        error: accentRoseLight,
        outline: borderDark,
      ),
      scaffoldBackgroundColor: bgDark,
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        hintStyle: const TextStyle(color: slateMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTealLight, width: 1.8),
        ),
      ),
    );
  }
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppRadius {
  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 14.0;
  static const double xl = 16.0;
  static const double xxl = 20.0;
  static const double card = 16.0;
  static const double button = 14.0;
  static const double pill = 28.0;
  static const double modal = 24.0;
}

class AppColors {
  static const Color primary = AppTheme.primaryOrange;
  static const Color primaryLight = AppTheme.primaryOrangeLight;
  static const Color primaryDark = AppTheme.primaryOrangeDark;
  static const Color secondary = AppTheme.primaryTeal;
  static const Color secondaryLight = AppTheme.primaryTealLight;
  static const Color secondaryDark = AppTheme.primaryTealDark;
  static const Color accent = AppTheme.accentRose;
  static const Color error = AppTheme.accentRose;
  static const Color success = AppTheme.successGreen;
  static const Color amber = AppTheme.accentAmber;
  static const Color slateDark = AppTheme.slateDark;
  static const Color slateMedium = AppTheme.slateMedium;
  static const Color textSecondary = AppTheme.slateMuted;
  static const Color border = AppTheme.slateBorder;
  static const Color surfaceScaffold = AppTheme.slateLight;
}



