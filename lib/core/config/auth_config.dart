import 'package:flutter/foundation.dart' show kIsWeb;

/// Single source of truth for authentication configuration.
///
/// Every layer (Google Sign-In, Supabase, Laravel/Node token exchange) must use
/// the SAME Google **Web** OAuth client ID. On Android/iOS it is passed as
/// `serverClientId` so the returned ID token has `aud = <web client id>`, which is
/// exactly what the backends verify. A mismatch produces HTTP 401.
///
/// Override at build time:
///   flutter run --dart-define=GOOGLE_CLIENT_ID=<web-client-id>
///   flutter build apk --dart-define=GOOGLE_CLIENT_ID=<web-client-id> \
///     --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>
class AuthConfig {
  const AuthConfig._();

  /// Web OAuth client ID. Used as `clientId` on web and `serverClientId` on mobile.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '94403915199-f4vmb0cpapc2usdrl6epqgu611mv5pji.apps.googleusercontent.com',
  );

  /// iOS OAuth client ID (required for the iOS URL scheme; see ios/Flutter/GoogleAuth.xcconfig).
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isGoogleConfigured => googleWebClientId.trim().isNotEmpty;

  /// Deep link scheme registered by the Android manifest and the iOS
  /// `CFBundleURLSchemes` entry.
  static const String appUrlScheme = 'adoptmatch';

  /// Where Supabase sends the user back after a Google OAuth round-trip or a
  /// confirmation / recovery email.
  ///
  /// On web this must be the origin the app is actually served from, not a
  /// hardcoded localhost port: a mismatch sends the browser to a dead page and
  /// the PKCE code is never exchanged. Every value produced here has to be
  /// listed in Supabase → Authentication → URL Configuration → Redirect URLs.
  static String get oauthRedirectUrl => kIsWeb
      ? '${Uri.base.origin}/auth-callback'
      : '$appUrlScheme://auth-callback';

  /// Same target, named for email templates (`emailRedirectTo`).
  static String get emailRedirectUrl => oauthRedirectUrl;

  /// Recovery links land on a dedicated screen so the user can actually set a
  /// new password. Supabase matches redirect URLs against the allowlist, so
  /// this value must be listed in the dashboard as well.
  static String get passwordResetRedirectUrl => kIsWeb
      ? '${Uri.base.origin}/auth/reset-password'
      : '$appUrlScheme://auth-callback?type=recovery';

  /// The debug keystore fingerprint. Release builds are signed with a different
  /// key and need their own Android OAuth client, so this value only describes
  /// development builds.
  static const String debugAndroidSha1 =
      '88:60:0E:C9:44:D9:F7:FE:5B:DC:53:74:3C:BA:B1:25:32:0C:09:7B';

  /// Actionable message when Google did not return an ID token. This is almost
  /// always a platform registration problem, not a server problem.
  static const String missingIdTokenMessage =
      'Google did not return an ID token. Check that GOOGLE_CLIENT_ID is the Web '
      'OAuth client ID, that this build\'s SHA-1 (Android) or bundle ID + URL '
      'scheme (iOS) is registered in Google Cloud Console, and that the web '
      'origin is authorised. See docs/AUTH_SETUP.md.';

  static const String notConfiguredMessage =
      'Google sign-in is not configured in this build. Rebuild with '
      '--dart-define=GOOGLE_CLIENT_ID=<web-client-id>. See docs/AUTH_SETUP.md.';
}
