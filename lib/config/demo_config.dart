/// Centralized demonstration configuration for thesis defense & viva evaluation.
///
/// Role: Single-point switchboard for academic evaluation and live faculty demonstration.
/// Design Pattern: Configuration Object / Feature Toggle Pattern.
///
/// Modify any value in this class and perform a Flutter Hot-Reload (`r`) to
/// instantly showcase live behavior, branding, security guards, or algorithm changes.
class DemoConfig {
  DemoConfig._();

  // ---------------------------------------------------------------------------
  // 1. Instant Branding & Color Demonstration
  // ---------------------------------------------------------------------------
  /// When true, activates the AdoptMatch Rose accent (#E11D48) as the primary brand.
  /// When false, uses the signature AdoptMatch Teal (#0D9488) palette.
  static bool useRoseAccentTheme = false;

  /// English and Bengali localization labels for header inspection
  static const String appTitleEnglish = 'AdoptMatch';
  static const String appTitleBengali = 'অ্যাডপ্টম্যাচ';

  // ---------------------------------------------------------------------------
  // 2. Academic Feature Toggles for Live Demo
  // ---------------------------------------------------------------------------
  /// Enables/disables the 24/7 Emergency SOS broadcast card in the Discover screen.
  static bool enableEmergencySOSBanner = true;

  /// Toggles whether email + password login requires 6-digit OTP verification.
  /// If set to false during viva, demonstrates instant direct password sign-in.
  static bool enableStrictOTPVerification = true;

  /// Enables 1-tap Admin & User Demo Access with full permissions.
  /// Can be disabled for locked-down builds via `--dart-define=ENABLE_VIVA_DEMO=false`.
  static const bool enableVivaDemoPass = bool.fromEnvironment(
    'ENABLE_VIVA_DEMO',
    defaultValue: true,
  );

  /// Toggles exotic pet category chips (Turtles, Geckos, Birds) in the catalog.
  static bool showExoticPetCategories = true;

  // ---------------------------------------------------------------------------
  // 3. Match Algorithm Sensitivity & Geographic Radius
  // ---------------------------------------------------------------------------
  /// Radius in kilometers used for nearby rescue filtering (e.g. 5km, 10km, 25km).
  static double defaultSearchRadiusKm = 10.0;

  /// Minimum compatibility score (%) required to recommend a pet profile.
  static int minimumCompatibilityScore = 60;

  // ---------------------------------------------------------------------------
  // 4. Academic Metadata for Defense & Thesis Presentation
  // ---------------------------------------------------------------------------
  static const String thesisTitle =
      'AdoptMatch: Intelligent Pet Adoption & Shelter Management System';
  static const String projectVersion = '2.4.0-Academic-Release';
  static const String academicSession = '2026-2027';
  static const String architecturalPattern =
      'Clean Architecture + BLoC State Management Pattern';
  static const String primaryBackend =
      'Supabase (PostgreSQL 15 + RLS + GoTrue Auth + Edge Functions)';
  static const String fallbackBackend =
      'Laravel 11 REST API (PHP 8.2 + Sanctum)';
}
